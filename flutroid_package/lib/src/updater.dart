import 'update_client.dart';

/// Orchestrates the on-device update lifecycle.
///
/// Call [check] early in `main()` (before/around `runApp`). Downloaded patches
/// are staged on disk; the patched engine loads them on the next launch.
class Updater {
  Updater({required this.client});

  final UpdateClient client;

  /// Checks the server and, if a newer patch exists, downloads + stages it.
  ///
  /// Returns true if a patch was staged (so you can decide whether to prompt
  /// the user to restart).
  Future<bool> check({
    required String platform,
    required String releaseVersion,
    required int currentPatch,
  }) async {
    final info = await client.checkForUpdate(
      platform: platform,
      releaseVersion: releaseVersion,
      currentPatch: currentPatch,
    );
    if (info == null) return false;

    // TODO:
    //   1. download bytes via client.download(info.downloadUrl)
    //   2. verify hash == info.hash
    //   3. write to the engine's staging path (app-private dir)
    //   4. record the new patch number so next check compares correctly
    throw UnimplementedError();
  }

  /// The patch number currently installed/staged on this device.
  Future<int> currentPatchNumber() async {
    // TODO: read from local storage; 0 = only the base release.
    throw UnimplementedError();
  }
}
