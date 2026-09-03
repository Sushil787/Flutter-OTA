import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'flutter_ota_platform.dart';
import 'flutter_ota_progress.dart';
import 'update_client.dart';
import 'updater.dart';

/// Entry point for the Flutter OTA updater.
///
/// ```dart
/// void main() async {
///   await FlutterOta.initialize(updateUrl: 'http://10.0.2.2:8080');
///   runApp(const MyApp());
/// }
/// ```
///
/// The app's package name and release version come from the platform, so the
/// backend URL is the only thing you have to supply.
class FlutterOta {
  FlutterOta._({
    required this.updateUrl,
    required this.packageName,
    required this.releaseVersion,
    required FlutterOtaState state,
  }) : _state = state,
       updater = Updater(
         client: UpdateClient(updateUrl: updateUrl, packageName: packageName),
       );

  /// Base URL of the Flutter OTA backend.
  ///
  /// Note that `localhost` on a device or emulator is the device itself — reach
  /// a server on your machine at `http://10.0.2.2:8080` from the Android
  /// emulator, or at your LAN address from a physical device.
  final String updateUrl;

  /// Identifier for this app, e.g. `com.example.mybird_test`.
  final String packageName;

  /// Release this install was built as, e.g. `1.0.0+1`. Patches are scoped to
  /// it — a patch built against a different release is never offered.
  final String releaseVersion;

  /// Handles the download/verify/stage lifecycle.
  final Updater updater;

  /// Live progress of the running check.
  ///
  /// Rebuild on it with a `ValueListenableBuilder`; the example app puts it
  /// under the app bar. The last outcome stays readable after a check ends.
  ValueListenable<FlutterOtaProgress> get progress => _progress;

  final ValueNotifier<FlutterOtaProgress> _progress =
      ValueNotifier<FlutterOtaProgress>(const FlutterOtaProgress());

  FlutterOtaState _state;

  static FlutterOta? _instance;

  /// The initialized instance. Throws if [initialize] has not been called.
  static FlutterOta get instance {
    final instance = _instance;
    if (instance == null) {
      throw StateError('FlutterOta.initialize() must be called before use.');
    }
    return instance;
  }

  /// Whether [initialize] has run.
  static bool get isInitialized => _instance != null;

  /// Bookkeeping as of the last platform read.
  FlutterOtaState get state => _state;

  /// Patch number this process is running; 0 means the code shipped in the APK.
  int get currentPatch => _state.patchActive ? _state.currentPatch : 0;

  /// Initializes Flutter OTA against the backend at [updateUrl].
  ///
  /// [packageName] and [releaseVersion] default to the running app's own, and
  /// only need supplying when you release under a different identity than the
  /// one baked into the APK.
  ///
  /// With [confirmLaunch] set, the running patch is marked good once the first
  /// frame renders; a patch that crashes before then is rolled back after a
  /// couple of launches. Turn it off to confirm by hand at a point that better
  /// reflects your app being healthy.
  ///
  /// With [checkOnStart] set, an update check runs in the background and any
  /// failure is logged rather than thrown — a backend being unreachable must
  /// not take the app down with it.
  static Future<FlutterOta> initialize({
    required String updateUrl,
    String? packageName,
    String? releaseVersion,
    bool confirmLaunch = true,
    bool checkOnStart = true,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();

    final state = await FlutterOtaPlatform.state();
    final resolvedPackage = packageName ?? state.packageName;
    final resolvedRelease = releaseVersion ?? state.releaseVersion;
    if (resolvedPackage == null || resolvedRelease == null) {
      throw StateError(
        'Flutter OTA could not read this app’s identity from the platform. '
        'Pass packageName and releaseVersion explicitly.',
      );
    }

    final flutter_ota = FlutterOta._(
      updateUrl: updateUrl,
      packageName: resolvedPackage,
      releaseVersion: resolvedRelease,
      state: state,
    );
    _instance = flutter_ota;

    debugPrint('[flutter_ota] $resolvedPackage $resolvedRelease — $state');

    if (confirmLaunch) {
      // Reaching a frame is the cheapest honest signal that the patched code
      // works. Anything earlier would confirm a snapshot that has barely run.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        flutter_ota.confirmLaunch();
      });
    }

    if (checkOnStart) {
      unawaited(flutter_ota.checkForUpdate());
    }

    return flutter_ota;
  }

  /// Checks for a newer patch and stages it for the next launch.
  ///
  /// Returns the staged patch number, or null if already up to date. Never
  /// throws: failures are logged, because a failed check should leave the app
  /// exactly as it was.
  Future<int?> checkForUpdate() async {
    if (!FlutterOtaPlatform.isSupported) return null;
    try {
      final staged = await updater.check(
        platform: 'android',
        releaseVersion: releaseVersion,
        currentPatch: _state.currentPatch,
        onProgress: _emit,
      );
      if (staged != null) _state = await FlutterOtaPlatform.state();
      return staged;
    } catch (error) {
      debugPrint('[flutter_ota] update check failed: $error');
      _emit(FlutterOtaProgress(
        stage: FlutterOtaStage.failed,
        error: error is UpdateClientException ? error.message : '$error',
      ));
      return null;
    }
  }

  /// Publishes [next], dropping download ticks too small to see. Chunks arrive
  /// every few kilobytes, and rebuilding on each one costs frames for nothing.
  void _emit(FlutterOtaProgress next) {
    final current = _progress.value;
    if (next.stage == FlutterOtaStage.downloading &&
        current.stage == FlutterOtaStage.downloading &&
        next.total > 0) {
      final delta = (next.fraction ?? 0) - (current.fraction ?? 0);
      if (delta < 0.01 && next.received < next.total) return;
    }
    _progress.value = next;
  }

  /// Marks the running patch as good, ending the crash-rollback countdown.
  ///
  /// Called for you after the first frame unless [initialize] was passed
  /// `confirmLaunch: false`.
  Future<void> confirmLaunch() async {
    await FlutterOtaPlatform.confirmLaunch();
    _state = await FlutterOtaPlatform.state();
  }

  /// Drops the active and staged patches; the next launch runs the APK's code.
  Future<void> rollback() async {
    await FlutterOtaPlatform.rollback();
    _state = await FlutterOtaPlatform.state();
  }
}
