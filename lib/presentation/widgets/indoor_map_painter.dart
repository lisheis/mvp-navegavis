import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/models/building.dart';
import '../../data/models/nav_node.dart';
import '../../data/models/nav_edge.dart';
import '../../data/models/position.dart';
import '../../data/models/route_step.dart';

/// Full indoor map widget — renders:
///   • floor plan background: PNG importado do PDF (se existir) ou grid escuro
///   • edges (grey) + route edges (blue, highlighted)
///   • nodes as labelled circles
///   • user position dot (animated pulse)
///   • selected node highlight (editor mode)
class IndoorMapView extends StatefulWidget {
  final Building building;
  final int currentFloor;
  final IndoorPosition? userPosition;
  final NavigationRoute? route;
  final int currentStepIndex;
  final String? selectedNodeId;
  final Offset? draggedNodePosition;
  final bool editMode;

  const IndoorMapView({
    super.key,
    required this.building,
    required this.currentFloor,
    required this.userPosition,
    required this.route,
    required this.currentStepIndex,
    this.selectedNodeId,
    this.draggedNodePosition,
    this.editMode = false,
  });

  @override
  State<IndoorMapView> createState() => _IndoorMapViewState();
}

class _IndoorMapViewState extends State<IndoorMapView> {
  // Caminho da imagem do andar atual (pode ser null)
  String? _currentImagePath;
  // true quando a imagem existe no disco
  bool _hasImage = false;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(IndoorMapView old) {
    super.didUpdateWidget(old);
    // Re-check image when floor or building changes
    if (old.currentFloor != widget.currentFloor ||
        old.building.id != widget.building.id) {
      _resolveImage();
    }
  }

