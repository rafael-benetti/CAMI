import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/local_date_formatters.dart';
import '../../../models/local_photo.dart';

class RecentSnapshotCards extends StatelessWidget {
  final List<LocalPhoto> snapshots;
  final ValueChanged<LocalPhoto> onOpen;
  final ValueChanged<LocalPhoto> onDismiss;
  final Future<void> Function(LocalPhoto) onShare;

  const RecentSnapshotCards({
    super.key,
    required this.snapshots,
    required this.onOpen,
    required this.onDismiss,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    if (snapshots.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ÚLTIMOS SNAPSHOTS',
          style: TextStyle(
            color: muted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ...snapshots.map(
          (snapshot) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Dismissible(
              key: ValueKey(snapshot.path),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => onDismiss(snapshot),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 18),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: .85),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.visibility_off_outlined),
              ),
              child: Material(
                color: panel,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onOpen(snapshot),
                  child: SizedBox(
                    height: 68,
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(10),
                          ),
                          child: SizedBox(
                            width: 92,
                            height: double.infinity,
                            child: Image.file(
                              File(snapshot.path),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                snapshot.cameraName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${snapshot.location} • ${localRecordingDate(snapshot.capturedAt)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Compartilhar snapshot',
                          onPressed: () => onShare(snapshot),
                          icon: const Icon(Icons.share_outlined, size: 19),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
