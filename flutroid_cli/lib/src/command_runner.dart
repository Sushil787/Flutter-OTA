import 'package:args/command_runner.dart';

import 'commands/init_command.dart';
import 'commands/patch_command.dart';
import 'commands/release_command.dart';

/// `flutroid` — the OTA CLI.
///
///   flutroid init      wire the patch loader into an app's Android side
///   flutroid release   upload the baseline snapshot the app ships with
///   flutroid patch     upload new Dart code for an existing release
class FlutroidCommandRunner extends CommandRunner<int> {
  FlutroidCommandRunner() : super('flutroid', 'Flutroid OTA command-line tool.') {
    argParser.addOption(
      'server',
      help: 'Backend base URL.',
      defaultsTo: 'http://localhost:8080',
    );
    addCommand(InitCommand());
    addCommand(ReleaseCommand());
    addCommand(PatchCommand());
  }
}
