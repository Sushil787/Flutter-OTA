import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:flutter_ota_cli/src/command_runner.dart';

Future<void> main(List<String> args) async {
  try {
    exitCode = await FlutterOtaCommandRunner().run(args) ?? 0;
  } on UsageException catch (error) {
    stderr.writeln(error);
    exitCode = 64; // EX_USAGE
  }
}
