import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../app_info.dart';
import '../env.dart';
import '../uploader.dart';

/// `flutter_ota patch` — ship changed Dart code on top of an existing release.
///
/// The artifact is a whole `libapp.so`, not a diff: diffs are applied inside
/// the engine, and Flutter OTA deliberately does not go there. Rebuild the app
/// with the same Flutter version and ABI as the release, then upload.
///
/// Everything but the rebuild is derived: the app id from `applicationId`, the
/// release from `pubspec.yaml`, the token from `.env`, and the patch *number*
/// from the server, which hands out the next one for that release.
class PatchCommand extends Command<int> {
  PatchCommand() {
    argParser
      ..addOption('app', help: 'Path to the Flutter app.', defaultsTo: '.')
      ..addOption('app-id', help: 'App identifier (default: the Android applicationId).')
      ..addOption('platform', help: 'android | ios', defaultsTo: 'android')
      ..addOption('release', help: 'Release this patch targets (default: the pubspec version).')
      ..addOption('abi', help: 'Android ABI to upload.', defaultsTo: 'arm64-v8a')
      ..addOption('artifact', help: 'libapp.so to upload (else the build output).')
      ..addOption('token', help: 'Upload token (default: FLUTTER_OTA_TOKEN or .env).');
  }

  @override
  String get name => 'patch';

  @override
  String get description => 'Upload a patch for an existing release.';

  @override
  Future<int> run() async {
    final args = argResults!;
    final appDir = p.normalize(p.absolute(args['app'] as String));

    final appId = resolveOrDerive(
      args['app-id'] as String?,
      label: 'app id',
      flag: '--app-id',
      source: 'android/app/build.gradle',
      derive: () => readApplicationId(appDir),
    );
    if (appId == null) return 1;

    // A patch targets the release the *installed* app reports, so this must
    // stay the version that app was built from — do not bump it to ship code.
    final release = resolveOrDerive(
      args['release'] as String?,
      label: 'release',
      flag: '--release',
      source: 'pubspec.yaml',
      derive: () => readPubspecVersion(appDir),
    );
    if (release == null) return 1;

    final token = resolveToken(args['token'] as String?, appDir: appDir);
    if (token == null) {
      stderr
        ..writeln('No upload token. Add one to .env:')
        ..writeln('  UPLOAD_TOKEN=dev-secret')
        ..writeln('or pass --token / set FLUTTER_OTA_TOKEN.');
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
      server: resolveServer(
        globalResults!['server'] as String,
        appDir: appDir,
        explicitly: globalResults!.wasParsed('server'),
      ),
      path: '/api/v1/apps/$appId/patches',
      query: {'platform': args['platform'] as String, 'release': release},
      artifact: artifact,
      token: token,
    );
  }
}
