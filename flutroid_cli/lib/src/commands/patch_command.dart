import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../uploader.dart';

/// `flutroid patch` — ship changed Dart code on top of an existing release.
///
/// The artifact is a whole `libapp.so`, not a diff: diffs are applied inside
/// the engine, and Flutroid deliberately does not go there. Rebuild the app
/// with the same Flutter version and ABI as the release, then upload.
class PatchCommand extends Command<int> {
  PatchCommand() {
    argParser
      ..addOption('app-id', help: 'App identifier.', mandatory: true)
      ..addOption('app', help: 'Path to the Flutter app.', defaultsTo: '.')
      ..addOption('platform', help: 'android | ios', defaultsTo: 'android')
      ..addOption('release', help: 'Release version this patch targets.', mandatory: true)
      ..addOption('abi', help: 'Android ABI to upload.', defaultsTo: 'arm64-v8a')
      ..addOption('artifact', help: 'libapp.so to upload (else the build output).')
      ..addOption('token', help: 'Upload token (or set FLUTROID_TOKEN).');
  }

  @override
  String get name => 'patch';

  @override
  String get description => 'Upload a patch for an existing release.';

  @override
  Future<int> run() async {
    final args = argResults!;
    final appDir = p.normalize(p.absolute(args['app'] as String));

    final token = resolveToken(args['token'] as String?);
    if (token == null) {
      stderr.writeln('Set --token or FLUTROID_TOKEN.');
      return 1;
    }

    final artifact = resolveArtifact(
      args['artifact'] as String?,
      appDir: appDir,
      abi: args['abi'] as String,
    );
    if (artifact == null) {
      stderr
        ..writeln('No libapp.so found. Rebuild the app first:')
        ..writeln('  flutter build apk --release')
        ..writeln('or pass --artifact <path>.');
      return 1;
    }

    return uploadArtifact(
      server: globalResults!['server'] as String,
      path: '/api/v1/apps/${args['app-id']}/patches',
      query: {
        'platform': args['platform'] as String,
        'release': args['release'] as String,
      },
      artifact: artifact,
      token: token,
    );
  }
}
