import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../data/models/building.dart';
import '../../../data/models/nav_node.dart';
import '../../../data/models/nav_edge.dart';
import '../../providers/building_provider.dart';
import '../../../services/import_service.dart';

/// Wizard de 4 passos para cadastrar ou configurar um prédio.
///
/// Passo 1 — Informações básicas (nome, endereço, andares)
/// Passo 2 — Importar planta baixa (PDF ou JSON)
/// Passo 3 — Configurar andares (dimensões)
/// Passo 4 — Conclusão e atalhos
class BuildingSetupScreen extends StatefulWidget {
  /// null = novo prédio; não-null = editar prédio existente
  final String? buildingId;

  const BuildingSetupScreen({super.key, this.buildingId});

  @override
  State<BuildingSetupScreen> createState() => _BuildingSetupScreenState();
}

class _BuildingSetupScreenState extends State<BuildingSetupScreen> {
  final _importService = ImportService();
  int _step = 0;
  bool _busy = false;
  String? _feedbackMsg;

  // Passo 1
  final _nameCtrl = TextEditingController();
  final _addrCtrl = TextEditingController();
  int _totalFloors = 1;

  // Passo 2 — planta por andar
  // andar → caminho local da imagem (PNG gerada do PDF)
  final Map<int, String> _floorImagePaths = {};
  // se importou JSON completo, guarda o building
  Building? _importedBuilding;

  // Prédio criado ao finalizar o passo 1
  Building? _createdBuilding;

  @override
  void initState() {
    super.initState();
    // Edição: pré-preencher com dados existentes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.buildingId != null) {
        final b = context.read<BuildingProvider>().selected;
        if (b != null) {
          _nameCtrl.text = b.name;
          _addrCtrl.text = b.address;
          _totalFloors = b.floorPlans.length;
          _createdBuilding = b;
          for (final fp in b.floorPlans) {
            if (fp.imageUrl != null && fp.imageUrl!.isNotEmpty) {
              _floorImagePaths[fp.floor] = fp.imageUrl!;
            }
          }
          setState(() {});
        }
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addrCtrl.dispose();
    super.dispose();
  }

  // ── Steps ─────────────────────────────────────────────────────────────────

  Widget _buildStep1() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _sectionTitle('Informações do prédio'),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nome do prédio *',
              prefixIcon: Icon(Icons.business),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _addrCtrl,
            decoration: const InputDecoration(
              labelText: 'Endereço',
              prefixIcon: Icon(Icons.location_on),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle('Número de andares'),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed:
                    _totalFloors > 1 ? () => setState(() => _totalFloors--) : null,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$_totalFloors ${_totalFloors == 1 ? 'andar' : 'andares'}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _totalFloors < 20 ? () => setState(() => _totalFloors++) : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Andar 0 = térreo. Andares negativos para subsolos.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      );

