import 'dart:typed_data';

class CameraItem {
  final int? id;
  final String name;
  final String place;
  final String rtspUrl;
  final bool online;
  final Uint8List? thumbnail;

  const CameraItem({
    this.id,
    required this.name,
    required this.place,
    required this.rtspUrl,
    required this.online,
    this.thumbnail,
  });

  factory CameraItem.fromJson(Map<String, dynamic> json) {
    return CameraItem(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String? ?? 'Câmera',
      place: json['location'] as String? ?? 'Sem localização',
      rtspUrl: json['rtsp_url'] as String? ?? '',
      online: json['enabled'] as bool? ?? true,
    );
  }

  factory CameraItem.fromCacheJson(Map<String, dynamic> json) {
    return CameraItem(
      id: (json['id'] as num?)?.toInt(),
      name: json['name'] as String? ?? 'Câmera',
      place: json['location'] as String? ?? 'Sem localização',
      // A URL RTSP e suas possíveis credenciais não ficam neste cache visual.
      rtspUrl: '',
      online: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toCacheJson() => {
    'id': id,
    'name': name,
    'location': place,
    'enabled': online,
  };
}
