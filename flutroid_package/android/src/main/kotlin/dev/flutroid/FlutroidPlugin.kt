package dev.flutroid

import android.content.Context
import android.content.pm.PackageManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Method-channel surface over [FlutroidPatch].
 *
 * The patch that this process is running was chosen before any plugin was
 * registered; everything here is bookkeeping for the *next* launch, plus the
 * app identity the updater needs to ask the server what is available.
 */
class FlutroidPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "dev.flutroid/flutroid")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "state" -> result.success(FlutroidPatch.snapshot(context) + appInfo())

            "stage" -> {
                val patchNumber = call.argument<Int>("patchNumber")
                val bytes = call.argument<ByteArray>("bytes")
                val sha256 = call.argument<String>("sha256")
                if (patchNumber == null || bytes == null || sha256 == null) {
                    result.error("bad_args", "patchNumber, bytes and sha256 are required", null)
                } else {
                    result.success(FlutroidPatch.stage(context, patchNumber, bytes, sha256))
                }
            }

            "confirmLaunch" -> {
                FlutroidPatch.confirmLaunch(context)
                result.success(null)
            }

            "rollback" -> {
                FlutroidPatch.rollback(context)
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    /**
     * The app's identity, so `Flutroid.initialize` needs nothing but a URL.
     *
     * `releaseVersion` is formatted as `versionName+versionCode` to match the
     * `--version` the CLI uploads a release under.
     */
    private fun appInfo(): Map<String, Any?> {
        val packageName = context.packageName
        val info =
            try {
                context.packageManager.getPackageInfo(packageName, 0)
            } catch (e: PackageManager.NameNotFoundException) {
                null
            }
        @Suppress("DEPRECATION") val code = info?.versionCode ?: 0
        return mapOf(
            "packageName" to packageName,
            "releaseVersion" to info?.versionName?.let { "$it+$code" },
        )
    }
}