  Widget _buildStep2() {
    final floors = List.generate(_totalFloors, (i) => i);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionTitle('Importar planta baixa'),
        const SizedBox(height: 4),
        const Text(
          'Selecione um PDF para cada andar, ou importe um JSON completo do prédio.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),

        // JSON import card
        Card(
          child: ListTile(
            leading: const Icon(Icons.data_object, color: Colors.amber),
            title: const Text('Importar JSON do prédio'),
            subtitle: const Text('Carrega nós, arestas e plantas de uma vez'),
            trailing: const Icon(Icons.upload_file),
            onTap: _importedBuilding != null ? null : _onImportJson,
          ),
        ),

        if (_importedBuilding != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: _successChip('JSON importado: ${_importedBuilding!.name}'),
          ),

        const Divider(height: 32),
        const Text('— ou importe PDF por andar —',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 16),

        ...floors.map((floor) {
          final hasImage = _floorImagePaths.containsKey(floor);
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: hasImage ? Colors.green : Colors.grey,
                child: Text('$floor',
                    style: const TextStyle(color: Colors.white)),
              ),
              title: Text('Andar $floor'),
              subtitle: hasImage
                  ? Text(
                      _floorImagePaths[floor]!.split('/').last,
                      overflow: TextOverflow.ellipsis,
                    )
                  : const Text('Sem planta importada'),
              trailing: hasImage
                  ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () =>
                          setState(() => _floorImagePaths.remove(floor)),
                    )
                  : IconButton(
                      icon: const Icon(Icons.picture_as_pdf),
                      onPressed: () => _onImportPdf(floor),
                    ),
            ),
          );
        }),

        const SizedBox(height: 8),
        const Text(
          'Você pode pular esta etapa e adicionar as plantas depois.',
          style: TextStyle(color: Colors.grey, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStep3() {
    final bp = context.read<BuildingProvider>();
    final b = _createdBuilding ?? bp.selected;
    final floors = List.generate(_totalFloors, (i) => i);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionTitle('Dimensões dos andares'),
        const SizedBox(height: 4),
        const Text(
          'Informe as dimensões reais (em metros) de cada andar. '
          'Isso calibra as coordenadas dos nós no mapa.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),
        ...floors.map((floor) {
          final existing = b?.floorPlans.firstWhere(
            (f) => f.floor == floor,
            orElse: () => FloorPlan(floor: floor, widthMeters: 50, heightMeters: 30),
          );
          return _FloorDimensionCard(
            floor: floor,
            initialWidth: existing?.widthMeters ?? 50,
            initialHeight: existing?.heightMeters ?? 30,
            imagePath: _floorImagePaths[floor],
            onChanged: (w, h) {
              // Will be applied when saving in step 4
            },
          );
        }),
      ],
    );
  }

  Widget _buildStep4() {
    final b = _createdBuilding;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 72),
        const SizedBox(height: 16),
        const Text(
          'Prédio configurado!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          b != null ? b.name : _nameCtrl.text,
          style: const TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        const Text('Próximos passos:',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _nextStepTile(
          icon: Icons.add_location_alt,
          color: Colors.blue,
          title: 'Editar mapa',
          subtitle: 'Adicionar nós e arestas no grafo indoor',
          onTap: () {
            if (b != null) {
              context.read<BuildingProvider>().selectBuilding(b);
              context.go('/map/${b.id}');
            }
          },
        ),
        const SizedBox(height: 10),
        _nextStepTile(
          icon: Icons.wifi,
          color: Colors.orange,
          title: 'Treinar Wi-Fi',
          subtitle: 'Coletar fingerprints por posição',
          onTap: () {
            if (b != null) {
              context.read<BuildingProvider>().selectBuilding(b);
              context.go('/training/${b.id}');
            }
          },
        ),
        const SizedBox(height: 10),
        _nextStepTile(
          icon: Icons.navigation,
          color: Colors.green,
          title: 'Navegar agora',
          subtitle: 'Testar o sistema de navegação por voz',
          onTap: () {
            if (b != null) {
              context.read<BuildingProvider>().selectBuilding(b);
              context.go('/navigate/${b.id}');
            }
          },
        ),
      ],
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _onImportJson() async {
    setState(() { _busy = true; _feedbackMsg = null; });
    final result = await _importService.importBuildingJson();
    setState(() => _busy = false);

    if (!result.success || result.building == null) {
      setState(() => _feedbackMsg = result.error);
      return;
    }

    // Save the imported building to cache
    await context.read<BuildingProvider>().importBuilding(result.building!);
    setState(() {
      _importedBuilding = result.building;
      _createdBuilding = result.building;
      _nameCtrl.text = result.building!.name;
      _addrCtrl.text = result.building!.address;
      _totalFloors = result.building!.floorPlans.length;
    });
  }

  Future<void> _onImportPdf(int floor) async {
    final b = _createdBuilding ?? await _ensureBuildingExists();
    if (b == null) {
      setState(() => _feedbackMsg = 'Salve as informações do prédio primeiro.');
      return;
    }

    setState(() { _busy = true; _feedbackMsg = null; });
    final result = await _importService.importFloorPlanPdf(
      buildingId: b.id,
      floor: floor,
    );
    setState(() => _busy = false);

    if (!result.success || result.savedImagePath == null) {
      setState(() => _feedbackMsg = result.error);
      return;
    }

    // Persist image path in building's FloorPlan
    await context.read<BuildingProvider>().setFloorPlanImage(
      buildingId: b.id,
      floor: floor,
      imagePath: result.savedImagePath!,
    );

    setState(() => _floorImagePaths[floor] = result.savedImagePath!);
  }

  Future<Building?> _ensureBuildingExists() async {
    if (_nameCtrl.text.trim().isEmpty) return null;
    final b = await context.read<BuildingProvider>().createBuildingWithFloors(
      name: _nameCtrl.text.trim(),
      address: _addrCtrl.text.trim(),
      totalFloors: _totalFloors,
    );
    setState(() => _createdBuilding = b);
    return b;
  }

  Future<void> _onNext() async {
    setState(() => _feedbackMsg = null);

    if (_step == 0) {
      if (_nameCtrl.text.trim().isEmpty) {
        setState(() => _feedbackMsg = 'Informe o nome do prédio.');
        return;
      }
      // Create the building so PDF import has a buildingId
      if (_createdBuilding == null && _importedBuilding == null) {
        setState(() => _busy = true);
        try {
          final b = await context.read<BuildingProvider>().createBuildingWithFloors(
            name: _nameCtrl.text.trim(),
            address: _addrCtrl.text.trim(),
            totalFloors: _totalFloors,
          );
          setState(() { _createdBuilding = b; });
        } catch (e) {
          setState(() => _feedbackMsg = 'Erro ao cadastrar prédio localmente: $e');
          return;
        } finally {
          setState(() => _busy = false);
        }
      }
    }

    setState(() => _step++);
  }

  void _onBack() => setState(() => _step--);

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      );

  Widget _successChip(String label) => Chip(
        avatar: const Icon(Icons.check, size: 16, color: Colors.white),
        label: Text(label, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      );

  Widget _nextStepTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color,
            child: Icon(icon, color: Colors.white),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: onTap,
        ),
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final steps = [
      'Informações',
      'Planta baixa',
      'Dimensões',
      'Concluído',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.buildingId == null ? 'Cadastrar prédio' : 'Configurar prédio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () => context.go('/'),
            tooltip: 'Voltar ao início',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_step + 1) / steps.length,
            backgroundColor: Colors.white24,
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Step labels
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: steps.asMap().entries.map((e) {
                    final active = e.key == _step;
                    final done = e.key < _step;
                    return _StepLabel(
                      label: e.value,
                      index: e.key + 1,
                      active: active,
                      done: done,
                    );
                  }).toList(),
                ),
              ),

              // Feedback message
              if (_feedbackMsg != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.4)),
                  ),
                  child: Text(_feedbackMsg!,
                      style: const TextStyle(color: Colors.red)),
                ),

              // Step content
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: [
                      _buildStep1(),
                      _buildStep2(),
                      _buildStep3(),
                      _buildStep4(),
                    ][_step],
                  ),
                ),
              ),
            ],
          ),

          // Busy overlay
          if (_busy)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
      bottomNavigationBar: _step < 3
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    if (_step > 0)
                      OutlinedButton(
                        onPressed: _onBack,
                        child: const Text('Voltar'),
                      ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _busy ? null : _onNext,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(_step == 2 ? 'Finalizar' : 'Próximo'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Voltar ao início'),
                  ),
                ),
              ),
            ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _StepLabel extends StatelessWidget {
  final String label;
  final int index;
  final bool active;
  final bool done;

  const _StepLabel({
    required this.label,
    required this.index,
    required this.active,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final color = done
        ? Colors.green
        : active
            ? Theme.of(context).colorScheme.primary
            : Colors.grey;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: color,
          child: done
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text('$index',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
        const SizedBox(height: 3),
        Text(label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            )),
      ],
    );
  }
}

