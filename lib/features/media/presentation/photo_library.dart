import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/media_share_service.dart';
import '../../../models/local_photo.dart';
import '../../dashboard/widgets/list_content.dart';

class PhotoLibrary extends StatelessWidget {
  final List<LocalPhoto> photos;
  final bool loading;
  final Future<void> Function() onRefresh;
  final ValueChanged<LocalPhoto> onOpen;

  const PhotoLibrary({
    super.key,
    required this.photos,
    required this.loading,
    required this.onRefresh,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 64),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (photos.isEmpty) {
      return Column(
        children: [
          const ListContent(
            title: 'Snapshots salvos neste aparelho',
            icon: Icons.photo_library_outlined,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => unawaited(onRefresh()),
            icon: const Icon(Icons.refresh),
            label: const Text('Atualizar'),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${photos.length} ${photos.length == 1 ? 'foto' : 'fotos'} neste aparelho',
              style: const TextStyle(color: muted, fontSize: 10),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Atualizar',
              onPressed: () => unawaited(onRefresh()),
              icon: const Icon(Icons.refresh, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: .9,
          ),
          itemCount: photos.length,
          itemBuilder: (context, index) {
            final photo = photos[index];
            return Material(
              color: panel,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onOpen(photo),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SizedBox(
                        width: double.infinity,
                        child: Image.file(
                          File(photo.path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            photo.cameraName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            localRecordingDate(photo.capturedAt),
                            style: const TextStyle(color: muted, fontSize: 8),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class LocalPhotoPage extends StatelessWidget {
  final LocalPhoto photo;

  const LocalPhotoPage({super.key, required this.photo});

  Future<void> _share(BuildContext context) async {
    try {
      await MediaShareService.shareFile(
        photo.path,
        title: 'Foto - ${photo.cameraName}',
        text: 'Snapshot da câmera ${photo.cameraName}',
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível compartilhar a foto.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(photo.cameraName)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: InteractiveViewer(
                  child: Image.file(
                    File(photo.path),
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      color: muted,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.photo_outlined, color: blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${photo.location}\n${localRecordingDate(photo.capturedAt)}',
                      style: const TextStyle(color: muted, fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _share(context),
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('Compartilhar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String localRecordingDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0
      ? '${hours.toString().padLeft(2, '0')}:$minutes:$seconds'
      : '$minutes:$seconds';
}

String localRecordingDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} às $hour:$minute';
}
