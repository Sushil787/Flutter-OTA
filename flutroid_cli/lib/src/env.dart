import 'dart:io';

import 'package:path/path.dart' as p;

/// Reads settings from a `.env` file so the token is not a flag you retype.
///
/// The file is found by walking up from the app directory, so one `.env` at the
/// repo root covers every package under it. The server reads the same file.
///
/// Highest priority wins: a flag, then a real environment variable, then the
/// file. That order is what lets CI set a token with no `.env` checked out.

/// Parses `KEY=value` lines, allowing `export`, `#` comments and quotes.
Map<String, String> parseDotEnv(String source) {
  final values = <String, String>{};
  for (final raw in source.split('\n')) {
    var line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    if (line.startsWith('export ')) line = line.substring(7).trim();

    final eq = line.indexOf('=');
    if (eq <= 0) continue;

    final key = line.substring(0, eq).trim();
    var value = line.substring(eq + 1).trim();

    // Drop matching quotes, or trim a trailing comment off a bare value.
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    } else {
      final hash = value.indexOf(' #');
      if (hash >= 0) value = value.substring(0, hash).trim();
    }

    if (key.isNotEmpty) values[key] = value;
  }
  return values;
}

/// Finds the nearest `.env` at or above [start], or null.
File? findDotEnv(String start) {
  var dir = Directory(p.normalize(p.absolute(start)));
  while (true) {
    final candidate = File(p.join(dir.path, '.env'));
    if (candidate.existsSync()) return candidate;

    final parent = dir.parent;
    if (parent.path == dir.path) return null; // hit the filesystem root
    dir = parent;
  }
}

/// Loads the nearest `.env`, or an empty map when there is none.
Map<String, String> loadDotEnv({required String appDir}) {
  final file = findDotEnv(appDir) ?? findDotEnv(Directory.current.path);
  if (file == null) return const {};
  try {
    return parseDotEnv(file.readAsStringSync());
  } on IOException catch (error) {
    stderr.writeln('Warning: could not read ${file.path}: $error');
    return const {};
  }
}

/// Finds the upload token: `--token`, then the environment, then `.env`.
///
/// `UPLOAD_TOKEN` is accepted as well as `FLUTROID_TOKEN` because that is the
/// name the server uses, so one line in `.env` configures both.
String? resolveToken(String? explicit, {required String appDir}) {
  if (explicit != null && explicit.isNotEmpty) return explicit;

  for (final key in const ['FLUTROID_TOKEN', 'UPLOAD_TOKEN']) {
    final value = Platform.environment[key];
    if (value != null && value.isNotEmpty) return value;
  }

  final env = loadDotEnv(appDir: appDir);
  for (final key in const ['FLUTROID_TOKEN', 'UPLOAD_TOKEN']) {
    final value = env[key];
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

/// Finds the backend URL, so `--server` can be left off too.
///
/// [explicitly] tells a typed `--server` apart from the default the parser
/// filled in; a typed one always wins.
String resolveServer(
  String fallback, {
  required String appDir,
  required bool explicitly,
}) {
  if (explicitly) return fallback;

  final fromEnv = Platform.environment['FLUTROID_SERVER'];
  if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;

  final value = loadDotEnv(appDir: appDir)['FLUTROID_SERVER'];
  return (value != null && value.isNotEmpty) ? value : fallback;
}
