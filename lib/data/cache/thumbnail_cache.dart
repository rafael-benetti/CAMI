import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class ThumbnailCacheEntry {
  final Uint8List bytes;
  final DateTime cachedAt;

  const ThumbnailCacheEntry({required this.bytes, required this.cachedAt});

  bool isFresh(Duration maxAge, DateTime now) =>
      now.difference(cachedAt) <= maxAge;
}

class ThumbnailCache {
  static const _maximumFiles = 500;
  static const _maximumBytes = 100 * 1024 * 1024;

  static Future<Directory> _directory() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}/camera_thumbnails');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  static Future<ThumbnailCacheEntry?> readEntry(int cameraId) async {
    try {
      final directory = await _directory();
      final file = File('${directory.path}/$cameraId.jpg');
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      return ThumbnailCacheEntry(
        bytes: bytes,
        cachedAt: await file.lastModified(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> read(int cameraId) async =>
      (await readEntry(cameraId))?.bytes;

  static Future<void> write(int cameraId, Uint8List image) async {
    try {
      final directory = await _directory();
      await File('${directory.path}/$cameraId.jpg').writeAsBytes(image);
      await _prune(directory);
    } catch (_) {
      // A falha no cache não deve impedir a câmera de funcionar.
    }
  }

  static Future<void> _prune(Directory directory) async {
    final files = <File>[];
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.jpg')) {
        files.add(entity);
      }
    }

    var total = 0;
    for (final file in files) {
      total += await file.length();
    }
    if (files.length <= _maximumFiles && total <= _maximumBytes) return;

    files.sort(
      (first, second) =>
          first.lastModifiedSync().compareTo(second.lastModifiedSync()),
    );
    var remaining = files.length;
    for (final file in files) {
      if (remaining <= _maximumFiles && total <= _maximumBytes) break;
      final length = await file.length();
      await file.delete();
      total -= length;
      remaining--;
    }
  }
}
