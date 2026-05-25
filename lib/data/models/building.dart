import 'package:hive/hive.dart';
import 'nav_node.dart';
import 'nav_edge.dart';
import 'wifi_fingerprint.dart';

part 'building.g.dart';

@HiveType(typeId: 4)
class FloorPlan extends HiveObject {
  @HiveField(0)
  final int floor;

  @HiveField(1)
  final String? imageUrl; // URL or local path

  @HiveField(2)
  final double widthMeters;

  @HiveField(3)
  final double heightMeters;

  FloorPlan({
    required this.floor,
    this.imageUrl,
    required this.widthMeters,
    required this.heightMeters,
  });

  factory FloorPlan.fromJson(Map<String, dynamic> json) => FloorPlan(
        floor: json['floor'] as int,
        imageUrl: json['imageUrl'] as String?,
        widthMeters: (json['widthMeters'] as num).toDouble(),
        heightMeters: (json['heightMeters'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'floor': floor,
        'imageUrl': imageUrl,
        'widthMeters': widthMeters,
        'heightMeters': heightMeters,
      };
}

@HiveType(typeId: 5)
class Building extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String address;

  @HiveField(3)
  final List<FloorPlan> floorPlans;

  @HiveField(4)
  final List<NavNode> nodes;

  @HiveField(5)
  final List<NavEdge> edges;

  @HiveField(6)
  final List<WifiFingerprint> fingerprints;

  @HiveField(7)
  final DateTime lastSynced;

  Building({
    required this.id,
    required this.name,
    required this.address,
    required this.floorPlans,
    required this.nodes,
    required this.edges,
    required this.fingerprints,
    required this.lastSynced,
  });

  factory Building.fromJson(Map<String, dynamic> json) => Building(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String? ?? '',
        floorPlans: (json['floorPlans'] as List? ?? [])
            .map((f) => FloorPlan.fromJson(f as Map<String, dynamic>))
            .toList(),
        nodes: (json['nodes'] as List? ?? [])
            .map((n) => NavNode.fromJson(n as Map<String, dynamic>))
            .toList(),
        edges: (json['edges'] as List? ?? [])
            .map((e) => NavEdge.fromJson(e as Map<String, dynamic>))
            .toList(),
        fingerprints: (json['fingerprints'] as List? ?? [])
            .map((f) => WifiFingerprint.fromJson(f as Map<String, dynamic>))
            .toList(),
        lastSynced: json['lastSynced'] != null
            ? DateTime.parse(json['lastSynced'] as String)
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'floorPlans': floorPlans.map((f) => f.toJson()).toList(),
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
        'fingerprints': fingerprints.map((f) => f.toJson()).toList(),
        'lastSynced': lastSynced.toIso8601String(),
      };

  List<NavNode> nodesOnFloor(int floor) =>
      nodes.where((n) => n.floor == floor).toList();

  List<NavEdge> edgesOnFloor(int floor) => edges.where((e) {
        final from = nodes.firstWhere((n) => n.id == e.fromNodeId,
            orElse: () => nodes.first);
        return from.floor == floor;
      }).toList();
}
