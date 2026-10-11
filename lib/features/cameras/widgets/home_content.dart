import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/camera_item.dart';
import 'camera_tile.dart';

class HomeContent extends StatelessWidget {
  final List<CameraItem> cameras;
  final String searchQuery;
  final void Function(CameraItem) onOpen;
  final Set<int> thumbnailLoadingIds;
  const HomeContent({
    super.key,
    required this.cameras,
    required this.searchQuery,
    required this.onOpen,
    required this.thumbnailLoadingIds,
  });
  @override
  Widget build(BuildContext context) {
    final onlineCount = cameras.where((camera) => camera.online).length;
    final offlineCount = cameras.length - onlineCount;
    final normalizedQuery = searchQuery.trim().toLowerCase();
    final visibleCameras =
        cameras
            .where(
              (camera) => camera.name.toLowerCase().contains(normalizedQuery),
            )
            .toList()
          ..sort(
            (first, second) =>
                first.name.toLowerCase().compareTo(second.name.toLowerCase()),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xff172235),
            border: Border.all(color: panelBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.circle, size: 7, color: statusGreen),
              const SizedBox(width: 5),
              Text(
                '$onlineCount online',
                style: const TextStyle(color: muted, fontSize: 9),
              ),
              const SizedBox(width: 13),
              const Icon(Icons.circle, size: 7, color: Colors.redAccent),
              const SizedBox(width: 5),
              Text(
                '$offlineCount offline',
                style: const TextStyle(color: muted, fontSize: 9),
              ),
              const Spacer(),
              const Text(
                'Atualizado agora',
                style: TextStyle(color: Color(0xff687993), fontSize: 7),
              ),
            ],
          ),
        ),
        const SizedBox(height: 21),
        Row(
          children: [
            const Text(
              'Visualização ao vivo',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 7),
            Text(
              '${cameras.length} câmeras',
              style: const TextStyle(color: muted, fontSize: 9),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (cameras.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 24),
            decoration: BoxDecoration(
              color: panel,
              border: Border.all(color: panelBorder),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Column(
              children: [
                Icon(Icons.videocam_off_outlined, color: muted, size: 32),
                SizedBox(height: 12),
                Text(
                  'Nenhuma câmera encontrada',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 5),
                Text(
                  'Cadastre a câmera no Frigate e atualize esta tela.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, fontSize: 10),
                ),
              ],
            ),
          )
        else if (visibleCameras.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 24),
            decoration: BoxDecoration(
              color: panel,
              border: Border.all(color: panelBorder),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Column(
              children: [
                Icon(Icons.search_off, color: muted, size: 32),
                SizedBox(height: 12),
                Text(
                  'Nenhuma câmera encontrada',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          )
        else
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: .88,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: visibleCameras
                .map(
                  (camera) => CameraTile(
                    name: camera.name,
                    place: camera.place,
                    online: camera.online,
                    thumbnail: camera.thumbnail,
                    thumbnailLoading:
                        camera.id != null &&
                        thumbnailLoadingIds.contains(camera.id),
                    onTap: () => onOpen(camera),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}
