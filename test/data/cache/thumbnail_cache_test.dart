import 'dart:typed_data';

import 'package:cami/data/cache/thumbnail_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('thumbnail freshness honors the configured age', () {
    final now = DateTime(2026, 10, 11, 12);
    final fresh = ThumbnailCacheEntry(
      bytes: Uint8List.fromList(<int>[1]),
      cachedAt: now.subtract(const Duration(minutes: 29)),
    );
    final stale = ThumbnailCacheEntry(
      bytes: Uint8List.fromList(<int>[1]),
      cachedAt: now.subtract(const Duration(minutes: 31)),
    );

    expect(fresh.isFresh(const Duration(minutes: 30), now), isTrue);
    expect(stale.isFresh(const Duration(minutes: 30), now), isFalse);
  });
}
