import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/building_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/positioning_provider.dart';
import '../../widgets/indoor_map_painter.dart';
import '../../widgets/voice_command_widget.dart';

class NavigationScreen extends StatefulWidget {
  final String buildingId;
  const NavigationScreen({super.key, required this.buildingId});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _init() {
    final bp = context.read<BuildingProvider>();
    final pp = context.read<PositioningProvider>();
    final np = context.read<NavigationProvider>();
    final b = bp.selected;
    if (b == null) return;
    pp.setBuilding(b);
    np.setBuilding(b);
    pp.startPositioning();
  }

  @override
  void dispose() {
    context.read<PositioningProvider>().stopPositioning();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BuildingProvider>();
    final pp = context.watch<PositioningProvider>();
    final np = context.watch<NavigationProvider>();
    final building = bp.selected;

    // Forward position updates to navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pos = pp.position;
      if (pos != null) np.onPositionUpdate(pos);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(building?.name ?? 'Navegação'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Voltar ao início',
          ),
          if (np.state != NavigationState.idle)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: np.cancelNavigation,
              tooltip: 'Cancelar rota',
            ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          _StatusBar(np: np, pp: pp),

          // Map view
          Expanded(
            child: building == null
                ? const Center(child: Text('Prédio não encontrado'))
                : IndoorMapView(
                    building: building,
                    currentFloor: pp.currentFloor,
                    userPosition: pp.position,
                    route: np.route,
                    currentStepIndex: np.currentStepIndex,
                  ),
          ),

          // Floor selector
          if (building != null)
            _FloorSelector(
              floors: building.floorPlans.map((f) => f.floor).toList(),
              currentFloor: pp.currentFloor,
              onFloorChanged: pp.setFloor,
            ),
        ],
      ),

      // Voice command FAB
      floatingActionButton: VoiceCommandFab(
        isListening: np.isListening,
        onTap: np.startVoiceCommand,
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final NavigationProvider np;
  final PositioningProvider pp;

  const _StatusBar({required this.np, required this.pp});

  @override
  Widget build(BuildContext context) {
    final pos = pp.position;
    final step = np.currentStep;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (step != null) ...[
            Text(step.instruction,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
          ] else if (np.statusMessage != null)
            Text(np.statusMessage!,
                style: const TextStyle(fontStyle: FontStyle.italic)),
          if (pos != null)
            Text(
              'Posição: (${pos.x.toStringAsFixed(1)}m, ${pos.y.toStringAsFixed(1)}m)  '
              'Confiança: ${(pos.confidence * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
    );
  }
}

class _FloorSelector extends StatelessWidget {
  final List<int> floors;
  final int currentFloor;
  final ValueChanged<int> onFloorChanged;

  const _FloorSelector({
    required this.floors,
    required this.currentFloor,
    required this.onFloorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: floors.map((f) {
          final selected = f == currentFloor;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text('Andar $f'),
              selected: selected,
              onSelected: (_) => onFloorChanged(f),
            ),
          );
        }).toList(),
      ),
    );
  }
}
