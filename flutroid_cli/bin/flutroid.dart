import 'package:flutroid_cli/src/command_runner.dart';

Future<void> main(List<String> args) async {
  await FlutroidCommandRunner().run(args);
}
