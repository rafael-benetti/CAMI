import 'dart:typed_data';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

Future<Uint8List?> captureVideoThumbnail(String streamUrl) async {
  final thumbnailPlayer = Player(
    configuration: const PlayerConfiguration(
      protocolWhitelist: [
        'rtsp',
        'udp',
        'rtp',
        'tcp',
        'tls',
        'data',
        'file',
        'http',
        'https',
        'crypto',
      ],
    ),
  );
  // A tela ao vivo usa um VideoController para inicializar o output de vídeo.
  // A captura automática precisa fazer o mesmo para que screenshot() tenha
  // um frame real disponível.
  VideoController(thumbnailPlayer);
  try {
    final videoReady = thumbnailPlayer.stream.videoParams
        .firstWhere((params) => (params.w ?? 0) > 0 && (params.h ?? 0) > 0)
        .timeout(const Duration(seconds: 20));
    await thumbnailPlayer.open(Media(streamUrl));
    await videoReady;
    await Future<void>.delayed(const Duration(seconds: 1));
    return await thumbnailPlayer.screenshot(format: 'image/jpeg');
  } catch (_) {
    return null;
  } finally {
    await thumbnailPlayer.dispose();
  }
}
