import 'dart:io';

import 'package:path/path.dart' as p;

/// Reads the app's id and version out of its own project files.
///
/// These have to match what the device reports, or the update check finds
/// nothing and says nothing. Reading them from the project keeps both sides in
/// step without anyone retyping them.

/// The version from `pubspec.yaml`, e.g. `1.0.0+1`.
///
/// Flutter passes the same value to Gradle, so it is also what the app reports
/// back as its release.
String? readPubspecVersion(String appDir) {
  final pubspec = File(p.join(appDir, 'pubspec.yaml'));
  if (!pubspec.existsSync()) return null;

  for (final line in pubspec.readAsLinesSync()) {
    // Top-level only, so an indented `version:` under a dependency is skipped.
    final match = RegExp(r'^version:\s*(\S+)').firstMatch(line);
    if (match != null) return match.group(1)!.replaceAll(RegExp(r'''^["']|["']$'''), '');
  }
  return null;
}

/// The Android `applicationId`, e.g. `com.example.mybird_test`.
///
/// Falls back to `namespace`, which is what the id defaults to when unset.
String? readApplicationId(String appDir) {
  for (final name in const ['build.gradle.kts', 'build.gradle']) {
    final gradle = File(p.join(appDir, 'android', 'app', name));
    if (!gradle.existsSync()) continue;

    final source = gradle.readAsStringSync();
    for (final key in const ['applicationId', 'namespace']) {
      // Handles `applicationId = "x"` (kts) and `applicationId "x"` (groovy).
      final match = RegExp('$key\\s*=?\\s*"([^"]+)"').firstMatch(source);
      final value = match?.group(1);
      if (value != null && value.contains('.')) return value;
    }
  }
  return null;
}

/// Uses what the caller passed, else works it out, else explains what to pass.
///
/// Prints whatever it worked out. A value picked up silently is the thing you
/// want to see in the log when a patch lands on the wrong release.
String? resolveOrDerive(
  String? explicit, {
  required String label,
  required String flag,
  required String? Function() derive,
  required String source,
}) {
  if (explicit != null && explicit.isNotEmpty) return explicit;

  final derived = derive();
  if (derived == null) {
    stderr
      ..writeln('Could not read the $label from $source.')
      ..writeln('Pass $flag explicitly.');
    return null;
  }
  stdout.writeln('$label: $derived  (from $source)');
  return derived;
}
