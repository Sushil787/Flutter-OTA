import 'package:flutter_ota_cli/src/android_patcher.dart';
import 'package:test/test.dart';

void main() {
  group('patchMainActivity', () {
    test('gives a bodyless Kotlin class a body', () {
      const source = '''
package com.example.mybird_test

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
''';
      final result = patchMainActivity(source, isKotlin: true);

      expect(result.ok, isTrue);
      expect(result.outcome, PatchOutcome.injected);
      expect(result.source, contains('class MainActivity : FlutterActivity() {'));
      expect(result.source, contains('FlutterOtaPatch.applyTo'));
      expect('{'.allMatches(result.source!).length,
          '}'.allMatches(result.source!).length);
    });

    test('inserts into an existing Kotlin class body', () {
      const source = '''
package com.example.mybird_test

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
    }
}
''';
      final result = patchMainActivity(source, isKotlin: true);

      expect(result.outcome, PatchOutcome.injected);
      // The existing member survives, and the new block lands inside the class.
      expect(result.source, contains('configureFlutterEngine'));
      final body = result.source!;
      expect(body.indexOf('FlutterOtaPatch.applyTo'), lessThan(body.lastIndexOf('}')));
    });

    test('is idempotent', () {
      const source = 'class MainActivity : FlutterActivity()\n';
      final once = patchMainActivity(source, isKotlin: true);
      final twice = patchMainActivity(once.source!, isKotlin: true);

      expect(twice.outcome, PatchOutcome.unchanged);
      expect(twice.source, once.source);
      expect(beginMarker.allMatches(twice.source!).length, 1);
    });

    test('patches Java', () {
      const source = '''
package com.example.mybird_test;

import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {
}
''';
      final result = patchMainActivity(source, isKotlin: false);

      expect(result.outcome, PatchOutcome.injected);
      expect(result.source, contains('@Override'));
      expect(result.source, contains('FlutterOtaPatch.applyTo'));
    });

    test('is not fooled by braces in comments or strings', () {
      const source = '''
class MainActivity : FlutterActivity() {
    // a stray } in a comment
    private val label = "another } here"
}
''';
      final result = patchMainActivity(source, isKotlin: true);

      expect(result.outcome, PatchOutcome.injected);
      // The block belongs after the field, not wedged into the comment.
      final body = result.source!;
      expect(body.indexOf('private val label'),
          lessThan(body.indexOf('FlutterOtaPatch.applyTo')));
    });

    test('refuses rather than guessing when there is no MainActivity', () {
      final result = patchMainActivity('class Other\n', isKotlin: true);

      expect(result.ok, isFalse);
      expect(result.failure, contains('MainActivity'));
    });

    test('refuses when a previous block was left half-deleted', () {
      final result = patchMainActivity(
        'class MainActivity : FlutterActivity() {\n  $beginMarker\n}\n',
        isKotlin: true,
      );

      expect(result.ok, isFalse);
      expect(result.failure, contains(endMarker));
    });
  });
}
