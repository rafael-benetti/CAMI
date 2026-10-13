import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Bounded cache for clips explicitly opened from the recording history.
/// Live streams are intentionally never persisted here.
class MediaCache {
  static const maximumBytes = 250 * 1024 * 1024;
  static const maximumAge = Duration(hours: 48);

  static Future<Directory> _directory() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}/recording_cache');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  static String recordingFileName({
    required String camera,
    required DateTime start,
    required DateTime end,
  }) {
    final identity =
        '$camera|${start.toUtc().millisecondsSinceEpoch}|'
        '${end.toUtc().millisecondsSinceEpoch}';
    return '${base64Url.encode(utf8.encode(identity)).replaceAll('=', '')}.mp4';
  }

  static Future<File> recordingFile({
    required String camera,
    required DateTime start,
    required DateTime end,
  }) async {
    final directory = await _directory();
    return File(
      '${directory.path}/${recordingFileName(camera: camera, start: start, end: end)}',
    );
  }

  static Future<bool> isUsable(File file, {DateTime? now}) async {
    try {
      if (!await file.exists() || await file.length() == 0) return false;
      final age = (now ?? DateTime.now()).difference(await file.lastModified());
      if (age > maximumAge) {
        await file.delete();
        return false;
      }
      await file.setLastModified(now ?? DateTime.now());
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> prune() async {
    try {
      final directory = await _directory();
      final now = DateTime.now();
      final files = <File>[];
      await for (final entity in directory.list()) {
        if (entity is! File || !entity.path.toLowerCase().endsWith('.mp4')) {
          continue;
        }
        if (now.difference(await entity.lastModified()) > maximumAge) {
          await entity.delete();
        } else {
          files.add(entity);
        }
      }
      files.sort(
        (first, second) =>
            first.lastModifiedSync().compareTo(second.lastModifiedSync()),
      );
      var total = 0;
      for (final file in files) {
        total += await file.length();
      }
      for (final file in files) {
        if (total <= maximumBytes) break;
        final length = await file.length();
        await file.delete();
        total -= length;
      }
    } catch (_) {
      // Cache maintenance must never break playback.
    }
  }
}
