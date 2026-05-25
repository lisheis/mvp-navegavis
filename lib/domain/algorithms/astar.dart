import 'dart:math';
import '../../data/models/nav_node.dart';
import '../../data/models/nav_edge.dart';
import '../../data/models/route_step.dart';

double _heuristic(NavNode a, NavNode b) {
  final dx = a.x - b.x;
  final dy = a.y - b.y;
  // Floor penalty discourages cross-floor paths without an elevator/stairs edge
  final floorPenalty = (a.floor - b.floor).abs() * 10.0;
  return sqrt(dx * dx + dy * dy) + floorPenalty;
}

double _angleBetween(NavNode from, NavNode via, NavNode to) {
  final v1x = via.x - from.x;
  final v1y = via.y - from.y;
  final v2x = to.x - via.x;
  final v2y = to.y - via.y;
  return atan2(v2y, v2x) - atan2(v1y, v1x);
}

Direction _directionFromAngle(double angle) {
  // Normalise to -π..π
  double a = angle;
  while (a > pi) a -= 2 * pi;
  while (a < -pi) a += 2 * pi;

  if (a.abs() < 0.26) return Direction.straight;
  if (a > 1.3) return Direction.left;
  if (a < -1.3) return Direction.right;
  if (a > 0) return Direction.slightLeft;
  return Direction.slightRight;
}

String _instructionPt(Direction dir, NavNode to, double dist) {
  final distStr = dist < 5
      ? 'poucos metros'
      : '${dist.toStringAsFixed(0)} metros';
  switch (dir) {
    case Direction.straight:
      return 'Siga em frente por $distStr até ${to.label}.';
    case Direction.left:
      return 'Vire à esquerda e siga por $distStr até ${to.label}.';
    case Direction.right:
      return 'Vire à direita e siga por $distStr até ${to.label}.';
    case Direction.slightLeft:
      return 'Vire levemente à esquerda e siga por $distStr até ${to.label}.';
    case Direction.slightRight:
      return 'Vire levemente à direita e siga por $distStr até ${to.label}.';
    case Direction.uTurn:
      return 'Faça um retorno e siga por $distStr até ${to.label}.';
    case Direction.arrive:
      return 'Você chegou ao destino: ${to.label}.';
  }
}

class _Node implements Comparable<_Node> {
  final NavNode node;
  double g;
  double f;
  _Node? parent;

  _Node(this.node, {this.g = 0, this.f = 0, this.parent});

  @override
  int compareTo(_Node other) => f.compareTo(other.f);
}

/// A* pathfinding over an indoor navigation graph.
class AStarPathfinder {
  /// Returns a [NavigationRoute] from [startId] to [goalId],
  /// or null if no path exists.
  NavigationRoute? findRoute({
    required String startId,
    required String goalId,
    required List<NavNode> nodes,
    required List<NavEdge> edges,
    bool accessibleOnly = false,
  }) {
    final nodeMap = {for (final n in nodes) n.id: n};
    final start = nodeMap[startId];
    final goal = nodeMap[goalId];
    if (start == null || goal == null) return null;
    if (startId == goalId) {
      return NavigationRoute(
        nodes: [start],
        steps: [],
        totalDistanceMeters: 0,
        estimatedSeconds: 0,
      );
    }

    // Build adjacency list
    final adj = <String, List<(NavNode, NavEdge)>>{};
    for (final edge in edges) {
      if (accessibleOnly && !edge.accessible) continue;
      final from = nodeMap[edge.fromNodeId];
      final to = nodeMap[edge.toNodeId];
      if (from == null || to == null) continue;
      adj.putIfAbsent(edge.fromNodeId, () => []).add((to, edge));
      if (edge.bidirectional) {
        adj.putIfAbsent(edge.toNodeId, () => []).add((from, edge));
      }
    }

    final openSet = <String, _Node>{};
    final closedSet = <String>{};

    final startEntry = _Node(start, g: 0, f: _heuristic(start, goal));
    openSet[startId] = startEntry;

    while (openSet.isNotEmpty) {
      // Pick node with lowest f
      final current = openSet.values.reduce((a, b) => a.f < b.f ? a : b);
      if (current.node.id == goalId) {
        return _reconstructRoute(current, nodeMap, edges);
      }

      openSet.remove(current.node.id);
      closedSet.add(current.node.id);

      for (final (neighbor, edge) in adj[current.node.id] ?? <(NavNode, NavEdge)>[]) {
        if (closedSet.contains(neighbor.id)) continue;
        final tentativeG = current.g + edge.weight;

        final existing = openSet[neighbor.id];
        if (existing == null || tentativeG < existing.g) {
          final entry = _Node(
            neighbor,
            g: tentativeG,
            f: tentativeG + _heuristic(neighbor, goal),
            parent: current,
          );
          openSet[neighbor.id] = entry;
        }
      }
    }
    return null; // no path found
  }

  NavigationRoute _reconstructRoute(
    _Node goalEntry,
    Map<String, NavNode> nodeMap,
    List<NavEdge> edges,
  ) {
    final path = <NavNode>[];
    _Node? current = goalEntry;
    while (current != null) {
      path.insert(0, current.node);
      current = current.parent;
    }

    double totalDist = 0;
    final steps = <RouteStep>[];

    for (int i = 0; i < path.length - 1; i++) {
      final from = path[i];
      final to = path[i + 1];
      final edge = edges.firstWhere(
        (e) =>
            (e.fromNodeId == from.id && e.toNodeId == to.id) ||
            (e.bidirectional && e.fromNodeId == to.id && e.toNodeId == from.id),
        orElse: () => NavEdge(
          id: '',
          fromNodeId: from.id,
          toNodeId: to.id,
          weight: _heuristic(from, to),
        ),
      );

      totalDist += edge.weight;

      Direction dir;
      if (i == path.length - 2) {
        dir = Direction.arrive;
      } else if (i == 0) {
        dir = Direction.straight;
      } else {
        final angle = _angleBetween(path[i - 1], from, to);
        dir = _directionFromAngle(angle);
      }

      steps.add(RouteStep(
        fromNode: from,
        toNode: to,
        distanceMeters: edge.weight,
        direction: dir,
        instruction: _instructionPt(dir, to, edge.weight),
      ));
    }

    return NavigationRoute(
      nodes: path,
      steps: steps,
      totalDistanceMeters: totalDist,
      estimatedSeconds: (totalDist / 1.2).round(), // avg walking speed 1.2 m/s
    );
  }
}
