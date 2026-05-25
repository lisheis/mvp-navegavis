import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/building_provider.dart';
import '../../providers/app_mode_provider.dart';
import '../../../core/constants/app_mode.dart';
import '../../../data/models/building.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AppModeProvider>().load();
      await context.read<BuildingProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BuildingProvider>();
    final amp = context.watch<AppModeProvider>();
    final isAdmin = amp.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NavegaVis'),
        actions: [
          // Botão de troca de modo (Admin / Usuário)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _ModeSwitcher(isAdmin: isAdmin, onToggle: amp.toggle),
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner de modo
          _ModeBanner(isAdmin: isAdmin),

          // Lista de prédios
          Expanded(
            child: bp.loading
                ? const Center(child: CircularProgressIndicator())
                : bp.buildings.isEmpty
                    ? _emptyState(context, isAdmin)
                    : _buildingList(context, bp.buildings, isAdmin),
          ),
        ],
      ),

      // FAB: só em modo admin
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/setup'),
              icon: const Icon(Icons.add_business),
              label: const Text('Cadastrar prédio'),
            )
          : null,
    );
  }

  // ── Empty state ────────────────────────────────────────────────────────────

  Widget _emptyState(BuildContext context, bool isAdmin) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isAdmin ? Icons.add_business : Icons.map_outlined,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                isAdmin
                    ? 'Nenhum prédio cadastrado'
                    : 'Nenhum prédio disponível',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isAdmin
                    ? 'Cadastre o primeiro prédio para começar.'
                    : 'Peça ao administrador para cadastrar um prédio.',
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              if (isAdmin) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.go('/setup'),
                  icon: const Icon(Icons.add),
                  label: const Text('Cadastrar prédio'),
                ),
              ],
            ],
          ),
        ),
      );

  // ── Building list ──────────────────────────────────────────────────────────

  Widget _buildingList(
      BuildContext context, List<Building> buildings, bool isAdmin) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: buildings.length,
      itemBuilder: (ctx, i) {
        final b = buildings[i];
        return _BuildingCard(
          building: b,
          isAdmin: isAdmin,
          onNavigate: () {
            context.read<BuildingProvider>().selectBuilding(b);
            context.go('/navigate/${b.id}');
          },
          onEditMap: () {
            context.read<BuildingProvider>().selectBuilding(b);
            context.go('/map/${b.id}');
          },
          onTrain: () {
            context.read<BuildingProvider>().selectBuilding(b);
            context.go('/training/${b.id}');
          },
          onSetup: () {
            context.read<BuildingProvider>().selectBuilding(b);
            context.go('/setup?id=${b.id}');
          },
          onDelete: () => _confirmDelete(context, b),
        );
      },
    );
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(BuildContext context, Building b) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir prédio'),
        content: Text(
            'Tem certeza que deseja excluir "${b.name}"?\nTodos os dados serão perdidos.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<BuildingProvider>().deleteBuilding(b.id);
    }
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _ModeSwitcher extends StatelessWidget {
  final bool isAdmin;
  final VoidCallback onToggle;

  const _ModeSwitcher({required this.isAdmin, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isAdmin
              ? Colors.orange.withOpacity(0.2)
              : Colors.blue.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isAdmin ? Colors.orange : Colors.blue,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAdmin ? Icons.admin_panel_settings : Icons.person,
              size: 16,
              color: isAdmin ? Colors.orange : Colors.blue,
            ),
            const SizedBox(width: 5),
            Text(
              isAdmin ? 'Admin' : 'Usuário',
              style: TextStyle(
                color: isAdmin ? Colors.orange : Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeBanner extends StatelessWidget {
  final bool isAdmin;

  const _ModeBanner({required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isAdmin
          ? Colors.orange.withOpacity(0.1)
          : Colors.blue.withOpacity(0.08),
      child: Row(
        children: [
          Icon(
            isAdmin ? Icons.admin_panel_settings : Icons.navigation,
            size: 18,
            color: isAdmin ? Colors.orange : Colors.blue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isAdmin
                  ? 'Modo Administrador — cadastre prédios, edite mapas e treine Wi-Fi.'
                  : 'Modo Usuário — selecione um prédio para navegar.',
              style: TextStyle(
                color: isAdmin ? Colors.orange : Colors.blue,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BuildingCard extends StatelessWidget {
  final Building building;
  final bool isAdmin;
  final VoidCallback onNavigate;
  final VoidCallback onEditMap;
  final VoidCallback onTrain;
  final VoidCallback onSetup;
  final VoidCallback onDelete;

  const _BuildingCard({
    required this.building,
    required this.isAdmin,
    required this.onNavigate,
    required this.onEditMap,
    required this.onTrain,
    required this.onSetup,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final nodeCount = building.nodes.length;
    final fpCount = building.fingerprints.length;
    final floorCount = building.floorPlans.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: const Icon(Icons.business),
            ),
            title: Text(
              building.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: building.address.isNotEmpty
                ? Text(building.address)
                : null,
            // Menu admin
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'setup':
                    onSetup();
                  case 'map':
                    onEditMap();
                  case 'train':
                    onTrain();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (_) => [
                if (isAdmin) ...[
                  const PopupMenuItem(
                      value: 'setup',
                      child: ListTile(
                          leading: Icon(Icons.settings),
                          title: Text('Configurar'),
                          dense: true)),
                  const PopupMenuItem(
                      value: 'map',
                      child: ListTile(
                          leading: Icon(Icons.map),
                          title: Text('Editar mapa'),
                          dense: true)),
                  const PopupMenuItem(
                      value: 'train',
                      child: ListTile(
                          leading: Icon(Icons.wifi),
                          title: Text('Treinar Wi-Fi'),
                          dense: true)),
                  const PopupMenuDivider(),
                ],
                const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                        leading: Icon(Icons.delete, color: Colors.red),
                        title: Text('Excluir mapa',
                            style: TextStyle(color: Colors.red)),
                        dense: true)),
              ],
            ),
          ),

          // Stats row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _stat(Icons.layers, '$floorCount andar(es)'),
                const SizedBox(width: 16),
                _stat(Icons.location_on, '$nodeCount pontos'),
                const SizedBox(width: 16),
                _stat(Icons.wifi, '$fpCount amostras'),
              ],
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                if (isAdmin) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEditMap,
                      icon: const Icon(Icons.edit_location_alt, size: 16),
                      label: const Text('Mapa'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onTrain,
                      icon: const Icon(Icons.wifi_find, size: 16),
                      label: const Text('Wi-Fi'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  flex: isAdmin ? 1 : 3,
                  child: ElevatedButton.icon(
                    onPressed: onNavigate,
                    icon: const Icon(Icons.navigation, size: 16),
                    label: const Text('Navegar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );
}
