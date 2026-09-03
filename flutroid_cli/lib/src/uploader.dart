import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Shared upload path for `flutroid release` and `flutroid patch`.
///
/// Both endpoints take the artifact as the raw request body and everything else
/// as query parameters, behind a bearer token.
Future<int> uploadArtifact({
  required String server,
  required String path,
  required Map<String, String> query,
  required File artifact,
  required String token,
}) async {
  final bytes = artifact.readAsBytesSync();
  // `Uri` percent-encodes the `+` in versions like `1.0.0+1`; a raw `+` would
  // reach the server decoded as a space.
  final uri = Uri.parse(server).replace(path: path, queryParameters: query);

  stdout.writeln('Uploading ${_size(bytes.length)} to $uri');

  final response = await http.post(
    uri,
    headers: {
      'authorization': 'Bearer $token',
      'content-type': 'application/octet-stream',
    },
    body: bytes,
  );

  if (response.statusCode >= 300) {
    stderr.writeln('Upload failed (${response.statusCode}): ${response.body}');
    return 1;
  }

  final body = jsonDecode(response.body) as Map<String, dynamic>;
  stdout
    ..writeln('✓ uploaded')
    ..writeln(const JsonEncoder.withIndent('  ').convert(body));
  return 0;
}

/// Resolves the AOT snapshot to upload.
///
/// [explicit] wins; otherwise this looks where `flutter build apk --release`
/// leaves `libapp.so`. Returns null if nothing usable was found.
File? resolveArtifact(String? explicit, {required String appDir, required String abi}) {
  if (explicit != null) {
    final file = File(p.normalize(p.absolute(explicit)));
    return file.existsSync() ? file : null;
  }

  for (final mode in const ['release', 'profile']) {
    final capitalized = mode[0].toUpperCase() + mode.substring(1);
    for (final template in _artifactPaths) {
      final relative = template
          .replaceAll('<mode>', mode)
          .replaceAll('<Mode>', capitalized)
          .replaceAll('<abi>', abi);
      final candidate = File(p.join(appDir, relative));
      if (candidate.existsSync()) return candidate;
    }
  }
  return null;
}

/// Where Gradle leaves `libapp.so`, most-shipped copy first.
///
/// `stripped_native_libs` is what actually lands in the APK; the others are
/// where older Flutter versions put it.
const List<String> _artifactPaths = [
  'build/app/intermediates/stripped_native_libs/<mode>/'
      'strip<Mode>DebugSymbols/out/lib/<abi>/libapp.so',
  'build/app/intermediates/merged_native_libs/<mode>/'
      'merge<Mode>NativeLibs/out/lib/<abi>/libapp.so',
  'build/app/intermediates/flutter/<mode>/<abi>/libapp.so',
];

/// Reads the upload token from `--token` or `FLUTROID_TOKEN`.
String? resolveToken(String? explicit) =>
    explicit ?? Platform.environment['FLUTROID_TOKEN'];

String _size(int bytes) => '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