  void _resolveImage() {
    final fp = widget.building.floorPlans.firstWhere(
      (f) => f.floor == widget.currentFloor,
      orElse: () => widget.building.floorPlans.isNotEmpty
          ? widget.building.floorPlans.first
          : FloorPlan(floor: 0, widthMeters: 50, heightMeters: 30),
    );

    final path = fp.imageUrl;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      setState(() {
        _currentImagePath = path;
        _hasImage = true;
      });
    } else {
      setState(() {
        _currentImagePath = null;
        _hasImage = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fp = widget.building.floorPlans.firstWhere(
      (f) => f.floor == widget.currentFloor,
      orElse: () => widget.building.floorPlans.isNotEmpty
          ? widget.building.floorPlans.first
          : FloorPlan(floor: 0, widthMeters: 50, heightMeters: 30),
    );

    final nodes = widget.building.nodesOnFloor(widget.currentFloor);
    final edges = widget.building.edgesOnFloor(widget.currentFloor);

    return LayoutBuilder(builder: (ctx, constraints) {
      return Stack(
        children: [
          // ── Planta baixa (imagem PNG do PDF) ──────────────────────────
          if (_hasImage && _currentImagePath != null)
            Positioned.fill(
              child: Image.file(
                File(_currentImagePath!),
                fit: BoxFit.contain,
                // Aplica leve overlay escuro para melhorar visibilidade dos nós
                color: Colors.black.withOpacity(0.25),
                colorBlendMode: BlendMode.darken,
              ),
            ),

          // ── Grafo + usuário (CustomPainter) ────────────────────────────
          CustomPaint(
            size: constraints.biggest,
            painter: _IndoorMapPainter(
              floorPlan: fp,
              nodes: nodes,
              edges: edges,
              allNodes: widget.building.nodes,
              userPosition: widget.userPosition,
              route: widget.route,
              currentStepIndex: widget.currentStepIndex,
              selectedNodeId: widget.selectedNodeId,
              draggedNodePosition: widget.draggedNodePosition,
              editMode: widget.editMode,
              // Quando há imagem, o painter não desenha o fundo escuro
              hasFloorPlanImage: _hasImage,
            ),
          ),

          // ── Badge de imagem no editor ──────────────────────────────────
          if (widget.editMode && _hasImage)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image, size: 14, color: Colors.white70),
                    SizedBox(width: 4),
                    Text('Planta baixa',
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _IndoorMapPainter extends CustomPainter {
  final FloorPlan floorPlan;
  final List<NavNode> nodes;
  final List<NavEdge> edges;
  final List<NavNode> allNodes;
  final IndoorPosition? userPosition;
  final NavigationRoute? route;
  final int currentStepIndex;
  final String? selectedNodeId;
  final Offset? draggedNodePosition;
  final bool editMode;
  final bool hasFloorPlanImage;

  _IndoorMapPainter({
    required this.floorPlan,
    required this.nodes,
    required this.edges,
    required this.allNodes,
    required this.userPosition,
    required this.route,
    required this.currentStepIndex,
    this.selectedNodeId,
    this.draggedNodePosition,
    required this.editMode,
    this.hasFloorPlanImage = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / floorPlan.widthMeters;
    final scaleY = size.height / floorPlan.heightMeters;

    Offset toPixel(double x, double y) =>
        Offset(x * scaleX, y * scaleY);

    // Background — só desenha o fundo escuro se não há imagem de planta
    if (!hasFloorPlanImage) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFF1A1A2A),
      );
    }

    // Grid — mais sutil quando há imagem
    _drawGrid(canvas, size, scaleX, scaleY, faint: hasFloorPlanImage);

    // Collect route node IDs for highlight
    final routeNodeIds = route?.nodes.map((n) => n.id).toSet() ?? {};

    // Edges
    for (final edge in edges) {
      final from = allNodes.firstWhere(
        (n) => n.id == edge.fromNodeId,
        orElse: () => nodes.isEmpty ? _dummyNode() : nodes.first,
      );
      final to = allNodes.firstWhere(
        (n) => n.id == edge.toNodeId,
        orElse: () => nodes.isEmpty ? _dummyNode() : nodes.first,
      );

      final isRouteEdge =
          routeNodeIds.contains(from.id) && routeNodeIds.contains(to.id);

      final paint = Paint()
        ..color =
            isRouteEdge ? const Color(0xFF2196F3) : const Color(0xFF555577)
        ..strokeWidth = isRouteEdge ? 3 : 1.5
        ..style = PaintingStyle.stroke;

      canvas.drawLine(toPixel(from.x, from.y), toPixel(to.x, to.y), paint);
    }

    // Nodes
    for (final node in nodes) {
      final isSelected = node.id == selectedNodeId;
      
      // Use dragged position if this is the selected node and it is currently being dragged
      final effectiveX = (isSelected && draggedNodePosition != null) ? draggedNodePosition!.dx : node.x;
      final effectiveY = (isSelected && draggedNodePosition != null) ? draggedNodePosition!.dy : node.y;
      
      final pos = toPixel(effectiveX, effectiveY);
      final isOnRoute = routeNodeIds.contains(node.id);

      Color fillColor = _nodeColor(node.nodeType);
      if (isSelected) fillColor = Colors.amber;
      if (isOnRoute) fillColor = const Color(0xFF1565C0);

      // Circle
      canvas.drawCircle(
        pos,
        isSelected ? 10 : 7,
        Paint()..color = fillColor,
      );
      canvas.drawCircle(
        pos,
        isSelected ? 10 : 7,
        Paint()
          ..color = Colors.white.withOpacity(0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: node.label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 9,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos.translate(-tp.width / 2, 9));
    }

    // User position
    final pos = userPosition;
    if (pos != null && pos.floor == floorPlan.floor) {
      final pxPos = toPixel(pos.x, pos.y);

      // Accuracy ring
      canvas.drawCircle(
        pxPos,
        20,
        Paint()
          ..color = Colors.blue.withOpacity(0.15)
          ..style = PaintingStyle.fill,
      );

      // Blue dot
      canvas.drawCircle(
        pxPos,
        8,
        Paint()..color = const Color(0xFF2196F3),
      );
      canvas.drawCircle(
        pxPos,
        8,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      // Confidence text
      final conf = '${(pos.confidence * 100).toStringAsFixed(0)}%';
      final ctp = TextPainter(
        text: TextSpan(
            text: conf,
            style: const TextStyle(color: Colors.white70, fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      ctp.paint(canvas, pxPos.translate(-ctp.width / 2, 11));
    }

    // Route step indicator: highlight current target node
    if (route != null && currentStepIndex < route!.steps.length) {
      final target = route!.steps[currentStepIndex].toNode;
      if (target.floor == floorPlan.floor) {
        final tPos = toPixel(target.x, target.y);
        canvas.drawCircle(
          tPos,
          14,
          Paint()
            ..color = Colors.green.withOpacity(0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
    }
  }

  void _drawGrid(Canvas canvas, Size size, double scaleX, double scaleY,
      {bool faint = false}) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(faint ? 0.08 : 0.05)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += scaleX * 5) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += scaleY * 5) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  Color _nodeColor(NodeType type) {
    switch (type) {
      case NodeType.entrance:
        return Colors.green;
      case NodeType.exit:
        return Colors.red;
      case NodeType.bathroom:
        return Colors.teal;
      case NodeType.elevator:
        return Colors.purple;
      case NodeType.stairs:
        return Colors.orange;
      case NodeType.room:
        return Colors.indigo;
      case NodeType.corridor:
        return const Color(0xFF37474F);
      case NodeType.poi:
        return Colors.pink;
    }
  }

  NavNode _dummyNode() => NavNode(
        id: '',
        label: '',
        x: 0,
        y: 0,
        floor: 0,
        nodeTypeStr: 'corridor',
        buildingId: '',
      );

  @override
  bool shouldRepaint(covariant _IndoorMapPainter old) => true;
}
