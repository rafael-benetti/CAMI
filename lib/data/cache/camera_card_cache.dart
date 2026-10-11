import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/camera_item.dart';

class CameraCardCache {
  static String keyFor(Map<String, dynamic> user) {
    final identity =
        user['id']?.toString() ?? user['email']?.toString() ?? 'unknown';
    return 'cami.camera_cards.$identity';
  }

  static Future<List<CameraItem>> load(String key) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(key);
      if (raw == null) return const [];
      return (jsonDecode(raw) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(CameraItem.fromCacheJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(String? key, List<CameraItem> cameras) async {
    if (key == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      key,
      jsonEncode(cameras.map((camera) => camera.toCacheJson()).toList()),
    );
  }
}
