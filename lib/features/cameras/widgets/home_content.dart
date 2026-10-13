import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/camera_item.dart';
import 'camera_tile.dart';

class HomeContent extends StatelessWidget {
  final Widget header;
  final List<CameraItem> cameras;
  final String searchQuery;
  final void Function(CameraItem) onOpen;
  final Future<void> Function() onRefresh;
  final Set<int> thumbnailLoadingIds;
  const HomeContent({
    super.key,
    required this.header,
    required this.cameras,
    required this.searchQuery,
    required this.onOpen,
    required this.onRefresh,
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
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        key: const PageStorageKey<String>('camera-home-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  const SizedBox(height: 22),
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
                        const Icon(
                          Icons.circle,
                          size: 7,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '$offlineCount offline',
                          style: const TextStyle(color: muted, fontSize: 9),
                        ),
                        const Spacer(),
                        const Text(
                          'Atualizado agora',
                          style: TextStyle(
                            color: Color(0xff687993),
                            fontSize: 7,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 21),
                  Row(
                    children: [
                      const Text(
                        'Visualização ao vivo',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '${cameras.length} câmeras',
                        style: const TextStyle(color: muted, fontSize: 9),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          if (cameras.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverToBoxAdapter(
                child: _EmptyCameraState(
                  icon: Icons.videocam_off_outlined,
                  message: 'Cadastre a câmera no Frigate e atualize esta tela.',
                ),
              ),
            )
          else if (visibleCameras.isEmpty)
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverToBoxAdapter(
                child: _EmptyCameraState(icon: Icons.search_off, message: null),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: .88,
                ),
                itemCount: visibleCameras.length,
                itemBuilder: (context, index) {
                  final camera = visibleCameras[index];
                  return CameraTile(
                    key: ValueKey(camera.id ?? camera.rtspUrl),
                    name: camera.name,
                    place: camera.place,
                    online: camera.online,
                    thumbnail: camera.thumbnail,
                    thumbnailLoading:
                        camera.id != null &&
                        thumbnailLoadingIds.contains(camera.id),
                    onTap: () => onOpen(camera),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyCameraState extends StatelessWidget {
  final IconData icon;
  final String? message;

  const _EmptyCameraState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 24),
    decoration: BoxDecoration(
      color: panel,
      border: Border.all(color: panelBorder),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Column(
      children: [
        Icon(icon, color: muted, size: 32),
        const SizedBox(height: 12),
        const Text(
          'Nenhuma câmera encontrada',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        if (message != null) ...[
          const SizedBox(height: 5),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, fontSize: 10),
          ),
        ],
      ],
    ),
  );
}
