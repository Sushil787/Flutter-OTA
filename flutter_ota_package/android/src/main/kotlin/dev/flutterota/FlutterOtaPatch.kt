package dev.flutterota

import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.FlutterShellArgs
import java.io.File
import java.security.MessageDigest
import org.json.JSONObject

/**
 * The on-device half of Flutter OTA: decides which Dart snapshot the engine loads.
 *
 * The engine resolves its snapshot from an ordered list of
 * `--aot-shared-library-name` values and uses the first one whose symbols
 * resolve (`runtime/dart_snapshot.cc`). `FlutterLoader` splices the args it is
 * handed *before* the two entries it adds for the bundled `libapp.so`, so an
 * absolute path added here wins — and a missing or unloadable patch falls
 * straight back to the code shipped in the APK.
 *
 * None of this runs as a plugin. [applyTo] is called from the app's Activity
 * before the engine exists, so it must stay free of any Flutter runtime state.
 *
 * On-disk layout, all under `filesDir/flutter_ota`:
 * ```
 *   state.json          bookkeeping (see [State])
 *   current/libapp.so   what this process was told to load
 *   staged/libapp.so    downloaded; promoted to current at the next launch
 * ```
 */
object FlutterOtaPatch {
    private const val TAG = "FlutterOta"
    private const val LIB = "libapp.so"

    /** Launches an unconfirmed patch gets before it is assumed to be crashing. */
    private const val MAX_BOOT_ATTEMPTS = 2

    /**
     * @property currentPatch patch number backing `current/`, or 0 for the bundled snapshot.
     * @property stagedPatch patch number sitting in `staged/`, or 0 for nothing staged.
     * @property confirmed whether [confirmLaunch] has been reached with [currentPatch] active.
     * @property bootAttempts launches of an unconfirmed [currentPatch].
     */
    private data class State(
        var currentPatch: Int = 0,
        var stagedPatch: Int = 0,
        var confirmed: Boolean = false,
        var bootAttempts: Int = 0,
    )

    @Volatile private var bootstrapped = false
    @Volatile private var activeLib: File? = null

    // --- Entry point from the app's Activity ---------------------------------

    /**
     * Adds the staged patch to [args] if one is ready, and returns [args].
     *
     * Call from `MainActivity.getFlutterShellArgs()`. `flutter_ota init` writes
     * that override for you. Never throws: a broken patch must not stop the app
     * from starting on the code in its APK.
     */
    @JvmStatic
    fun applyTo(context: Context, args: FlutterShellArgs): FlutterShellArgs {
        try {
            val lib = resolve(context) ?: return args
            args.add("--aot-shared-library-name=${lib.absolutePath}")
            Log.i(TAG, "loading patched snapshot from ${lib.absolutePath}")
        } catch (t: Throwable) {
            Log.e(TAG, "could not apply patch; using the bundled snapshot", t)
        }
        return args
    }

    /**
     * Promotes/expires patches once per process and returns the snapshot to
     * load, or null to use the bundled one.
     *
     * Runs on the main thread before engine startup, so it stays to a directory
     * rename and a small JSON write.
     */
    @Synchronized
    private fun resolve(context: Context): File? {
        if (bootstrapped) return activeLib
        bootstrapped = true

        val root = root(context)
        val state = readState(root)

        // 1. Promote whatever the updater staged since the last launch.
        if (state.stagedPatch != 0 && File(staged(root), LIB).isFile && promote(root)) {
            Log.i(TAG, "promoting patch ${state.stagedPatch}")
            state.currentPatch = state.stagedPatch
            state.stagedPatch = 0
            state.confirmed = false
            state.bootAttempts = 0
        }

        // 2. A patch that keeps getting relaunched without ever confirming is
        //    crashing on startup. Drop it and fall back to the APK.
        if (state.currentPatch != 0 && !state.confirmed) {
            state.bootAttempts++
            if (state.bootAttempts > MAX_BOOT_ATTEMPTS) {
                Log.w(
                    TAG,
                    "patch ${state.currentPatch} failed to confirm in ${state.bootAttempts} " +
                        "launches; rolling back",
                )
                current(root).deleteRecursively()
                state.currentPatch = 0
                state.bootAttempts = 0
                state.confirmed = false
            }
        }

        // 3. Trust the disk over the bookkeeping.
        val lib = File(current(root), LIB)
        if (state.currentPatch != 0 && !lib.isFile) state.currentPatch = 0

        writeState(root, state)
        activeLib = if (state.currentPatch != 0) lib else null
        return activeLib
    }

    // --- Called from Dart over the method channel ----------------------------

