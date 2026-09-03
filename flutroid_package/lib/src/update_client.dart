import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Talks to the Flutroid OTA backend.
///
/// Transport and JSON live here; what to *do* with an update lives in
/// `Updater`.
class UpdateClient {
  UpdateClient({
    required this.updateUrl,
    required this.packageName,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// Backend base URL, e.g. `http://10.0.2.2:8080` from an emulator.
  final String updateUrl;

  /// App identifier, e.g. `com.example.mybird_test`.
  final String packageName;

  final http.Client _http;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse(updateUrl).replace(path: path, queryParameters: query);

  /// `GET /api/v1/apps/<packageName>/updates?platform=&release=&patch=`
  ///
  /// Returns the available patch, or null when the server answers 204 (up to
  /// date). Throws [UpdateClientException] on any other non-200.
  Future<UpdateInfo?> checkForUpdate({
    required String platform,
    required String releaseVersion,
    required int currentPatch,
  }) async {
    // `Uri` percent-encodes the `+` in versions like `1.0.0+1`, which the
    // server needs — a raw `+` would decode as a space.
    final uri = _uri('/api/v1/apps/$packageName/updates', {
      'platform': platform,
      'release': releaseVersion,
      'patch': '$currentPatch',
    });

    final response = await _http.get(uri);
    if (response.statusCode == 204) return null;
    if (response.statusCode != 200) {
      throw UpdateClientException(
        'update check failed (${response.statusCode}): ${response.body}',
      );
    }
    return UpdateInfo.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Downloads an artifact, reporting bytes as they arrive.
  ///
  /// [onProgress] gets the bytes so far and the total, where the total is 0 if
  /// the server sent no `content-length`. The response is streamed rather than
  /// buffered so the count is real: a patch is a few megabytes, long enough on
  /// a phone to be worth showing.
  Future<Uint8List> download(
    String artifactUrl, {
    void Function(int received, int total)? onProgress,
  }) async {
    final uri = artifactUrl.startsWith('http')
        ? Uri.parse(artifactUrl)
        : _uri(artifactUrl);

    final response = await _http.send(http.Request('GET', uri));
    if (response.statusCode != 200) {
      throw UpdateClientException(
        'download failed (${response.statusCode}) for $uri',
      );
    }

    final total = response.contentLength ?? 0;
    final buffer = BytesBuilder(copy: false);
    // Report zero first so the bar appears empty rather than jumping in.
    onProgress?.call(0, total);

    await for (final chunk in response.stream) {
      buffer.add(chunk);
      onProgress?.call(buffer.length, total);
    }
    return buffer.takeBytes();
  }

  /// Releases the underlying HTTP client.
  void close() => _http.close();
}

/// What the server returns when a patch is available.
class UpdateInfo {
  const UpdateInfo({
    required this.patchNumber,
    required this.downloadUrl,
    required this.hash,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    final downloadUrl = json['downloadUrl'] as String?;
    final hash = json['hash'] as String?;
    if (downloadUrl == null || hash == null) {
      // A patch row with no artifact — nothing to install.
      throw UpdateClientException('update is missing downloadUrl or hash');
    }
    return UpdateInfo(
      patchNumber: json['patchNumber'] as int,
      downloadUrl: downloadUrl,
      hash: hash,
    );
  }

  final int patchNumber;
  final String downloadUrl;

  /// sha256 of the artifact; the download is verified against it.
  final String hash;

  @override
  String toString() => 'UpdateInfo(patch: $patchNumber, hash: $hash)';
}

/// Raised when the backend answers with something unusable.
class UpdateClientException implements Exception {
  const UpdateClientException(this.message);

  final String message;

  @override
  String toString() => 'UpdateClientException: $message';
}
