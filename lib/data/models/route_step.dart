import 'nav_node.dart';

enum Direction { straight, left, right, slightLeft, slightRight, uTurn, arrive }

class RouteStep {
  final NavNode fromNode;
  final NavNode toNode;
  final double distanceMeters;
  final Direction direction;
  final String instruction; // Portuguese TTS string

  const RouteStep({
    required this.fromNode,
    required this.toNode,
    required this.distanceMeters,
    required this.direction,
    required this.instruction,
  });
}

class NavigationRoute {
  final List<NavNode> nodes;
  final List<RouteStep> steps;
  final double totalDistanceMeters;
  final int estimatedSeconds;

  const NavigationRoute({
    required this.nodes,
    required this.steps,
    required this.totalDistanceMeters,
    required this.estimatedSeconds,
  });

  bool get isEmpty => nodes.isEmpty;
}
