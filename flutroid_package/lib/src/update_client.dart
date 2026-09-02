/// Talks to the Flutroid OTA backend.
///
/// Thin HTTP wrapper around the server's API. Keep transport/JSON here;
/// keep the "what to do with an update" logic in [Updater].
class UpdateClient {
  UpdateClient({required this.updateUrl, required this.packageName});

  /// Backend base URL, e.g. http://localhost:8080
  final String updateUrl;

  /// App identifier, e.g. com.example.mybird_test
  final String packageName;

  /// GET /api/v1/apps/<packageName>/updates?platform=&release=&patch=
  ///
  /// Returns the available patch descriptor, or null if up to date.
  Future<UpdateInfo?> checkForUpdate({
    required String platform,
    required String releaseVersion,
    required int currentPatch,
  }) async {
    // TODO: build the query, GET it, parse the JSON body.
    throw UnimplementedError();
  }

  /// Downloads an artifact's bytes from the server's download URL.
  Future<List<int>> download(String artifactUrl) async {
    // TODO: GET the artifact bytes (stream to a file in Updater).
    throw UnimplementedError();
  }
}

/// What the server returns when a patch is available.
class UpdateInfo {
  UpdateInfo({
    required this.patchNumber,
    required this.downloadUrl,
    required this.hash,
  });

  final int patchNumber;
  final String downloadUrl;
  final String hash; // verify the download against this

  // TODO: fromJson
}
