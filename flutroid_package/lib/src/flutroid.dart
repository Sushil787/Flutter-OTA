import 'update_client.dart';
import 'updater.dart';

/// Entry point for the Flutroid OTA updater.
///
/// Call [initialize] once with your app's package name and the backend URL,
/// then use [instance] (or [checkForUpdate]) to drive updates.
class Flutroid {
  Flutroid._({required this.packageName, required this.updateUrl})
      : updater = Updater(
          client: UpdateClient(
            updateUrl: updateUrl,
            packageName: packageName,
          ),
        );

  /// Identifier for this app, e.g. `com.example.mybird_test`.
  final String packageName;

  /// Base URL of the Flutroid backend, e.g.
  /// `https://flutroid-ota.<account>.workers.dev`.
  final String updateUrl;

  /// Handles the download/verify/stage lifecycle.
  final Updater updater;

  static Flutroid? _instance;

  /// The initialized instance. Throws if [initialize] hasn't been called.
  static Flutroid get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('Flutroid.initialize() must be called before use.');
    }
    return i;
  }

  /// Whether [initialize] has run.
  static bool get isInitialized => _instance != null;

  /// Initialize Flutroid with the app's [packageName] and backend [updateUrl].
  static Future<Flutroid> initialize({
    required String packageName,
    required String updateUrl,
  }) async {
    final flutroid = Flutroid._(packageName: packageName, updateUrl: updateUrl);
    _instance = flutroid;
    // TODO: load persisted state (installed release/patch), optionally kick off
    //       an initial update check here.
    return flutroid;
  }

  /// Convenience: check the backend for a newer patch and stage it if found.
  Future<bool> checkForUpdate({
    required String platform,
    required String releaseVersion,
  }) {
    return updater.check(
      platform: platform,
      releaseVersion: releaseVersion,
      currentPatch: 0, // TODO: read the actual installed patch number
    );
  }
}
