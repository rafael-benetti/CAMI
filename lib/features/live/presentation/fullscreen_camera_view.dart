import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

class FullscreenCameraView extends StatefulWidget {
  final VideoController controller;
  final String cameraName;

  const FullscreenCameraView({
    super.key,
    required this.controller,
    required this.cameraName,
  });

  @override
  State<FullscreenCameraView> createState() => _FullscreenCameraViewState();
}

class _FullscreenCameraViewState extends State<FullscreenCameraView> {
  int quarterTurns = 0;

  void rotateVideo() {
    setState(() => quarterTurns = (quarterTurns + 1) % 4);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            RotatedBox(
              quarterTurns: quarterTurns,
              child: Video(
                controller: widget.controller,
                controls: NoVideoControls,
              ),
            ),
            Positioned(
              left: 16,
              top: 12,
              child: Text(
                widget.cameraName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 8,
              child: IconButton(
                tooltip: 'Sair da tela cheia',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0x99000000),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 12,
              child: IconButton(
                tooltip: 'Girar vídeo',
                onPressed: rotateVideo,
                icon: const Icon(Icons.rotate_right, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0x99000000),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
