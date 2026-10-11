import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/local_recording.dart';

class LocalRecordingStore {
  static const _key = 'cami.local_recordings';

  static Future<List<LocalRecording>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_key);
    if (raw == null) return const [];
    try {
      final values = (jsonDecode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(LocalRecording.fromJson)
          .toList();
      final available = <LocalRecording>[];
      for (final recording in values) {
        if (await File(recording.path).exists()) available.add(recording);
      }
      final root = await getApplicationDocumentsDirectory();
      final directory = Directory('${root.path}/recordings');
      if (await directory.exists()) {
        await for (final entry in directory.list()) {
          final isRecording =
              entry is File &&
              (entry.path.toLowerCase().endsWith('.mkv') ||
                  entry.path.toLowerCase().endsWith('.ts'));
          if (!isRecording) {
            continue;
          }
          if (available.any((recording) => recording.path == entry.path)) {
            continue;
          }
          available.add(
            LocalRecording(
              path: entry.path,
              cameraName: 'Gravação local',
              location: 'Arquivo recuperado',
              startedAt: await entry.lastModified(),
              duration: Duration.zero,
            ),
          );
        }
      }
      available.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      final previousPaths = values.map((recording) => recording.path).toSet();
      final recoveredRecording = available.any(
        (recording) => !previousPaths.contains(recording.path),
      );
      if (available.length != values.length || recoveredRecording) {
        await _write(available);
      }
      return available;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> add(LocalRecording recording) async {
    final current = await load();
    await _write([recording, ...current]);
  }

  static Future<void> _write(List<LocalRecording> recordings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      jsonEncode(recordings.map((recording) => recording.toJson()).toList()),
    );
  }
}
