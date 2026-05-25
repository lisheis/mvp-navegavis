import 'dart:math';
import '../../data/models/nav_node.dart';
import '../../data/models/nav_edge.dart';
import '../../data/models/position.dart';

double _dist(double x1, double y1, double x2, double y2) {
  final dx = x1 - x2;
  final dy = y1 - y2;
  return sqrt(dx * dx + dy * dy);
}

/// Projects a point P onto segment AB and returns the projected position.
/// Returns null if projection falls outside the segment.
(double x, double y)? _projectOntoSegment(
  double px, double py,
  double ax, double ay,
  double bx, double by,
) {
  final abx = bx - ax;
  final aby = by - ay;
  final len2 = abx * abx + aby * aby;
  if (len2 == 0) return null;
  final t = ((px - ax) * abx + (py - ay) * aby) / len2;
  if (t < 0 || t > 1) return null;
  return (ax + t * abx, ay + t * aby);
}

/// Map matching — snaps a raw (x,y) position onto the nearest graph edge or node.
///
/// Prevents the user dot from appearing in walls or outside corridors.
class MapMatcher {
  /// Snaps [position] to the nearest point on the graph (edge or node).
  IndoorPosition snap({
    required IndoorPosition position,
    required List<NavNode> nodes,
    required List<NavEdge> edges,
    required double maxSnapDistanceMeters,
  }) {
    final floorNodes = nodes.where((n) => n.floor == position.floor).toList();
    if (floorNodes.isEmpty) return position;

    double bestDist = double.infinity;
    double bestX = position.x;
    double bestY = position.y;
    String? bestNodeId;

    // Try snapping to each edge
    for (final edge in edges) {
      final from = nodes.firstWhere(
        (n) => n.id == edge.fromNodeId,
        orElse: () => floorNodes.first,
      );
      final to = nodes.firstWhere(
        (n) => n.id == edge.toNodeId,
        orElse: () => floorNodes.first,
      );
      if (from.floor != position.floor) continue;

      final proj = _projectOntoSegment(
        position.x, position.y,
        from.x, from.y,
        to.x, to.y,
      );
      if (proj != null) {
        final d = _dist(position.x, position.y, proj.$1, proj.$2);
        if (d < bestDist) {
          bestDist = d;
          bestX = proj.$1;
          bestY = proj.$2;
          // Nearest endpoint becomes the candidate node
          final dFrom = _dist(proj.$1, proj.$2, from.x, from.y);
          final dTo = _dist(proj.$1, proj.$2, to.x, to.y);
          bestNodeId = dFrom < dTo ? from.id : to.id;
        }
      }
    }

    // Also check direct node proximity (handles dead-ends)
    for (final node in floorNodes) {
      final d = _dist(position.x, position.y, node.x, node.y);
      if (d < bestDist) {
        bestDist = d;
        bestX = node.x;
        bestY = node.y;
        bestNodeId = node.id;
      }
    }

    // Only snap if close enough
    if (bestDist > maxSnapDistanceMeters) return position;

    return position.copyWith(
      x: bestX,
      y: bestY,
      nearestNodeId: bestNodeId,
    );
  }
}
