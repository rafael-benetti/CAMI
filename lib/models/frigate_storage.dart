class FrigateStorageVolume {
  final String path;
  final int totalBytes;
  final int usedBytes;
  final int freeBytes;

  const FrigateStorageVolume({
    required this.path,
    required this.totalBytes,
    required this.usedBytes,
    required this.freeBytes,
  });

  double get usedFraction =>
      totalBytes == 0 ? 0 : (usedBytes / totalBytes).clamp(0.0, 1.0);

  double get usedPercent => usedFraction * 100;
}

class FrigateStorageStats {
  final List<FrigateStorageVolume> volumes;

  const FrigateStorageStats(this.volumes);

  FrigateStorageVolume get primaryVolume {
    return volumes.firstWhere(
      (volume) => volume.path.contains('/recordings'),
      orElse: () => volumes.first,
    );
  }
}
