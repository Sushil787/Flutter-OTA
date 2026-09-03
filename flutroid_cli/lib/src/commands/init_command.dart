import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../android_patcher.dart';

/// `flutroid init` — wire Flutroid into a Flutter app's Android side.
///
/// Loading a patch needs one override in the app's own `MainActivity`, because
/// the snapshot path has to be handed to the engine before any plugin has been
/// registered. This writes it, and is safe to re-run: the block is fenced with
/// markers and regenerated in place.
class InitCommand extends Command<int> {
  InitCommand() {
    argParser
      ..addOption(
        'app',
        help: 'Path to the Flutter app to wire up.',
        defaultsTo: '.',
      )
      ..addFlag(
        'dry-run',
        help: 'Show what would change without writing anything.',
        negatable: false,
      );
  }

  @override
  String get name => 'init';

  @override
  String get description =>
      "Add Flutroid's patch loader to the app's Android MainActivity.";

  @override
  Future<int> run() async {
    final appDir = p.normalize(p.absolute(argResults!['app'] as String));
    final dryRun = argResults!['dry-run'] as bool;

    final pubspec = File(p.join(appDir, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      stderr.writeln('No pubspec.yaml in $appDir — is this a Flutter app?');
      return 1;
    }

    final activity = _findMainActivity(appDir);
    if (activity == null) {
      stderr
        ..writeln('Could not find MainActivity under')
        ..writeln('  ${p.join(appDir, 'android/app/src/main')}')
        ..writeln('Flutroid patches the app’s own Activity, so it needs one.');
      return 1;
    }

    final isKotlin = p.extension(activity.path) == '.kt';
    final result = patchMainActivity(activity.readAsStringSync(), isKotlin: isKotlin);
    if (!result.ok) {
      stderr
        ..writeln('Could not patch ${p.relative(activity.path, from: appDir)}:')
        ..writeln('  ${result.failure}')
        ..writeln()
        ..writeln('Add this to the class by hand instead:')
        ..writeln();
      stderr.writeln(_manualInstructions(isKotlin: isKotlin));
      return 1;
    }

    final relative = p.relative(activity.path, from: appDir);
    switch (result.outcome!) {
      case PatchOutcome.unchanged:
        stdout.writeln('$relative is already wired up.');
      case PatchOutcome.injected:
      case PatchOutcome.regenerated:
        if (dryRun) {
          stdout
            ..writeln('Would rewrite $relative as:')
            ..writeln()
            ..writeln(result.source);
        } else {
          activity.writeAsStringSync(result.source!);
          final verb = result.outcome == PatchOutcome.injected
              ? 'Patched'
              : 'Regenerated the Flutroid block in';
          stdout.writeln('$verb $relative');
        }
    }

    _warnIfDependencyMissing(pubspec);

    stdout
      ..writeln()
      ..writeln('Next: initialize the updater early in main().')
      ..writeln()
      ..writeln("  await Flutroid.initialize(updateUrl: 'http://10.0.2.2:8080');")
      ..writeln()
      ..writeln('Then cut a release with `flutroid release`, and ship changes')
      ..writeln('with `flutroid patch`. Patches load on the next cold start.');
    return 0;
  }

  /// The app's `MainActivity.kt` or `.java`, wherever the template put it.
  File? _findMainActivity(String appDir) {
    for (final language in const ['kotlin', 'java']) {
      final root = Directory(p.join(appDir, 'android/app/src/main', language));
      if (!root.existsSync()) continue;
      final matches = root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => const {'MainActivity.kt', 'MainActivity.java'}
              .contains(p.basename(file.path)))
          .toList();
      if (matches.isNotEmpty) return matches.first;
    }
    return null;
  }

  /// The override references `dev.flutroid.FlutroidPatch`, which reaches the
  /// app's classpath through the plugin — so the dependency has to be there.
  void _warnIfDependencyMissing(File pubspec) {
    if (pubspec.readAsStringSync().contains('flutroid_package')) return;
    stdout
      ..writeln()
      ..writeln('Note: flutroid_package is not in ${p.basename(pubspec.path)}.')
      ..writeln('The override will not compile without it. Add:')
      ..writeln()
      ..writeln('  dependencies:')
      ..writeln('    flutroid_package:')
      ..writeln('      path: ../flutroid_package');
  }

  String _manualInstructions({required bool isKotlin}) => isKotlin
      ? '''
  override fun getFlutterShellArgs(): io.flutter.embedding.engine.FlutterShellArgs =
      dev.flutroid.FlutroidPatch.applyTo(this, super.getFlutterShellArgs())
'''
      : '''
  @Override
  public io.flutter.embedding.engine.FlutterShellArgs getFlutterShellArgs() {
      return dev.flutroid.FlutroidPatch.applyTo(this, super.getFlutterShellArgs());
  }
''';
}
