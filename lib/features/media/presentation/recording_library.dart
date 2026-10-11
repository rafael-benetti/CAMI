import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/media_share_service.dart';
import '../../../core/utils/local_date_formatters.dart';
import '../../../models/local_recording.dart';
import '../../dashboard/widgets/list_content.dart';

class RecordingLibrary extends StatelessWidget {
  final List<LocalRecording> recordings;
  final bool loading;
  final Future<void> Function() onRefresh;
  final ValueChanged<LocalRecording> onOpen;

  const RecordingLibrary({
    super.key,
    required this.recordings,
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
    if (recordings.isEmpty) {
      return Column(
        children: [
          const ListContent(
            title: 'Gravações locais',
            icon: Icons.video_library_outlined,
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
              '${recordings.length} ${recordings.length == 1 ? 'gravação' : 'gravações'} neste aparelho',
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
        ...recordings.map(
          (recording) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: panel,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onOpen(recording),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xff172235),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.play_circle_outline,
                          color: blue,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recording.cameraName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${localRecordingDate(recording.startedAt)}  •  ${localRecordingDuration(recording.duration)}',
                              style: const TextStyle(color: muted, fontSize: 9),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              recording.location,
                              style: const TextStyle(color: muted, fontSize: 8),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: muted),
                    ],
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

class LocalRecordingPage extends StatefulWidget {
  final LocalRecording recording;

  const LocalRecordingPage({super.key, required this.recording});

  @override
  State<LocalRecordingPage> createState() => _LocalRecordingPageState();
}

class _LocalRecordingPageState extends State<LocalRecordingPage> {
  late final Player player;
  late final VideoController controller;
  bool sharing = false;

  @override
  void initState() {
    super.initState();
    player = Player();
    controller = VideoController(player);
    unawaited(player.open(Media(File(widget.recording.path).uri.toString())));
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  Future<void> shareRecording() async {
    if (sharing) return;
    setState(() => sharing = true);
    try {
      await MediaShareService.shareFile(
        widget.recording.path,
        title: 'Gravação - ${widget.recording.cameraName}',
        text: 'Gravação da câmera ${widget.recording.cameraName}',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível compartilhar o vídeo.')),
      );
    } finally {
      if (mounted) setState(() => sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.recording.cameraName)),
      body: SafeArea(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1.42,
              child: Video(controller: controller),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined, color: blue),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Salvo localmente\n${localRecordingDate(widget.recording.startedAt)} • ${localRecordingDuration(widget.recording.duration)}',
                      style: const TextStyle(color: muted, fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: sharing ? null : shareRecording,
                    icon: sharing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.share_outlined, size: 18),
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
