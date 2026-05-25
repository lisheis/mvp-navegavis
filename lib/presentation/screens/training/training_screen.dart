import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../providers/building_provider.dart';
import '../../../data/models/nav_node.dart';
import '../../../data/models/wifi_fingerprint.dart';
import '../../../services/wifi_service.dart';

/// Wi-Fi fingerprint training screen.
/// The user walks to a known node, selects it, presses "Coletar" and
/// the app scans the surrounding APs to record a fingerprint at that location.
class TrainingScreen extends StatefulWidget {
  final String buildingId;
  const TrainingScreen({super.key, required this.buildingId});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  final _scanner = WifiScanService();
  final _uuid = const Uuid();

  NavNode? _selectedNode;
  bool _scanning = false;
  String _status = 'Selecione um nó e colete o sinal Wi-Fi naquela posição.';
  int _samplesCollected = 0;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BuildingProvider>();
    final building = bp.selected;

    return Scaffold(
      appBar: AppBar(
        title: Text('Treinamento Wi-Fi — ${building?.name ?? ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Voltar ao início',
            onPressed: () => context.go('/'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('$_samplesCollected amostras',
                  style: const TextStyle(fontSize: 13)),
            ),
          )
        ],
      ),
      body: building == null
          ? const Center(child: Text('Prédio não encontrado'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Instructions
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_status,
                          style: const TextStyle(fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Node selector
                  const Text('Selecionar ponto no mapa:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: building.nodes.length,
                      itemBuilder: (ctx, i) {
                        final node = building.nodes[i];
                        final selected = node.id == _selectedNode?.id;
                        return ListTile(
                          leading: Icon(
                            selected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          title: Text(node.label),
                          subtitle: Text('Andar ${node.floor} — ${node.nodeTypeStr}'),
                          onTap: () => setState(() => _selectedNode = node),
                          selected: selected,
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Collect button
                  ElevatedButton.icon(
                    onPressed: _scanning || _selectedNode == null
                        ? null
                        : () => _collectSample(context),
                    icon: _scanning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.wifi),
                    label: Text(_scanning ? 'Coletando...' : 'Coletar amostra Wi-Fi'),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _collectSample(BuildContext context) async {
    if (_selectedNode == null) return;

    final hasPermission = await _scanner.checkPermissions();
    if (!hasPermission) {
      setState(() => _status = 'Permissão de Wi-Fi negada.');
      return;
    }

    setState(() {
      _scanning = true;
      _status = 'Escaneando redes Wi-Fi...';
    });

    // Collect 3 scans and merge readings for robustness
    final allReadings = <ApReading>[];
    for (int i = 0; i < 3; i++) {
      final readings = await _scanner.scanOnce();
      allReadings.addAll(readings);
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (allReadings.isEmpty) {
      setState(() {
        _scanning = false;
        _status = 'Nenhuma rede encontrada. Verifique o Wi-Fi do dispositivo.';
      });
      return;
    }

    final fp = WifiFingerprint(
      id: _uuid.v4(),
      nodeId: _selectedNode!.id,
      buildingId: context.read<BuildingProvider>().selected!.id,
      floor: _selectedNode!.floor,
      readings: allReadings,
      collectedAt: DateTime.now(),
    );

    await context.read<BuildingProvider>().addFingerprint(fp);
    _samplesCollected++;

    setState(() {
      _scanning = false;
      _status =
          'Amostra coletada para "${_selectedNode!.label}" (${allReadings.length} APs detectados). '
          'Total: $_samplesCollected amostras.';
    });
  }
}
