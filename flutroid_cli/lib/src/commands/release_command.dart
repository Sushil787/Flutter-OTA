import 'package:args/command_runner.dart';

/// `flutroid release` — cut a new base release.
///
/// Rough steps to implement:
///   1. flutter build apk --local-engine=... (the base the patches sit on)
///   2. locate the produced artifact (libapp.so / the AOT snapshot)
///   3. POST the bytes to /api/v1/apps/<appId>/releases?platform=&version=
///      with `Authorization: Bearer <token>` and Content-Type octet-stream.
class ReleaseCommand extends Command<int> {
  ReleaseCommand() {
    argParser
      ..addOption('app-id', help: 'App identifier.', mandatory: true)
      ..addOption('platform', help: 'android | ios', defaultsTo: 'android')
      ..addOption('version', help: 'Release version, e.g. 1.0.0+1.')
      ..addOption('artifact', help: 'Path to the artifact to upload (else build it).')
      ..addOption('token', help: 'Upload token (or set FLUTROID_TOKEN).');
  }

  @override
  String get name => 'release';

  @override
  String get description => 'Build and upload a new base release.';

  @override
  Future<int> run() async {
    // final server = globalResults?['server'] as String;
    // final token = argResults?['token'] ?? Platform.environment['FLUTROID_TOKEN'];
    // TODO: build (or use --artifact), then POST the bytes to the releases endpoint.
    print('TODO: release');
    return 0;
  }
}
