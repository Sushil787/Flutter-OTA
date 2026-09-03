import 'dart:async';

import 'package:flutter/widgets.dart';

import 'flutroid_platform.dart';
import 'update_client.dart';
import 'updater.dart';

/// Entry point for the Flutroid OTA updater.
///
/// ```dart
/// void main() async {
///   await Flutroid.initialize(updateUrl: 'http://10.0.2.2:8080');
///   runApp(const MyApp());
/// }
/// ```
///
/// The app's package name and release version come from the platform, so the
/// backend URL is the only thing you have to supply.
class Flutroid {
  Flutroid._({
    required this.updateUrl,
    required this.packageName,
    required this.releaseVersion,
    required FlutroidState state,
  }) : _state = state,
       updater = Updater(
         client: UpdateClient(updateUrl: updateUrl, packageName: packageName),
       );

  /// Base URL of the Flutroid backend.
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

  FlutroidState _state;

  static Flutroid? _instance;

  /// The initialized instance. Throws if [initialize] has not been called.
  static Flutroid get instance {
    final instance = _instance;
    if (instance == null) {
      throw StateError('Flutroid.initialize() must be called before use.');
    }
    return instance;
  }

  /// Whether [initialize] has run.
  static bool get isInitialized => _instance != null;

  /// Bookkeeping as of the last platform read.
  FlutroidState get state => _state;

  /// Patch number this process is running; 0 means the code shipped in the APK.
  int get currentPatch => _state.patchActive ? _state.currentPatch : 0;

  /// Initializes Flutroid against the backend at [updateUrl].
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
  static Future<Flutroid> initialize({
    required String updateUrl,
    String? packageName,
    String? releaseVersion,
    bool confirmLaunch = true,
    bool checkOnStart = true,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();

    final state = await FlutroidPlatform.state();
    final resolvedPackage = packageName ?? state.packageName;
    final resolvedRelease = releaseVersion ?? state.releaseVersion;
    if (resolvedPackage == null || resolvedRelease == null) {
      throw StateError(
        'Flutroid could not read this app’s identity from the platform. '
        'Pass packageName and releaseVersion explicitly.',
      );
    }

    final flutroid = Flutroid._(
      updateUrl: updateUrl,
      packageName: resolvedPackage,
      releaseVersion: resolvedRelease,
      state: state,
    );
    _instance = flutroid;

    debugPrint('[flutroid] $resolvedPackage $resolvedRelease — $state');

    if (confirmLaunch) {
      // Reaching a frame is the cheapest honest signal that the patched code
      // works. Anything earlier would confirm a snapshot that has barely run.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        flutroid.confirmLaunch();
      });
    }

    if (checkOnStart) {
      unawaited(flutroid.checkForUpdate());
    }

    return flutroid;
  }

  /// Checks for a newer patch and stages it for the next launch.
  ///
  /// Returns the staged patch number, or null if already up to date. Never
  /// throws: failures are logged, because a failed check should leave the app
  /// exactly as it was.
  Future<int?> checkForUpdate() async {
    if (!FlutroidPlatform.isSupported) return null;
    try {
      final staged = await updater.check(
        platform: 'android',
        releaseVersion: releaseVersion,
        currentPatch: _state.currentPatch,
      );
      if (staged != null) _state = await FlutroidPlatform.state();
      return staged;
    } catch (error) {
      debugPrint('[flutroid] update check failed: $error');
      return null;
    }
  }

  /// Marks the running patch as good, ending the crash-rollback countdown.
  ///
  /// Called for you after the first frame unless [initialize] was passed
  /// `confirmLaunch: false`.
  Future<void> confirmLaunch() async {
    await FlutroidPlatform.confirmLaunch();
    _state = await FlutroidPlatform.state();
  }

  /// Drops the active and staged patches; the next launch runs the APK's code.
  Future<void> rollback() async {
    await FlutroidPlatform.rollback();
    _state = await FlutroidPlatform.state();
  }
}
