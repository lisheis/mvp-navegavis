/// Estimated indoor position
class IndoorPosition {
  final double x;
  final double y;
  final int floor;
  final double confidence; // 0..1
  final String? nearestNodeId;

  const IndoorPosition({
    required this.x,
    required this.y,
    required this.floor,
    this.confidence = 0.0,
    this.nearestNodeId,
  });

  IndoorPosition copyWith({
    double? x,
    double? y,
    int? floor,
    double? confidence,
    String? nearestNodeId,
  }) =>
      IndoorPosition(
        x: x ?? this.x,
        y: y ?? this.y,
        floor: floor ?? this.floor,
        confidence: confidence ?? this.confidence,
        nearestNodeId: nearestNodeId ?? this.nearestNodeId,
      );

  @override
  String toString() =>
      'IndoorPosition(x:${x.toStringAsFixed(2)}, y:${y.toStringAsFixed(2)}, floor:$floor, conf:${(confidence * 100).toStringAsFixed(0)}%)';
}
