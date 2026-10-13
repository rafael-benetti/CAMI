import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/frigate_client.dart';
import '../../../core/services/media_library.dart';
import '../../../core/services/media_share_service.dart';
import '../../../data/cache/media_cache.dart';
import '../../../data/local/local_photo_store.dart';
import '../../../models/camera_item.dart';
import '../../../models/local_photo.dart';
import '../../media/presentation/photo_library.dart';
import '../widgets/live_control.dart';
import '../widgets/recent_snapshot_cards.dart';
import 'fullscreen_camera_view.dart';

class LiveCameraPage extends StatefulWidget {
  final CameraItem camera;
  final FrigateClient frigateClient;
  final String? streamAccessToken;
  final VoidCallback onBack;
  final ValueChanged<Uint8List> onThumbnailCaptured;
  const LiveCameraPage({
    super.key,
    required this.camera,
    required this.frigateClient,
    this.streamAccessToken,
    required this.onBack,
    required this.onThumbnailCaptured,
  });
  @override
  State<LiveCameraPage> createState() => _LiveCameraPageState();
}

enum _LiveConnectionState { connecting, live, reconnecting, paused, offline }

class _LiveCameraPageState extends State<LiveCameraPage>
    with WidgetsBindingObserver {
  bool takingSnapshot = false;
  late final Player player;
  late final VideoController videoController;
  bool thumbnailCaptured = false;
  final List<LocalPhoto> recentSnapshots = <LocalPhoto>[];
  late DateTime selectedRecordingDay;
  late DateTime timelineCursor;
  List<FrigateRecording> recordings = const <FrigateRecording>[];
  FrigateRecording? selectedRecording;
  bool recordingsLoading = false;
  String? recordingsError;
  String? timelineMessage;
  bool historyOpen = false;
  bool playingRecording = false;
  bool recordingPlaybackLoading = false;
  _LiveConnectionState connectionState = _LiveConnectionState.connecting;
  String? videoQuality;
  bool suspended = false;

  String get cameraAddress =>
      Uri.tryParse(widget.camera.rtspUrl)?.host ?? widget.camera.rtspUrl;

  String? get frigateCameraName =>
      Uri.tryParse(widget.camera.rtspUrl)?.queryParameters['src'];

  Map<String, String> get streamHeaders {
    final token = widget.streamAccessToken;
    if (token == null || token.isEmpty) return const <String, String>{};
    // O manifest HLS e seus segmentos usam a sessão frigate_token; manter o
    // bearer junto preserva a compatibilidade com instalações antigas.
    return {'Authorization': 'Bearer $token', 'Cookie': 'frigate_token=$token'};
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final now = DateTime.now();
    selectedRecordingDay = DateTime(now.year, now.month, now.day);
    timelineCursor = now;
    player = Player(
      configuration: const PlayerConfiguration(
        muted: true,
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
    videoController = VideoController(player);
    unawaited(_openLive());
  }

  Future<void> _openLive({bool reconnecting = false}) async {
    if (!mounted || suspended) return;
    setState(
      () => connectionState = reconnecting
          ? _LiveConnectionState.reconnecting
          : _LiveConnectionState.connecting,
    );
    try {
      await player.open(
        Media(widget.camera.rtspUrl, httpHeaders: streamHeaders),
        play: true,
      );
      unawaited(_markFirstFrameRendered());
    } catch (_) {
      if (!mounted || suspended) return;
      setState(() => connectionState = _LiveConnectionState.offline);
    }
  }

  Future<void> _markFirstFrameRendered() async {
    try {
      // Do not put a short timeout here. HLS over a mobile network can take more
      // than fifteen seconds to produce the first frame; restarting the Player
      // in that window prevents the stream from ever finishing its handshake.
      await videoController.waitUntilFirstFrameRendered;
      if (!mounted || suspended) return;
      final params = player.state.videoParams;
      setState(() {
        connectionState = _LiveConnectionState.live;
        if ((params.w ?? 0) > 0 && (params.h ?? 0) > 0) {
          videoQuality = '${params.w}×${params.h}';
        }
      });
      unawaited(_captureThumbnailWhenReady());
    } catch (_) {
      // Keep the native player opening. It already performs the HLS network
      // work and must not be interrupted merely because status UI failed.
    }
  }

  Future<void> _captureThumbnailWhenReady() async {
    try {
      // Este evento só é concluído quando o Video já renderizou um frame real
      // na tela. Assim, streams que demoram a negociar RTSP atualizam o card
      // automaticamente assim que o usuário os abre.
      await videoController.waitUntilFirstFrameRendered;
      if (thumbnailCaptured || !mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 300));
      for (var attempt = 0; attempt < 3; attempt++) {
        if (!mounted || thumbnailCaptured) return;
        final image = await player.screenshot(format: 'image/jpeg');
        if (image != null && image.isNotEmpty) {
          thumbnailCaptured = true;
          widget.onThumbnailCaptured(image);
          return;
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    } catch (_) {
      // A câmera pode demorar, estar offline ou não suportar snapshots.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    player.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      suspended = true;
      unawaited(player.pause());
      if (mounted && !playingRecording) {
        setState(() => connectionState = _LiveConnectionState.paused);
      }
      return;
    }
    if (state == AppLifecycleState.resumed && suspended) {
      suspended = false;
      if (playingRecording) {
        unawaited(player.play());
      } else {
        unawaited(_openLive(reconnecting: true));
      }
    }
  }

  Future<void> takeSnapshot() async {
    if (takingSnapshot) return;
    setState(() => takingSnapshot = true);
    try {
      final image = await player.screenshot(format: 'image/jpeg');
      if (image == null || image.isEmpty) {
        throw StateError('Nenhum frame disponível.');
      }
      final snapshot = await LocalPhotoStore.add(
        image,
        cameraName: widget.camera.name,
        location: widget.camera.place,
      );
      try {
        await MediaLibrary.saveSnapshot(image);
      } catch (_) {
        // A cópia do CAMI continua disponível em Fotos mesmo se a Galeria do
        // aparelho não tiver permissão ou estiver indisponível.
      }
      thumbnailCaptured = true;
      widget.onThumbnailCaptured(image);
      if (!mounted) return;
      setState(() {
        recentSnapshots.removeWhere((item) => item.path == snapshot.path);
        recentSnapshots.insert(0, snapshot);
        if (recentSnapshots.length > 3) {
          recentSnapshots.removeRange(3, recentSnapshots.length);
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível capturar um frame agora.'),
        ),
      );
    } finally {
      if (mounted) setState(() => takingSnapshot = false);
    }
  }

  Future<void> openSnapshot(LocalPhoto snapshot) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => LocalPhotoPage(photo: snapshot)),
    );
  }

  Future<void> shareSnapshot(LocalPhoto snapshot) async {
    try {
      await MediaShareService.shareFile(
        snapshot.path,
        title: 'Foto - ${snapshot.cameraName}',
        text: 'Snapshot da câmera ${snapshot.cameraName}',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível compartilhar o snapshot.'),
        ),
      );
    }
  }

  void hideSnapshot(LocalPhoto snapshot) {
    setState(
      () => recentSnapshots.removeWhere((item) => item.path == snapshot.path),
    );
  }

  Future<void> openFullscreen() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => FullscreenCameraView(
          controller: videoController,
          cameraName: widget.camera.name,
        ),
      ),
    );
  }

  Future<void> openHistory() async {
    if (!historyOpen) setState(() => historyOpen = true);
    await loadRecordings();
  }

  Future<void> loadRecordings() async {
    final token = widget.streamAccessToken;
    final camera = frigateCameraName;
    if (token == null || camera == null) {
      setState(
        () => recordingsError = 'Histórico indisponível para esta câmera.',
      );
      return;
    }
    setState(() {
      recordingsLoading = true;
      recordingsError = null;
      timelineMessage = null;
      selectedRecording = null;
    });
    try {
      final end = selectedRecordingDay.add(const Duration(days: 1));
      final loaded = await widget.frigateClient.fetchRecordings(
        camera: camera,
        after: selectedRecordingDay,
        before: end,
        token: token,
      );
      if (mounted) {
        setState(() {
          recordings = loaded;
          if (_recordingAt(timelineCursor, loaded) == null &&
              loaded.isNotEmpty) {
            timelineCursor = loaded.last.start;
          }
        });
      }
    } on FrigateException catch (error) {
      if (mounted) setState(() => recordingsError = error.message);
    } finally {
      if (mounted) setState(() => recordingsLoading = false);
    }
  }

  Future<void> selectDay(DateTime day) async {
    if (_sameDay(day, selectedRecordingDay)) return;
    setState(() {
      selectedRecordingDay = day;
      timelineCursor = day.add(const Duration(hours: 12));
      timelineMessage = null;
    });
    await loadRecordings();
  }

  FrigateRecording? _recordingAt(
    DateTime instant, [
    List<FrigateRecording>? available,
  ]) {
    for (final recording in available ?? recordings) {
      if (!instant.isBefore(recording.start) &&
          instant.isBefore(recording.end)) {
        return recording;
      }
    }
    return null;
  }

  Future<void> selectTimelineTime(DateTime instant) async {
    final recording = _recordingAt(instant);
    setState(() {
      timelineCursor = instant;
      timelineMessage = recording == null
          ? 'Não há gravação neste horário. Arraste até uma faixa azul.'
          : null;
    });
    if (recording != null) {
      await playRecording(recording, startAt: instant);
    }
  }

  Future<void> playRecording(
    FrigateRecording recording, {
    DateTime? startAt,
  }) async {
    if (recordingPlaybackLoading) return;
    final camera = frigateCameraName;
    final token = widget.streamAccessToken;
    if (camera == null || token == null || token.isEmpty) return;
    final start = startAt ?? recording.start;
    final dayEnd = selectedRecordingDay.add(const Duration(days: 1));
    final now = DateTime.now();
    final maximumEnd = now.isBefore(dayEnd) ? now : dayEnd;
    final desiredEnd = start.add(const Duration(minutes: 10));
    final end = desiredEnd.isBefore(maximumEnd) ? desiredEnd : maximumEnd;
    if (!end.isAfter(start)) return;
    setState(() => recordingPlaybackLoading = true);
    try {
      final file = await MediaCache.recordingFile(
        camera: camera,
        start: start,
        end: end,
      );
      if (!await MediaCache.isUsable(file)) {
        if (await file.exists()) await file.delete();
        await widget.frigateClient.downloadRecordingClip(
          camera: camera,
          start: start,
          end: end,
          token: token,
          destination: file,
        );
        await MediaCache.prune();
      }
      await player.open(Media(file.uri.toString()), play: true);
      if (mounted) {
        setState(() {
          selectedRecording = recording;
          timelineCursor = start;
          timelineMessage = null;
          playingRecording = true;
        });
      }
    } on FrigateException catch (error) {
      if (mounted) {
        setState(() => timelineMessage = error.message);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => recordingPlaybackLoading = false);
    }
  }

  Future<void> returnToLive() async {
    if (mounted) {
      setState(() {
        playingRecording = false;
        selectedRecording = null;
      });
    }
    await _openLive(reconnecting: true);
  }

  String get connectionLabel => switch (connectionState) {
    _LiveConnectionState.connecting => 'CONECTANDO',
    _LiveConnectionState.live => 'AO VIVO',
    _LiveConnectionState.reconnecting => 'RECONECTANDO',
    _LiveConnectionState.paused => 'PAUSADO',
    _LiveConnectionState.offline => 'SEM SINAL',
  };

  Color get connectionColor => switch (connectionState) {
    _LiveConnectionState.live => statusGreen,
    _LiveConnectionState.offline => Colors.redAccent,
    _LiveConnectionState.paused => muted,
    _ => Colors.amberAccent,
  };

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack();
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Column(
                        children: [
                          Text(
                            widget.camera.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '● $connectionLabel',
                            style: TextStyle(
                              color: connectionColor,
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                AspectRatio(
                  aspectRatio: 1.42,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Video(
                        controller: videoController,
                        controls: NoVideoControls,
                      ),
                      Container(color: Colors.black26),
                      if (connectionState == _LiveConnectionState.offline &&
                          !playingRecording)
                        Center(
                          child: FilledButton.icon(
                            onPressed: () => unawaited(_openLive()),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Tentar novamente'),
                          ),
                        ),
                      if (recordingPlaybackLoading)
                        const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 10),
                              Text('Preparando gravação...'),
                            ],
                          ),
                        ),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Text(
                          playingRecording
                              ? '● GRAVAÇÃO'
                              : '● $connectionLabel',
                          style: TextStyle(
                            color: playingRecording
                                ? Colors.amberAccent
                                : connectionColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Text(
                          playingRecording && selectedRecording != null
                              ? _formatTime(timelineCursor)
                              : _formatTime(DateTime.now()),
                          style: const TextStyle(fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            '●  $connectionLabel',
                            style: const TextStyle(color: muted, fontSize: 8),
                          ),
                          const Spacer(),
                          Text(
                            videoQuality ?? 'Preparando vídeo',
                            style: const TextStyle(color: muted, fontSize: 8),
                          ),
                        ],
                      ),
                      const SizedBox(height: 21),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          LiveControl(
                            icon: Icons.fullscreen,
                            label: 'Tela cheia',
                            onTap: () => unawaited(openFullscreen()),
                          ),
                          LiveControl(
                            icon: Icons.image_outlined,
                            label: takingSnapshot ? 'Salvando...' : 'Snapshot',
                            onTap: takingSnapshot
                                ? null
                                : () => unawaited(takeSnapshot()),
                          ),
                          LiveControl(
                            icon: playingRecording
                                ? Icons.videocam_outlined
                                : Icons.history_outlined,
                            label: playingRecording ? 'Ao vivo' : 'Histórico',
                            active: historyOpen,
                            onTap: () => unawaited(
                              playingRecording ? returnToLive() : openHistory(),
                            ),
                          ),
                        ],
                      ),
                      if (historyOpen) ...[
                        const Divider(height: 35, color: panelBorder),
                        _RecordingHistory(
                          selectedDay: selectedRecordingDay,
                          recordings: recordings,
                          loading: recordingsLoading,
                          playbackLoading: recordingPlaybackLoading,
                          error: recordingsError,
                          cursor: timelineCursor,
                          message: timelineMessage,
                          selectedRecording: selectedRecording,
                          onDaySelected: (day) => unawaited(selectDay(day)),
                          onCursorChanged: (time) =>
                              setState(() => timelineCursor = time),
                          onCursorReleased: (time) =>
                              unawaited(selectTimelineTime(time)),
                        ),
                      ],
                      const Divider(height: 35, color: panelBorder),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'LOCALIZAÇÃO\n${widget.camera.place}',
                              style: TextStyle(
                                color: muted,
                                fontSize: 8,
                                height: 2,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'ENDEREÇO\n$cameraAddress',
                              style: TextStyle(
                                color: muted,
                                fontSize: 8,
                                height: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (recentSnapshots.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        RecentSnapshotCards(
                          snapshots: recentSnapshots,
                          onOpen: (snapshot) =>
                              unawaited(openSnapshot(snapshot)),
                          onShare: shareSnapshot,
                          onDismiss: hideSnapshot,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordingHistory extends StatelessWidget {
  final DateTime selectedDay;
  final List<FrigateRecording> recordings;
  final bool loading;
  final bool playbackLoading;
  final String? error;
  final DateTime cursor;
  final String? message;
  final FrigateRecording? selectedRecording;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onCursorChanged;
  final ValueChanged<DateTime> onCursorReleased;

  const _RecordingHistory({
    required this.selectedDay,
    required this.recordings,
    required this.loading,
    required this.playbackLoading,
    required this.error,
    required this.cursor,
    required this.message,
    required this.selectedRecording,
    required this.onDaySelected,
    required this.onCursorChanged,
    required this.onCursorReleased,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List<DateTime>.generate(
      7,
      (index) => DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 6 - index)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('HISTÓRICO', style: TextStyle(color: muted, fontSize: 9)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: days
                .map(
                  (day) => Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      label: Text(
                        '${_weekday(day)} ${day.day.toString().padLeft(2, '0')}',
                      ),
                      selected: _sameDay(day, selectedDay),
                      onSelected: (_) => onDaySelected(day),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text(
                'LINHA DO TEMPO',
                style: TextStyle(color: muted, fontSize: 9),
              ),
            ),
            if (loading || playbackLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          'Arraste o marcador para escolher o horário • ${_formatTime(cursor)}',
          style: const TextStyle(color: muted, fontSize: 10),
        ),
        const SizedBox(height: 8),
        _RecordingTimeline(
          day: selectedDay,
          recordings: recordings,
          cursor: cursor,
          selected: selectedRecording,
          onCursorChanged: onCursorChanged,
          onCursorReleased: onCursorReleased,
        ),
        const SizedBox(height: 7),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('00h', style: TextStyle(color: muted, fontSize: 8)),
            Text('06h', style: TextStyle(color: muted, fontSize: 8)),
            Text('12h', style: TextStyle(color: muted, fontSize: 8)),
            Text('18h', style: TextStyle(color: muted, fontSize: 8)),
            Text('24h', style: TextStyle(color: muted, fontSize: 8)),
          ],
        ),
        const SizedBox(height: 12),
        if (error != null)
          Text(
            error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 10),
          )
        else if (!loading && recordings.isEmpty)
          const Text(
            'Não há gravações neste dia.',
            style: TextStyle(color: muted, fontSize: 10),
          )
        else if (message != null)
          Text(
            message!,
            style: const TextStyle(color: Colors.amberAccent, fontSize: 10),
          )
        else if (selectedRecording == null)
          const Text(
            'Arraste o marcador até uma faixa azul para reproduzir.',
            style: TextStyle(color: muted, fontSize: 10),
          )
        else
          Text(
            'Reproduzindo a partir de ${_formatTime(cursor)}',
            style: const TextStyle(color: statusGreen, fontSize: 10),
          ),
      ],
    );
  }
}

class _RecordingTimeline extends StatefulWidget {
  final DateTime day;
  final List<FrigateRecording> recordings;
  final DateTime cursor;
  final FrigateRecording? selected;
  final ValueChanged<DateTime> onCursorChanged;
  final ValueChanged<DateTime> onCursorReleased;

  const _RecordingTimeline({
    required this.day,
    required this.recordings,
    required this.cursor,
    required this.selected,
    required this.onCursorChanged,
    required this.onCursorReleased,
  });

  @override
  State<_RecordingTimeline> createState() => _RecordingTimelineState();
}

class _RecordingTimelineState extends State<_RecordingTimeline> {
  DateTime? draggedAt;

  DateTime _timeAt(double dx, double width) {
    final fraction = (dx / width).clamp(0.0, 1.0);
    return widget.day.add(
      Duration(
        milliseconds: (fraction * const Duration(days: 1).inMilliseconds)
            .round(),
      ),
    );
  }

  void _update(Offset position, double width) {
    draggedAt = _timeAt(position.dx, width);
    widget.onCursorChanged(draggedAt!);
  }

  void _release() {
    final time = draggedAt;
    if (time != null) widget.onCursorReleased(time);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) =>
          _update(details.localPosition, constraints.maxWidth),
      onTapUp: (_) => _release(),
      onPanDown: (details) =>
          _update(details.localPosition, constraints.maxWidth),
      onPanUpdate: (details) =>
          _update(details.localPosition, constraints.maxWidth),
      onPanEnd: (_) => _release(),
      child: CustomPaint(
        size: Size(constraints.maxWidth, 64),
        painter: _RecordingTimelinePainter(
          widget.day,
          widget.recordings,
          widget.cursor,
          widget.selected,
        ),
      ),
    ),
  );
}

