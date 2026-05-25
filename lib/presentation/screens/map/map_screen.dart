import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/building_provider.dart';
import '../../widgets/indoor_map_painter.dart';
import '../../../data/models/nav_node.dart';
import '../../../data/models/nav_edge.dart';
import '../../../services/import_service.dart';

enum _EditMode { none, addNode, addEdge, delete, move }

class MapScreen extends StatefulWidget {
  final String buildingId;
  const MapScreen({super.key, required this.buildingId});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  _EditMode _mode = _EditMode.none;
  String? _selectedNodeId;
  Offset? _draggedNodePosition;
  int _currentFloor = 0;
  final _uuid = const Uuid();
  final _importService = ImportService();
  bool _importing = false;

  NodeType _nodeType = NodeType.corridor;

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BuildingProvider>();
    final building = bp.selected;

    return Scaffold(
      appBar: AppBar(
        title: Text('Editor — ${building?.name ?? ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Voltar ao início',
            onPressed: () => context.go('/'),
          ),
          _ModeButton(
              label: 'Nó', icon: Icons.add_location, mode: _EditMode.addNode,
              current: _mode, onTap: () => setState(() => _mode = _EditMode.addNode)),
          _ModeButton(
              label: 'Mover', icon: Icons.open_with, mode: _EditMode.move,
              current: _mode, onTap: () => setState(() => _mode = _EditMode.move)),
          _ModeButton(
              label: 'Aresta', icon: Icons.timeline, mode: _EditMode.addEdge,
              current: _mode, onTap: () => setState(() => _mode = _EditMode.addEdge)),
          _ModeButton(
              label: 'Apagar', icon: Icons.delete_outline, mode: _EditMode.delete,
              current: _mode, onTap: () => setState(() => _mode = _EditMode.delete)),
          // Menu de importação / exportação
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) => _onMenuAction(context, v),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'import_pdf',
                child: ListTile(
                  leading: Icon(Icons.picture_as_pdf),
                  title: Text('Importar PDF (planta)'),
                  dense: true,
                ),
              ),
              PopupMenuItem(
                value: 'import_json',
                child: ListTile(
                  leading: Icon(Icons.data_object),
                  title: Text('Importar JSON do prédio'),
                  dense: true,
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'clear_nodes',
                child: ListTile(
                  leading: Icon(Icons.layers_clear, color: Colors.red),
                  title: Text('Limpar nós deste andar',
                      style: TextStyle(color: Colors.red)),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: building == null
          ? const Center(child: Text('Prédio não encontrado'))
          : Stack(
              children: [
                Column(
                  children: [
                    _NodeTypeSelector(
                      selected: _nodeType,
                      onChanged: (t) => setState(() => _nodeType = t),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTapUp: (details) {
                          if (_mode != _EditMode.move) {
                            _onMapTap(context, details.localPosition, building.floorPlans
                                .firstWhere((f) => f.floor == _currentFloor,
                                    orElse: () => building.floorPlans.first));
                          }
                        },
                        onPanStart: (details) {
                          if (_mode != _EditMode.move) return;
                          final bp = context.read<BuildingProvider>();
                          final b = bp.selected;
                          if (b == null) return;
                          final floorPlan = b.floorPlans.firstWhere(
                            (f) => f.floor == _currentFloor,
                            orElse: () => b.floorPlans.first,
                          );
                          final renderBox = context.findRenderObject() as RenderBox?;
                          if (renderBox == null) return;
                          final size = renderBox.size;
                          final xM = (details.localPosition.dx / size.width) * floorPlan.widthMeters;
                          final yM = (details.localPosition.dy / size.height) * floorPlan.heightMeters;

                          final tapped = _findNearestNode(b.nodes, xM, yM, _currentFloor);
                          if (tapped != null) {
                            setState(() {
                              _selectedNodeId = tapped.id;
                            });
                          }
                        },
                        onPanUpdate: (details) {
                          if (_mode != _EditMode.move || _selectedNodeId == null) return;
                          final bp = context.read<BuildingProvider>();
                          final b = bp.selected;
                          if (b == null) return;
                          final floorPlan = b.floorPlans.firstWhere(
                            (f) => f.floor == _currentFloor,
                            orElse: () => b.floorPlans.first,
                          );
                          final renderBox = context.findRenderObject() as RenderBox?;
                          if (renderBox == null) return;
                          final size = renderBox.size;
                          final dxClamped = details.localPosition.dx.clamp(0.0, size.width);
                          final dyClamped = details.localPosition.dy.clamp(0.0, size.height);
                          final xM = (dxClamped / size.width) * floorPlan.widthMeters;
                          final yM = (dyClamped / size.height) * floorPlan.heightMeters;

                          setState(() {
                            _draggedNodePosition = Offset(xM, yM);
                          });
                        },
                        onPanEnd: (_) {
                          if (_mode == _EditMode.move) {
                            if (_selectedNodeId != null && _draggedNodePosition != null) {
                              final bp = context.read<BuildingProvider>();
                              bp.updateNodePosition(_selectedNodeId!, _draggedNodePosition!.dx, _draggedNodePosition!.dy);
                            }
                            setState(() {
                              _selectedNodeId = null;
                              _draggedNodePosition = null;
                            });
                          }
                        },
                        child: IndoorMapView(
                          building: building,
                          currentFloor: _currentFloor,
                          userPosition: null,
                          route: null,
                          currentStepIndex: 0,
                          selectedNodeId: _selectedNodeId,
                          draggedNodePosition: _draggedNodePosition,
                          editMode: true,
                        ),
                      ),
                    ),
                    _FloorBar(
                      floors: building.floorPlans.map((f) => f.floor).toList(),
                      current: _currentFloor,
                      onChanged: (f) => setState(() => _currentFloor = f),
                    ),
                  ],
                ),
                if (_importing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 14),
                          Text('Importando...', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  void _onMapTap(
      BuildContext context, Offset localPos, dynamic floorPlan) async {
    final bp = context.read<BuildingProvider>();
    final building = bp.selected;
    if (building == null) return;

    // Convert pixel to meter coordinates
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;
    final xM = (localPos.dx / size.width) * floorPlan.widthMeters;
    final yM = (localPos.dy / size.height) * floorPlan.heightMeters;

    switch (_mode) {
      case _EditMode.addNode:
        final label = await _askLabel(context);
        if (label == null) return;
        final node = NavNode(
          id: _uuid.v4(),
          label: label,
          x: xM,
          y: yM,
          floor: _currentFloor,
          nodeTypeStr: _nodeType.name,
          buildingId: building.id,
        );
        await bp.addNode(node);

      case _EditMode.addEdge:
        final tapped = _findNearestNode(building.nodes, xM, yM, _currentFloor);
        if (tapped == null) return;
        if (_selectedNodeId == null) {
          setState(() => _selectedNodeId = tapped.id);
        } else {
          if (_selectedNodeId != tapped.id) {
            final dist = _distance(
                building.nodes.firstWhere((n) => n.id == _selectedNodeId!),
                tapped);
            final edge = NavEdge(
              id: _uuid.v4(),
              fromNodeId: _selectedNodeId!,
              toNodeId: tapped.id,
              weight: dist,
            );
            await bp.addEdge(edge);
          }
          setState(() => _selectedNodeId = null);
        }

      case _EditMode.delete:
        // Toca em um nó para removê-lo
        final toDelete = _findNearestNode(building.nodes, xM, yM, _currentFloor);
        if (toDelete != null) {
          final confirm = await _confirmDelete(context, toDelete.label);
          if (confirm == true) await bp.removeNode(toDelete.id);
        }
        break;

      case _EditMode.move:
      case _EditMode.none:
        break;
    }
  }

  NavNode? _findNearestNode(
      List<NavNode> nodes, double x, double y, int floor) {
    final onFloor = nodes.where((n) => n.floor == floor).toList();
    if (onFloor.isEmpty) return null;
    onFloor.sort((a, b) => _dist2(a, x, y).compareTo(_dist2(b, x, y)));
    final nearest = onFloor.first;
    return _dist2(nearest, x, y) < 64.0 ? nearest : null; // within 8m magnetic radius
  }

  double _dist2(NavNode n, double x, double y) =>
      (n.x - x) * (n.x - x) + (n.y - y) * (n.y - y);

  double _distance(NavNode a, NavNode b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return (dx * dx + dy * dy) > 0
        ? (dx * dx + dy * dy < 1 ? 1 : (dx * dx + dy * dy))
        : 1;
  }

  Future<bool?> _confirmDelete(BuildContext context, String label) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Remover ponto'),
          content: Text('Remover "$label" e todas as suas conexões?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child:
                  const Text('Remover', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

  Future<void> _onMenuAction(BuildContext context, String action) async {
    final bp = context.read<BuildingProvider>();
    final building = bp.selected;
    if (building == null) return;

    switch (action) {
      case 'import_pdf':
        setState(() => _importing = true);
        final result = await _importService.importFloorPlanPdf(
          buildingId: building.id,
          floor: _currentFloor,
        );
        setState(() => _importing = false);
        if (result.success && result.savedImagePath != null) {
          await bp.setFloorPlanImage(
            buildingId: building.id,
            floor: _currentFloor,
            imagePath: result.savedImagePath!,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Planta baixa importada com sucesso!')),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result.error ?? 'Erro ao importar PDF')),
            );
          }
        }

      case 'import_json':
        setState(() => _importing = true);
        final result = await _importService.importBuildingJson();
        setState(() => _importing = false);
        if (result.success && result.building != null) {
          await bp.importBuilding(result.building!);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Prédio "${result.building!.name}" importado!')),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result.error ?? 'Erro ao importar JSON')),
            );
          }
        }

      case 'clear_nodes':
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Limpar nós'),
            content: Text(
                'Remover todos os nós e arestas do andar $_currentFloor?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Limpar',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        if (confirm == true) {
          final floorNodes = building.nodes
              .where((n) => n.floor == _currentFloor)
              .map((n) => n.id)
              .toList();
          for (final nid in floorNodes) {
            await bp.removeNode(nid);
          }
        }
    }
  }

  Future<String?> _askLabel(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nome do ponto'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex: Banheiro, Entrada...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('OK')),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final _EditMode mode;
  final _EditMode current;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.mode,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => IconButton(
        icon: Icon(icon),
        tooltip: label,
        color: current == mode ? Colors.amber : null,
        onPressed: onTap,
      );
}

class _NodeTypeSelector extends StatelessWidget {
  final NodeType selected;
  final ValueChanged<NodeType> onChanged;

  const _NodeTypeSelector({required this.selected, required this.onChanged});

  String _translateNodeType(NodeType t) {
    switch (t) {
      case NodeType.entrance: return 'Entrada';
      case NodeType.exit: return 'Saída';
      case NodeType.bathroom: return 'Banheiro';
      case NodeType.elevator: return 'Elevador';
      case NodeType.stairs: return 'Escada';
      case NodeType.room: return 'Sala';
      case NodeType.corridor: return 'Corredor';
      case NodeType.poi: return 'Ponto de Interesse';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: NodeType.values.map((t) {
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(_translateNodeType(t)),
              selected: selected == t,
              onSelected: (_) => onChanged(t),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FloorBar extends StatelessWidget {
  final List<int> floors;
  final int current;
  final ValueChanged<int> onChanged;

  const _FloorBar(
      {required this.floors, required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
        height: 48,
        color: Theme.of(context).colorScheme.surface,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: floors.map((f) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text('Andar $f'),
                  selected: f == current,
                  onSelected: (_) => onChanged(f),
                ),
              )).toList(),
        ),
      );
}
