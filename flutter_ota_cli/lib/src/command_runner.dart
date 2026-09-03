import 'package:args/command_runner.dart';

import 'commands/init_command.dart';
import 'commands/patch_command.dart';

/// `flutter_ota` — the OTA CLI.
///
///   flutter_ota init      wire the patch loader into an app's Android side
///   flutter_ota patch     upload new Dart code for the release an app was built as
///
/// There is no `release` command: a patch is filed under the version the app
/// reports for itself, and the update check reads only the patches table, so
/// nothing has to register a baseline first.
class FlutterOtaCommandRunner extends CommandRunner<int> {
  FlutterOtaCommandRunner() : super('flutter_ota', 'Flutter OTA command-line tool.') {
    argParser.addOption(
      'server',
      help: 'Backend base URL.',
      defaultsTo: 'http://localhost:8080',
    );
    addCommand(InitCommand());
    addCommand(PatchCommand());
  }
}
