import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/local_photo.dart';

class LocalPhotoStore {
  static const _key = 'cami.local_photos';

  static Future<Directory> _directory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/photos');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  static Future<List<LocalPhoto>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    List<LocalPhoto> values = const [];
    if (raw != null) {
      try {
        values = (jsonDecode(raw) as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .map(LocalPhoto.fromJson)
            .toList();
      } catch (_) {
        values = const [];
      }
    }
    final available = <LocalPhoto>[];
    for (final photo in values) {
      if (await File(photo.path).exists()) available.add(photo);
    }
    final directory = await _directory();
    await for (final entry in directory.list()) {
      if (entry is! File || !entry.path.toLowerCase().endsWith('.jpg')) {
        continue;
      }
      if (available.any((photo) => photo.path == entry.path)) continue;
      available.add(
        LocalPhoto(
          path: entry.path,
          cameraName: 'Snapshot',
          location: 'Arquivo recuperado',
          capturedAt: await entry.lastModified(),
        ),
      );
    }
    available.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    if (available.length != values.length ||
        available.any(
          (photo) => !values.any((item) => item.path == photo.path),
        )) {
      await _write(available);
    }
    return available;
  }

  static Future<LocalPhoto> add(
    Uint8List image, {
    required String cameraName,
    required String location,
  }) async {
    final current = await load();
    final directory = await _directory();
    final capturedAt = DateTime.now();
    final file = File(
      '${directory.path}/snapshot_${capturedAt.toUtc().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(image, flush: true);
    final photo = LocalPhoto(
      path: file.path,
      cameraName: cameraName,
      location: location,
      capturedAt: capturedAt,
    );
    await _write([photo, ...current]);
    return photo;
  }

  /// Removes both the local image file and its library entry.
  static Future<void> delete(LocalPhoto photo) async {
    final current = await load();
    final file = File(photo.path);
    if (await file.exists()) await file.delete();
    await _write(current.where((item) => item.path != photo.path).toList());
  }

  static Future<void> _write(List<LocalPhoto> photos) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode(photos.map((photo) => photo.toJson()).toList()),
    );
  }
}
