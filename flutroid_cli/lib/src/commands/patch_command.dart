import 'package:args/command_runner.dart';

/// `flutroid patch` — ship a code patch on top of an existing release.
///
/// Rough steps to implement:
///   1. rebuild the Dart code (new AOT snapshot)
///   2. (optional) diff it against the release's snapshot to shrink the patch
///   3. POST the bytes to /api/v1/apps/<appId>/patches?platform=&release=
///      with `Authorization: Bearer <token>` and Content-Type octet-stream.
class PatchCommand extends Command<int> {
  PatchCommand() {
    argParser
      ..addOption('app-id', help: 'App identifier.', mandatory: true)
      ..addOption('platform', help: 'android | ios', defaultsTo: 'android')
      ..addOption('release', help: 'Release version this patch targets.')
      ..addOption('artifact', help: 'Path to the patch artifact (else build it).')
      ..addOption('token', help: 'Upload token (or set FLUTROID_TOKEN).');
  }

  @override
  String get name => 'patch';

  @override
  String get description => 'Build and upload a patch for an existing release.';

  @override
  Future<int> run() async {
    // final server = globalResults?['server'] as String;
    // final token = argResults?['token'] ?? Platform.environment['FLUTROID_TOKEN'];
    // TODO: build (or use --artifact), then POST the bytes to the patches endpoint.
    print('TODO: patch');
    return 0;
  }
}
