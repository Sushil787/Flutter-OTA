import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'flutroid_platform.dart';
import 'update_client.dart';

/// Orchestrates the on-device update lifecycle: check, download, verify, stage.
///
/// Staging is all this can do — the engine reads the snapshot path once, before
/// the Dart VM starts, so a patch downloaded now is loaded at the next launch.
class Updater {
  Updater({required this.client});

  final UpdateClient client;

  /// Checks the server and, if a newer patch exists, downloads and stages it.
  ///
  /// Returns the staged patch number, or null if the app is already up to date.
  /// Network and server failures propagate; being unable to reach the backend
  /// is the caller's business, not a reason to disturb a working app.
  Future<int?> check({
    required String platform,
    required String releaseVersion,
    required int currentPatch,
  }) async {
    final info = await client.checkForUpdate(
      platform: platform,
      releaseVersion: releaseVersion,
      currentPatch: currentPatch,
    );
    if (info == null) return null;

    final bytes = await client.download(info.downloadUrl);

    // Verify before the bytes go anywhere near the engine's load path. The
    // native side hashes them again after the channel hop; both checks are
    // cheap next to the cost of handing the engine a corrupt snapshot.
    final actual = sha256.convert(bytes).toString();
    if (actual != info.hash) {
      throw UpdateClientException(
        'patch ${info.patchNumber} failed verification: '
        'expected ${info.hash}, got $actual',
      );
    }

    final staged = await FlutroidPlatform.stage(
      patchNumber: info.patchNumber,
      bytes: bytes,
      sha256: info.hash,
    );
    if (!staged) {
      throw UpdateClientException('patch ${info.patchNumber} could not be staged');
    }

    debugPrint('[flutroid] staged patch ${info.patchNumber}; active next launch');
    return info.patchNumber;
  }
}
