import 'package:hive/hive.dart';

part 'nav_edge.g.dart';

enum EdgeType { walk, stairs, elevator, ramp }

@HiveType(typeId: 1)
class NavEdge extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String fromNodeId;

  @HiveField(2)
  final String toNodeId;

  @HiveField(3)
  final double weight; // distance in meters

  @HiveField(4)
  final bool bidirectional;

  @HiveField(5)
  final String edgeTypeStr;

  @HiveField(6)
  final bool accessible; // wheelchair accessible

  NavEdge({
    required this.id,
    required this.fromNodeId,
    required this.toNodeId,
    required this.weight,
    this.bidirectional = true,
    this.edgeTypeStr = 'walk',
    this.accessible = true,
  });

  EdgeType get edgeType => EdgeType.values.firstWhere(
        (e) => e.name == edgeTypeStr,
        orElse: () => EdgeType.walk,
      );

  factory NavEdge.fromJson(Map<String, dynamic> json) => NavEdge(
        id: json['id'] as String,
        fromNodeId: json['fromNodeId'] as String,
        toNodeId: json['toNodeId'] as String,
        weight: (json['weight'] as num).toDouble(),
        bidirectional: json['bidirectional'] as bool? ?? true,
        edgeTypeStr: json['edgeType'] as String? ?? 'walk',
        accessible: json['accessible'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fromNodeId': fromNodeId,
        'toNodeId': toNodeId,
        'weight': weight,
        'bidirectional': bidirectional,
        'edgeType': edgeTypeStr,
        'accessible': accessible,
      };
}
