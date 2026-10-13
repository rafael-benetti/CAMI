import 'package:cami/data/cache/media_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recording cache key is stable and varies by time range', () {
    final start = DateTime.utc(2026, 10, 11, 10);
    final end = start.add(const Duration(minutes: 10));
    final same = MediaCache.recordingFileName(
      camera: 'entrada',
      start: start,
      end: end,
    );
    final another = MediaCache.recordingFileName(
      camera: 'entrada',
      start: start,
      end: end.add(const Duration(minutes: 1)),
    );

    expect(same, endsWith('.mp4'));
    expect(
      same,
      MediaCache.recordingFileName(camera: 'entrada', start: start, end: end),
    );
    expect(another, isNot(same));
  });
}