class _RecordingTimelinePainter extends CustomPainter {
  final DateTime day;
  final List<FrigateRecording> recordings;
  final DateTime cursor;
  final FrigateRecording? selected;

  const _RecordingTimelinePainter(
    this.day,
    this.recordings,
    this.cursor,
    this.selected,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final background = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(9),
    );
    canvas.drawRRect(background, Paint()..color = panelBorder);
    final dayEnd = day.add(const Duration(days: 1));
    final gridPaint = Paint()
      ..color = muted.withValues(alpha: 0.22)
      ..strokeWidth = 1;
    for (var hour = 6; hour < 24; hour += 6) {
      final x = size.width * hour / 24;
      canvas.drawLine(Offset(x, 7), Offset(x, size.height - 7), gridPaint);
    }
    for (final span in _mergedRecordingSpans(recordings, day, dayEnd)) {
      final start = span.start;
      final finish = span.end;
      final left =
          start.difference(day).inMilliseconds /
          const Duration(days: 1).inMilliseconds *
          size.width;
      final right =
          finish.difference(day).inMilliseconds /
          const Duration(days: 1).inMilliseconds *
          size.width;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, 18, (right - left).clamp(3.0, size.width), 28),
          const Radius.circular(6),
        ),
        Paint()..color = blue,
      );
    }
    final cursorX =
        (cursor.difference(day).inMilliseconds /
                const Duration(days: 1).inMilliseconds *
                size.width)
            .clamp(0.0, size.width);
    final cursorPaint = Paint()
      ..color = Colors.amberAccent
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(cursorX, 3),
      Offset(cursorX, size.height - 3),
      cursorPaint,
    );
    canvas.drawCircle(
      Offset(cursorX, 10),
      6,
      Paint()..color = Colors.amberAccent,
    );
    if (selected != null &&
        !cursor.isBefore(selected!.start) &&
        cursor.isBefore(selected!.end)) {
      canvas.drawCircle(Offset(cursorX, 10), 2, Paint()..color = navy);
    }
  }

  @override
  bool shouldRepaint(covariant _RecordingTimelinePainter oldDelegate) =>
      oldDelegate.day != day ||
      oldDelegate.recordings != recordings ||
      oldDelegate.cursor != cursor ||
      oldDelegate.selected != selected;
}

class _RecordingSpan {
  final DateTime start;
  final DateTime end;

  const _RecordingSpan(this.start, this.end);
}

List<_RecordingSpan> _mergedRecordingSpans(
  List<FrigateRecording> recordings,
  DateTime day,
  DateTime dayEnd,
) {
  final sorted =
      recordings.where((recording) => recording.overlaps(day, dayEnd)).toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  final spans = <_RecordingSpan>[];
  for (final recording in sorted) {
    final start = recording.start.isBefore(day) ? day : recording.start;
    final end = recording.end.isAfter(dayEnd) ? dayEnd : recording.end;
    if (spans.isEmpty || start.difference(spans.last.end).inSeconds > 15) {
      spans.add(_RecordingSpan(start, end));
    } else if (end.isAfter(spans.last.end)) {
      spans[spans.length - 1] = _RecordingSpan(spans.last.start, end);
    }
  }
  return spans;
}

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String _weekday(DateTime day) =>
    const ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'][day.weekday - 1];

String _formatTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
