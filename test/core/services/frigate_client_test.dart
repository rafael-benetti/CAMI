import 'dart:io';
import 'dart:convert';

import 'package:cami/core/services/frigate_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('uses the public Frigate endpoint by default', () {
    expect(FrigateClient().baseUrl, 'https://cameraspmi.creativewave.com.br');
  });

  test('authenticates with Frigate and lists configured cameras', () async {
    final client = MockClient((request) async {
      switch (request.url.path) {
        case '/api/login':
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {
            'user': 'operator',
            'password': 'correct-password',
          });
          return http.Response(
            '{}',
            200,
            headers: const {'set-cookie': 'frigate_token=test-jwt; HttpOnly'},
          );
        case '/api/auth':
          expect(request.headers['authorization'], 'Bearer test-jwt');
          return http.Response(
            '',
            202,
            headers: const {'remote-user': 'operator', 'remote-role': 'viewer'},
          );
        case '/api/config':
          expect(request.headers['authorization'], 'Bearer test-jwt');
          return http.Response(
            jsonEncode({
              'cameras': {'entrada_principal': {}, 'fundos': {}},
            }),
            200,
          );
        case '/api/go2rtc/streams':
          return http.Response('{}', 200);
        case '/api/metrics':
          expect(request.headers['authorization'], 'Bearer test-jwt');
          return http.Response('''
frigate_storage_free_bytes{storage="/media/frigate/recordings"} 750000000000
frigate_storage_total_bytes{storage="/media/frigate/recordings"} 1000000000000
frigate_storage_used_bytes{storage="/media/frigate/recordings"} 250000000000
''', 200);
        case '/api/entrada_principal/recordings':
          expect(request.headers['authorization'], 'Bearer test-jwt');
          expect(request.url.queryParameters['after'], isNotNull);
          expect(request.url.queryParameters['before'], isNotNull);
          return http.Response(
            jsonEncode([
              {'start_time': 1760130000.0, 'end_time': 1760130060.0},
            ]),
            200,
          );
      }
      fail('Unexpected request: ${request.url}');
    });
    final frigate = FrigateClient(
      baseUrl: 'http://frigate.local:5001',
      client: client,
    );

    final session = await frigate.login('operator', 'correct-password');
    final cameras = await frigate.fetchCameras(token: session.token);
    final storage = await frigate.fetchStorageStats(token: session.token);
    final recordings = await frigate.fetchRecordings(
      camera: 'entrada_principal',
      after: DateTime.fromMillisecondsSinceEpoch(1760126400000),
      before: DateTime.fromMillisecondsSinceEpoch(1760133600000),
      token: session.token,
    );

    expect(session.token, 'test-jwt');
    expect(session.user['name'], 'operator');
    expect(cameras.map((camera) => camera.name), [
      'entrada_principal',
      'fundos',
    ]);
    expect(storage.primaryVolume.path, '/media/frigate/recordings');
    expect(storage.primaryVolume.usedPercent, 25);
    expect(recordings, hasLength(1));
    expect(
      recordings.single.end.difference(recordings.single.start).inMinutes,
      1,
    );
  });

  test('accepts recording response variants from Frigate proxies', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/entrada/recordings');
      return http.Response(
        jsonEncode({
          'recordings': [
            {'start': '2026-10-10T20:00:00.000Z', 'end': 1791662460000},
          ],
        }),
        200,
      );
    });
    final frigate = FrigateClient(
      baseUrl: 'http://frigate.local:5001',
      client: client,
    );

    final recordings = await frigate.fetchRecordings(
      camera: 'entrada',
      after: DateTime(2026, 10, 10),
      before: DateTime(2026, 10, 11),
      token: 'token',
    );

    expect(recordings, hasLength(1));
    expect(recordings.single.end.isAfter(recordings.single.start), isTrue);
  });

  test('downloads a recording clip before local playback', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.path,
        '/api/entrada/start/1760130000.000/end/1760130060.000/clip.mp4',
      );
      expect(request.headers['authorization'], 'Bearer test-token');
      expect(request.headers['cookie'], 'frigate_token=test-token');
      return http.Response.bytes(const [1, 2, 3, 4], 200);
    });
    final frigate = FrigateClient(
      baseUrl: 'http://frigate.local:5001',
      client: client,
    );
    final directory = await Directory.systemTemp.createTemp('cami_recording_');
    addTearDown(() => directory.delete(recursive: true));
    final destination = File('${directory.path}/recording.mp4');

    await frigate.downloadRecordingClip(
      camera: 'entrada',
      start: DateTime.fromMillisecondsSinceEpoch(1760130000000),
      end: DateTime.fromMillisecondsSinceEpoch(1760130060000),
      token: 'test-token',
      destination: destination,
    );

    expect(await destination.readAsBytes(), <int>[1, 2, 3, 4]);
  });
}