class _FloorDimensionCard extends StatefulWidget {
  final int floor;
  final double initialWidth;
  final double initialHeight;
  final String? imagePath;
  final void Function(double w, double h) onChanged;

  const _FloorDimensionCard({
    required this.floor,
    required this.initialWidth,
    required this.initialHeight,
    required this.onChanged,
    this.imagePath,
  });

  @override
  State<_FloorDimensionCard> createState() => _FloorDimensionCardState();
}

class _FloorDimensionCardState extends State<_FloorDimensionCard> {
  late final TextEditingController _wCtrl;
  late final TextEditingController _hCtrl;

  @override
  void initState() {
    super.initState();
    _wCtrl = TextEditingController(text: widget.initialWidth.toStringAsFixed(0));
    _hCtrl = TextEditingController(text: widget.initialHeight.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _wCtrl.dispose();
    _hCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (widget.imagePath != null &&
                    File(widget.imagePath!).existsSync())
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      File(widget.imagePath!),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                if (widget.imagePath != null &&
                    File(widget.imagePath!).existsSync())
                  const SizedBox(width: 12),
                Text('Andar ${widget.floor}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _wCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Largura (m)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => _notify(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _hCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Altura (m)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => _notify(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _notify() {
    final w = double.tryParse(_wCtrl.text) ?? widget.initialWidth;
    final h = double.tryParse(_hCtrl.text) ?? widget.initialHeight;
    widget.onChanged(w, h);
  }
}
