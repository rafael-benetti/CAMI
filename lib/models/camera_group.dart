class CameraGroup {
  final String name;
  final int order;
  final Set<int> cameraIds;

  const CameraGroup({
    required this.name,
    required this.order,
    required this.cameraIds,
  });
}
