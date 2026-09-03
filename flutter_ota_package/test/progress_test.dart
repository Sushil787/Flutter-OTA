import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ota_package/flutter_ota_package.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The updater's progress reporting, against a stubbed backend.
///
/// Staging needs the Android side, so these stop at the download: the point is
/// that bytes arriving turn into progress a UI can bind to.
void main() {
  const artifact = '/download/abc';

  UpdateClient clientFor(MockClient http) =>
      UpdateClient(updateUrl: 'http://test', packageName: 'app', httpClient: http);

  test('reports download progress against a known content-length', () async {
    final body = List<int>.filled(4096, 7);
    final client = clientFor(MockClient((request) async {
      return http.Response.bytes(body, 200, headers: {
        'content-length': '${body.length}',
      });
    }));

    final seen = <int>[];
    final bytes = await client.download(
      artifact,
      onProgress: (received, total) {
        expect(total, body.length);
        seen.add(received);
      },
    );

    expect(bytes.length, body.length);
    expect(seen.first, 0, reason: 'emits a zero tick so the bar starts at empty');
    expect(seen.last, body.length, reason: 'ends at 100%');
  });

  test('a missing content-length leaves the fraction null', () {
    const progress = FlutterOtaProgress(
      stage: FlutterOtaStage.downloading,
      received: 1024,
    );
    expect(progress.fraction, isNull, reason: 'so the UI shows an indeterminate bar');
    expect(progress.isBusy, isTrue);
  });

  test('fraction tracks received/total', () {
    const progress = FlutterOtaProgress(
      stage: FlutterOtaStage.downloading,
      received: 512,
      total: 1024,
      patchNumber: 3,
    );
    expect(progress.fraction, 0.5);
    expect(progress.label, contains('patch 3'));
  });

  test('up to date short-circuits before any download', () async {
    var downloads = 0;
    final client = clientFor(MockClient((request) async {
      if (request.url.path.contains('/updates')) return http.Response('', 204);
      downloads++;
      return http.Response.bytes(const [], 200);
    }));

    final stages = <FlutterOtaStage>[];
    final staged = await Updater(client: client).check(
      platform: 'android',
      releaseVersion: '1.0.0+1',
      currentPatch: 0,
      onProgress: (p) => stages.add(p.stage),
    );

    expect(staged, isNull);
    expect(downloads, 0);
    expect(stages, [FlutterOtaStage.checking, FlutterOtaStage.upToDate]);
  });

  test('a corrupt download is rejected before it is staged', () async {
    final client = clientFor(MockClient((request) async {
      if (request.url.path.contains('/updates')) {
        return http.Response(
          jsonEncode({
            'patchNumber': 1,
            'hash': 'not-the-real-hash',
            'downloadUrl': artifact,
          }),
          200,
        );
      }
      return http.Response.bytes(List<int>.filled(16, 1), 200);
    }));

    await expectLater(
      Updater(client: client).check(
        platform: 'android',
        releaseVersion: '1.0.0+1',
        currentPatch: 0,
      ),
      throwsA(isA<UpdateClientException>()),
    );
  });
}
