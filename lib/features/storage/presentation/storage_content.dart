import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/frigate_client.dart';
import '../../../models/frigate_storage.dart';

class StorageContent extends StatefulWidget {
  final FrigateClient frigateClient;
  final String token;

  const StorageContent({
    super.key,
    required this.frigateClient,
    required this.token,
  });

  @override
  State<StorageContent> createState() => _StorageContentState();
}

class _StorageContentState extends State<StorageContent> {
  FrigateStorageStats? stats;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.frigateClient.fetchStorageStats(
        token: widget.token,
      );
      if (mounted) setState(() => stats = result);
    } on FrigateException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading && stats == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 64),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null && stats == null) {
      return Card(
        color: panel,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: load,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    final storage = stats!.primaryVolume;
    final color = storage.usedPercent >= 90
        ? Colors.redAccent
        : storage.usedPercent >= 75
        ? Colors.orangeAccent
        : statusGreen;
    return Column(
      children: [
        Card(
          color: panel,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.storage_outlined, color: blue),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Armazenamento do disco',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Atualizar armazenamento',
                      onPressed: loading ? null : load,
                      icon: const Icon(Icons.refresh, color: muted),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 176,
                  height: 176,
                  child: CustomPaint(
                    painter: _StorageRingPainter(
                      fraction: storage.usedFraction,
                      color: color,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${storage.usedPercent.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            'utilizado',
                            style: TextStyle(color: muted, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _StorageRow(
                  label: 'Usado',
                  value: _formatBytes(storage.usedBytes),
                  color: color,
                ),
                _StorageRow(
                  label: 'Livre no disco',
                  value: _formatBytes(storage.freeBytes),
                  color: statusGreen,
                ),
                _StorageRow(
                  label: 'Capacidade total',
                  value: _formatBytes(storage.totalBytes),
                  color: muted,
                ),
                const SizedBox(height: 12),
                Text(
                  storage.path,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted, fontSize: 9),
                ),
              ],
            ),
          ),
        ),
        if (stats!.volumes.length > 1) ...[
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Outros volumes', style: TextStyle(color: muted)),
          ),
          const SizedBox(height: 8),
          ...stats!.volumes
              .where((volume) => volume.path != storage.path)
              .map(
                (volume) => Card(
                  color: panel,
                  child: ListTile(
                    title: Text(
                      volume.path,
                      style: const TextStyle(fontSize: 10),
                    ),
                    subtitle: Text(
                      '${_formatBytes(volume.usedBytes)} de ${_formatBytes(volume.totalBytes)}',
                      style: const TextStyle(color: muted, fontSize: 9),
                    ),
                    trailing: Text('${volume.usedPercent.toStringAsFixed(0)}%'),
                  ),
                ),
              ),
        ],
      ],
    );
  }
}

class _StorageRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StorageRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
        Text(value, style: const TextStyle(fontSize: 11, color: muted)),
      ],
    ),
  );
}

class _StorageRingPainter extends CustomPainter {
  final double fraction;
  final Color color;

  const _StorageRingPainter({required this.fraction, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 11;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = panelBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;
    final progress = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    if (fraction > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        progress,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StorageRingPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.color != color;
}

String _formatBytes(int value) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var amount = value.toDouble();
  var unit = 0;
  while (amount >= 1024 && unit < units.length - 1) {
    amount /= 1024;
    unit++;
  }
  return '${amount.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
}
