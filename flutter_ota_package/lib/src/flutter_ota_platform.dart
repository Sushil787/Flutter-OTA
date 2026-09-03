import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What the Android side knows about this install.
class FlutterOtaState {
  const FlutterOtaState({
    required this.currentPatch,
    required this.stagedPatch,
    required this.confirmed,
    required this.bootAttempts,
    required this.patchActive,
    required this.packageName,
    required this.releaseVersion,
  });

  /// Inert state for platforms Flutter OTA does not patch.
  const FlutterOtaState.unsupported()
    : currentPatch = 0,
      stagedPatch = 0,
      confirmed = false,
      bootAttempts = 0,
      patchActive = false,
      packageName = null,
      releaseVersion = null;

  factory FlutterOtaState.fromMap(Map<Object?, Object?> map) => FlutterOtaState(
    currentPatch: map['currentPatch'] as int? ?? 0,
    stagedPatch: map['stagedPatch'] as int? ?? 0,
    confirmed: map['confirmed'] as bool? ?? false,
    bootAttempts: map['bootAttempts'] as int? ?? 0,
    patchActive: map['patchActive'] as bool? ?? false,
    packageName: map['packageName'] as String?,
    releaseVersion: map['releaseVersion'] as String?,
  );

  /// Patch number the running snapshot came from; 0 means the APK's own code.
  final int currentPatch;

  /// Patch number waiting on disk, applied at the next launch; 0 means none.
  final int stagedPatch;

  /// Whether [currentPatch] has ever reached a successful launch.
  final bool confirmed;

  /// Launches of an unconfirmed [currentPatch]; drives the crash rollback.
  final int bootAttempts;

  /// Whether *this process* started on a patch. Distinct from [currentPatch]
  /// being non-zero right after staging, which only takes effect next launch.
  final bool patchActive;

  /// The app's Android package name, e.g. `com.example.mybird_test`.
  final String? packageName;

  /// `versionName+versionCode`, matching the CLI's `--version`.
  final String? releaseVersion;

  @override
  String toString() =>
      'FlutterOtaState(current: $currentPatch, staged: $stagedPatch, '
      'confirmed: $confirmed, bootAttempts: $bootAttempts, '
      'active: $patchActive, release: $releaseVersion)';
}

/// Thin wrapper over the `dev.flutterota/flutter_ota` method channel.
///
/// Every call is a no-op off Android, so an app using Flutter OTA still runs on
/// the other platforms — it just never patches.
class FlutterOtaPlatform {
  const FlutterOtaPlatform._();

  static const MethodChannel _channel = MethodChannel('dev.flutterota/flutter_ota');

  /// Whether patching is wired up for the platform we are running on.
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Reads the current bookkeeping plus the app's identity.
  static Future<FlutterOtaState> state() async {
    if (!isSupported) return const FlutterOtaState.unsupported();
    final map = await _channel.invokeMapMethod<Object?, Object?>('state');
    if (map == null) return const FlutterOtaState.unsupported();
    return FlutterOtaState.fromMap(map);
  }

  /// Hands verified patch [bytes] to the native side to stage.
  ///
  /// Returns false if the native side rejected them — normally a [sha256]
  /// mismatch, meaning the transfer was corrupted after the updater's check.
  static Future<bool> stage({
    required int patchNumber,
    required Uint8List bytes,
    required String sha256,
  }) async {
    if (!isSupported) return false;
    final ok = await _channel.invokeMethod<bool>('stage', <String, Object?>{
      'patchNumber': patchNumber,
      'bytes': bytes,
      'sha256': sha256,
    });
    return ok ?? false;
  }

  /// Marks the running patch as good, stopping the crash-rollback countdown.
  static Future<void> confirmLaunch() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('confirmLaunch');
  }

  /// Drops the active and staged patches; the next launch uses the APK's code.
  static Future<void> rollback() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('rollback');
  }
}
