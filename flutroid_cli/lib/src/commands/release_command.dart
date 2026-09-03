import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../uploader.dart';

/// `flutroid release` — upload the baseline snapshot an app ships with.
///
/// A release is the code inside the APK. Patches are scoped to one, and only
/// load on an app built from the same Flutter/engine version and ABI, so cut a
/// fresh release whenever any of those change.
class ReleaseCommand extends Command<int> {
  ReleaseCommand() {
    argParser
      ..addOption('app-id', help: 'App identifier.', mandatory: true)
      ..addOption('app', help: 'Path to the Flutter app.', defaultsTo: '.')
      ..addOption('platform', help: 'android | ios', defaultsTo: 'android')
      ..addOption('version', help: 'Release version, e.g. 1.0.0+1.', mandatory: true)
      ..addOption('abi', help: 'Android ABI to upload.', defaultsTo: 'arm64-v8a')
      ..addOption('artifact', help: 'libapp.so to upload (else the build output).')
      ..addOption('token', help: 'Upload token (or set FLUTROID_TOKEN).');
  }

  @override
  String get name => 'release';

  @override
  String get description => 'Upload a new base release.';

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
        ..writeln('No libapp.so found. Build the app first:')
        ..writeln('  flutter build apk --release')
        ..writeln('or pass --artifact <path>.');
      return 1;
    }

    return uploadArtifact(
      server: globalResults!['server'] as String,
      path: '/api/v1/apps/${args['app-id']}/releases',
      query: {
        'platform': args['platform'] as String,
        'version': args['version'] as String,
      },
      artifact: artifact,
      token: token,
    );
  }
}
