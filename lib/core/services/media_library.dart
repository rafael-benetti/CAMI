import 'dart:typed_data';

import 'package:flutter/services.dart';

class MediaLibrary {
  static const _channel = MethodChannel('br.gov.itapema.cami/media');

  static Future<String> saveSnapshot(Uint8List image) async {
    final destination = await _channel.invokeMethod<String>('saveSnapshot', {
      'bytes': image,
    });
    if (destination == null || destination.isEmpty) {
      throw StateError('O sistema não informou onde a imagem foi salva.');
    }
    return destination;
  }
}
