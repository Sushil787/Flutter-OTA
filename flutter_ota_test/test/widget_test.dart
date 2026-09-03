import 'package:flutter_ota_package/flutter_ota_package.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mybird_test/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dev.flutterota/flutter_ota');
  var confirmed = false;

  /// Stands in for the Android side, which is not present in a widget test.
  void mockPlatform({int currentPatch = 0, int stagedPatch = 0}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'state':
          return <String, Object?>{
            'currentPatch': currentPatch,
            'stagedPatch': stagedPatch,
            'confirmed': confirmed,
            'bootAttempts': 0,
            'patchActive': currentPatch != 0,
            'packageName': 'com.example.mybird_test',
            'releaseVersion': '1.0.0+1',
          };
        case 'confirmLaunch':
          confirmed = true;
          return null;
        default:
          return null;
      }
    });
  }

  setUp(() => confirmed = false);

  testWidgets('shows the build marker and the bundled-code state', (tester) async {
    mockPlatform();
    await FlutterOta.initialize(updateUrl: 'http://example.invalid', checkOnStart: false);

    await tester.pumpWidget(const FlutterOtaDemo());
    await tester.pumpAndSettle();

    expect(find.text(kBuildMarker), findsOneWidget);
    expect(find.text('1.0.0+1'), findsOneWidget);
    expect(find.text('the code in the APK'), findsOneWidget);
  });

  testWidgets('reports a running patch and one staged for next launch', (tester) async {
    mockPlatform(currentPatch: 3, stagedPatch: 4);
    await FlutterOta.initialize(updateUrl: 'http://example.invalid', checkOnStart: false);

    await tester.pumpWidget(const FlutterOtaDemo());
    await tester.pumpAndSettle();

    expect(find.text('patch 3'), findsOneWidget);
    expect(find.text('patch 4, loads next launch'), findsOneWidget);
  });

  testWidgets('confirms the launch once a frame has rendered', (tester) async {
    mockPlatform(currentPatch: 2);
    await FlutterOta.initialize(updateUrl: 'http://example.invalid', checkOnStart: false);

    expect(confirmed, isFalse, reason: 'nothing has rendered yet');

    await tester.pumpWidget(const FlutterOtaDemo());
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
  });
}
