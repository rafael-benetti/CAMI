import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class CameraTile extends StatelessWidget {
  final String name;
  final String place;
  final bool online;
  final Uint8List? thumbnail;
  final bool thumbnailLoading;
  final VoidCallback? onTap;
  const CameraTile({
    super.key,
    required this.name,
    required this.place,
    required this.online,
    this.thumbnail,
    this.thumbnailLoading = false,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(13),
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: panel,
        border: Border.all(color: panelBorder),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (thumbnail != null)
                  Image.memory(
                    thumbnail!,
                    fit: BoxFit.cover,
                    // Cards never need the full source frame in the image
                    // cache; decoding a bounded preview keeps scrolling smooth.
                    cacheWidth: 480,
                  )
                else
                  Image.asset('assets/images.png', fit: BoxFit.cover),
                Container(color: Colors.black26),
                if (thumbnailLoading)
                  Container(
                    color: Colors.black38,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                Positioned(
                  left: 7,
                  top: 7,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      online ? 'AO VIVO' : 'SEM SINAL',
                      style: const TextStyle(
                        fontSize: 6,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (!online)
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off, color: muted, size: 19),
                        SizedBox(height: 4),
                        Text(
                          'Câmera offline',
                          style: TextStyle(color: muted, fontSize: 7),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.fade,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        place,
                        style: const TextStyle(color: muted, fontSize: 7),
                      ),
                    ],
                  ),
                ),
                Text(
                  online ? '● Online' : '● Offline',
                  style: TextStyle(
                    color: online ? statusGreen : Colors.redAccent,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
