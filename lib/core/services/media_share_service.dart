import 'dart:io';

import 'package:share_plus/share_plus.dart';

class MediaShareService {
  static Future<void> shareFile(
    String path, {
    required String title,
    required String text,
  }) async {
    final file = File(path);
    if (!await file.exists() || await file.length() == 0) {
      throw StateError('O arquivo não está mais disponível neste aparelho.');
    }
    final result = await SharePlus.instance.share(
      ShareParams(
        title: title,
        text: text,
        files: [XFile(path, mimeType: _mimeTypeFor(path))],
      ),
    );
    if (result.status == ShareResultStatus.unavailable) {
      throw StateError(
        'O compartilhamento não está disponível neste aparelho.',
      );
    }
  }

  static String _mimeTypeFor(String path) {
    final extension = path.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'ts' => 'video/mp2t',
      'mkv' => 'video/x-matroska',
      'mp4' => 'video/mp4',
      _ => 'application/octet-stream',
    };
  }
}
