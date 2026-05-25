import 'package:hive/hive.dart';

part 'nav_node.g.dart';

enum NodeType { entrance, corridor, room, elevator, stairs, bathroom, exit, poi }

@HiveType(typeId: 0)
class NavNode extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String label;

  @HiveField(2)
  final double x; // meters or normalized 0..1

  @HiveField(3)
  final double y;

  @HiveField(4)
  final int floor;

  @HiveField(5)
  final String nodeTypeStr;

  @HiveField(6)
  final String buildingId;

  @HiveField(7)
  final Map<String, dynamic>? metadata;

  NavNode({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    required this.floor,
    required this.nodeTypeStr,
    required this.buildingId,
    this.metadata,
  });

  NodeType get nodeType => NodeType.values.firstWhere(
        (e) => e.name == nodeTypeStr,
        orElse: () => NodeType.poi,
      );

  factory NavNode.fromJson(Map<String, dynamic> json) => NavNode(
        id: json['id'] as String,
        label: json['label'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        floor: json['floor'] as int,
        nodeTypeStr: json['nodeType'] as String,
        buildingId: json['buildingId'] as String,
        metadata: json['metadata'] as Map<String, dynamic>?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'x': x,
        'y': y,
        'floor': floor,
        'nodeType': nodeTypeStr,
        'buildingId': buildingId,
        'metadata': metadata,
      };

  NavNode copyWith({double? x, double? y, String? label, String? nodeTypeStr}) =>
      NavNode(
        id: id,
        label: label ?? this.label,
        x: x ?? this.x,
        y: y ?? this.y,
        floor: floor,
        nodeTypeStr: nodeTypeStr ?? this.nodeTypeStr,
        buildingId: buildingId,
        metadata: metadata,
      );
}
