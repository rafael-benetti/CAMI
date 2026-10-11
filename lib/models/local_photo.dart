import 'dart:typed_data';

class LocalPhoto {
  final String path;
  final String cameraName;
  final String location;
  final DateTime capturedAt;

  const LocalPhoto({
    required this.path,
    required this.cameraName,
    required this.location,
    required this.capturedAt,
  });

  factory LocalPhoto.fromJson(Map<String, dynamic> json) {
    return LocalPhoto(
      path: json['path'] as String,
      cameraName: json['camera_name'] as String? ?? 'Câmera',
      location: json['location'] as String? ?? 'Sem localização',
      capturedAt: DateTime.parse(json['captured_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'path': path,
    'camera_name': cameraName,
    'location': location,
    'captured_at': capturedAt.toIso8601String(),
  };
}
