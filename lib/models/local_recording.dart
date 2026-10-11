class LocalRecording {
  final String path;
  final String cameraName;
  final String location;
  final DateTime startedAt;
  final Duration duration;

  const LocalRecording({
    required this.path,
    required this.cameraName,
    required this.location,
    required this.startedAt,
    required this.duration,
  });

  factory LocalRecording.fromJson(Map<String, dynamic> json) {
    return LocalRecording(
      path: json['path'] as String,
      cameraName: json['camera_name'] as String? ?? 'Câmera',
      location: json['location'] as String? ?? 'Sem localização',
      startedAt: DateTime.parse(json['started_at'] as String),
      duration: Duration(seconds: (json['duration_seconds'] as num).toInt()),
    );
  }

  Map<String, dynamic> toJson() => {
    'path': path,
    'camera_name': cameraName,
    'location': location,
    'started_at': startedAt.toIso8601String(),
    'duration_seconds': duration.inSeconds,
  };
}
