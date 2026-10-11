import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class ThumbnailCache {
  static Future<Directory> _directory() async {
    final root = await getApplicationSupportDirectory();
    final directory = Directory('${root.path}/camera_thumbnails');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  static Future<Uint8List?> read(int cameraId) async {
    try {
      final directory = await _directory();
      final file = File('${directory.path}/$cameraId.jpg');
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(int cameraId, Uint8List image) async {
    try {
      final directory = await _directory();
      await File('${directory.path}/$cameraId.jpg').writeAsBytes(image);
    } catch (_) {
      // A falha no cache não deve impedir a câmera de funcionar.
    }
  }
}
