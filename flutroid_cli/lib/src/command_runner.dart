import 'package:args/command_runner.dart';

import 'commands/release_command.dart';
import 'commands/patch_command.dart';

/// `flutroid` — the OTA CLI.
///
///   flutroid release   build the app with the local engine and upload a base release
///   flutroid patch     build the new Dart code and upload it as a patch
class FlutroidCommandRunner extends CommandRunner<int> {
  FlutroidCommandRunner()
      : super('flutroid', 'Flutroid OTA command-line tool.') {
    argParser.addOption(
      'server',
      help: 'Backend base URL.',
      defaultsTo: 'http://localhost:8080',
    );
    addCommand(ReleaseCommand());
    addCommand(PatchCommand());
  }
}