    /**
     * Writes [bytes] to `staged/` so the next launch picks them up, after
     * re-checking them against [sha256].
     *
     * The updater already verified the download; hashing again here is what
     * stops a truncated channel transfer from being staged. Returns false if
     * the bytes are wrong or the write fails — the caller keeps its old state
     * and retries on the next check.
     */
    @Synchronized
    fun stage(context: Context, patchNumber: Int, bytes: ByteArray, sha256: String): Boolean {
        val root = root(context)
        val actual = sha256(bytes)
        if (!actual.equals(sha256, ignoreCase = true)) {
            Log.e(TAG, "refusing patch $patchNumber: expected sha256 $sha256, got $actual")
            return false
        }

        // Build the directory off to the side, then swing it into place with a
        // single rename, so `staged/` is never half-written.
        val tmp = File(root, "tmp")
        tmp.deleteRecursively()
        if (!tmp.mkdirs()) {
            Log.e(TAG, "could not create ${tmp.absolutePath}")
            return false
        }
        File(tmp, LIB).writeBytes(bytes)

        val staged = staged(root)
        staged.deleteRecursively()
        if (!tmp.renameTo(staged)) {
            Log.e(TAG, "could not stage patch $patchNumber")
            tmp.deleteRecursively()
            return false
        }

        val state = readState(root)
        state.stagedPatch = patchNumber
        writeState(root, state)
        Log.i(TAG, "staged patch $patchNumber (${bytes.size} bytes)")
        return true
    }

    /**
     * Marks the running patch as good, ending the crash-rollback countdown.
     *
     * Until this is called, [resolve] treats every launch as a failed one.
     */
    @Synchronized
    fun confirmLaunch(context: Context) {
        val root = root(context)
        val state = readState(root)
        if (state.currentPatch == 0 || state.confirmed) return
        state.confirmed = true
        state.bootAttempts = 0
        writeState(root, state)
        Log.i(TAG, "patch ${state.currentPatch} confirmed")
    }

    /** Drops the active and staged patches; the next launch uses the APK. */
    @Synchronized
    fun rollback(context: Context) {
        val root = root(context)
        current(root).deleteRecursively()
        staged(root).deleteRecursively()
        writeState(root, State())
        Log.i(TAG, "rolled back to the bundled snapshot")
    }

    /** Current bookkeeping, for the Dart side's update check and diagnostics. */
    @Synchronized
    fun snapshot(context: Context): Map<String, Any> {
        val state = readState(root(context))
        return mapOf(
            "currentPatch" to state.currentPatch,
            "stagedPatch" to state.stagedPatch,
            "confirmed" to state.confirmed,
            "bootAttempts" to state.bootAttempts,
            // Whether *this process* actually started with a patch path, which
            // is not the same as having one on disk: a patch staged a moment
            // ago only takes effect at the next launch.
            "patchActive" to (activeLib != null),
        )
    }

    // --- Paths, state, hashing ----------------------------------------------

    private fun root(context: Context) =
        File(context.filesDir, "flutter_ota").apply { if (!isDirectory) mkdirs() }

    private fun current(root: File) = File(root, "current")

    private fun staged(root: File) = File(root, "staged")

    /** Swaps `staged/` into `current/`, keeping the old one until the swap lands. */
    private fun promote(root: File): Boolean {
        val current = current(root)
        val trash = File(root, "trash")
        trash.deleteRecursively()
        if (current.exists() && !current.renameTo(trash)) {
            Log.e(TAG, "could not move the previous patch aside")
            return false
        }
        val ok = staged(root).renameTo(current)
        if (!ok) {
            Log.e(TAG, "could not promote the staged patch")
            trash.renameTo(current) // put the previous one back
        }
        trash.deleteRecursively()
        return ok
    }

    private fun stateFile(root: File) = File(root, "state.json")

    private fun readState(root: File): State {
        val file = stateFile(root)
        if (!file.isFile) return State()
        return try {
            val json = JSONObject(file.readText())
            State(
                currentPatch = json.optInt("currentPatch", 0),
                stagedPatch = json.optInt("stagedPatch", 0),
                confirmed = json.optBoolean("confirmed", false),
                bootAttempts = json.optInt("bootAttempts", 0),
            )
        } catch (t: Throwable) {
            // Unreadable bookkeeping means we cannot reason about the patch on
            // disk, so start over from the bundled snapshot.
            Log.e(TAG, "unreadable state.json; resetting", t)
            State()
        }
    }

    private fun writeState(root: File, state: State) {
        val json =
            JSONObject()
                .put("currentPatch", state.currentPatch)
                .put("stagedPatch", state.stagedPatch)
                .put("confirmed", state.confirmed)
                .put("bootAttempts", state.bootAttempts)
        try {
            stateFile(root).writeText(json.toString())
        } catch (t: Throwable) {
            Log.e(TAG, "could not persist state", t)
        }
    }

    private fun sha256(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
}
