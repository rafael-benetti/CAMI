import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../models/camera_group.dart';
import '../../../models/camera_item.dart';
import 'camera_tile.dart';

class HomeContent extends StatefulWidget {
  final Widget header;
  final List<CameraItem> cameras;
  final List<CameraGroup> cameraGroups;
  final String searchQuery;
  final void Function(CameraItem) onOpen;
  final Future<void> Function() onRefresh;
  final Set<int> thumbnailLoadingIds;
  const HomeContent({
    super.key,
    required this.header,
    required this.cameras,
    required this.cameraGroups,
    required this.searchQuery,
    required this.onOpen,
    required this.onRefresh,
    required this.thumbnailLoadingIds,
  });

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  String? selectedGroupName;

  @override
  void didUpdateWidget(covariant HomeContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (selectedGroupName != null &&
        !widget.cameraGroups.any((group) => group.name == selectedGroupName)) {
      selectedGroupName = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    CameraGroup? selectedGroup;
    for (final group in widget.cameraGroups) {
      if (group.name == selectedGroupName) {
        selectedGroup = group;
        break;
      }
    }
    final selectedCameraIds = selectedGroup?.cameraIds;
    final groupedCameras = selectedCameraIds == null
        ? widget.cameras
        : widget.cameras
              .where(
                (camera) =>
                    camera.id != null && selectedCameraIds.contains(camera.id),
              )
              .toList();
    final onlineCount = groupedCameras.where((camera) => camera.online).length;
    final offlineCount = groupedCameras.length - onlineCount;
    final normalizedQuery = widget.searchQuery.trim().toLowerCase();
    final visibleCameras =
        groupedCameras
            .where(
              (camera) => camera.name.toLowerCase().contains(normalizedQuery),
            )
            .toList()
          ..sort(
            (first, second) =>
                first.name.toLowerCase().compareTo(second.name.toLowerCase()),
          );
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
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
                  widget.header,
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
                  if (widget.cameraGroups.isNotEmpty) ...[
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: const Text('Todas'),
                              selected: selectedGroupName == null,
                              onSelected: (_) =>
                                  setState(() => selectedGroupName = null),
                            ),
                          ),
                          ...widget.cameraGroups.map(
                            (group) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(group.name),
                                selected: selectedGroupName == group.name,
                                onSelected: (_) => setState(
                                  () => selectedGroupName = group.name,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                  ],
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
                        '${groupedCameras.length} câmeras',
                        style: const TextStyle(color: muted, fontSize: 9),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          if (widget.cameras.isEmpty)
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
                        widget.thumbnailLoadingIds.contains(camera.id),
                    onTap: () => widget.onOpen(camera),
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
