import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../data/models/building.dart';
import '../../data/models/nav_node.dart';
import '../../data/models/nav_edge.dart';
import '../../data/models/wifi_fingerprint.dart';
import '../../services/cache_service.dart';
import '../../services/api_service.dart';

class BuildingProvider extends ChangeNotifier {
  final CacheService _cache;
  final ApiService _api;

  List<Building> _buildings = [];
  Building? _selected;
  bool _loading = false;
  String? _error;

  BuildingProvider(this._cache, this._api);

  List<Building> get buildings => _buildings;
  Building? get selected => _selected;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> init() async {
    await _cache.init();
    _buildings = _cache.getAllBuildings();
    notifyListeners();

    // Try to sync from backend (best-effort, non-blocking)
    _syncFromBackend();
  }

  Future<void> _syncFromBackend() async {
    try {
      final remote = await _api.fetchBuildings();
      for (final b in remote) {
        await _cache.saveBuilding(b);
      }
      _buildings = _cache.getAllBuildings();
      notifyListeners();
    } catch (_) {
      // Offline — use cached data
    }
  }

  void selectBuilding(Building b) {
    _selected = b;
    notifyListeners();
  }

  Future<Building> createBuilding({
    required String name,
    required String address,
  }) async {
    final now = DateTime.now();
    final b = Building(
      id: 'bld_${now.millisecondsSinceEpoch}',
      name: name,
      address: address,
      floorPlans: [
        FloorPlan(floor: 0, widthMeters: 50, heightMeters: 30),
      ],
      nodes: [],
      edges: [],
      fingerprints: [],
      lastSynced: now,
    );
    await _cache.saveBuilding(b);
    _buildings.add(b);
    notifyListeners();

    // Feed the backend from the app (non-blocking background sync)
    _api.createBuilding(b.toJson()).catchError((_) => null);

    return b;
  }

  /// Cria um prédio com N andares (para o wizard de setup).
  Future<Building> createBuildingWithFloors({
    required String name,
    required String address,
    required int totalFloors,
  }) async {
    final now = DateTime.now();
    final floors = List.generate(
      totalFloors,
      (i) => FloorPlan(floor: i, widthMeters: 50, heightMeters: 30),
    );
    final b = Building(
      id: 'bld_${now.millisecondsSinceEpoch}',
      name: name,
      address: address,
      floorPlans: floors,
      nodes: [],
      edges: [],
      fingerprints: [],
      lastSynced: now,
    );
    await _cache.saveBuilding(b);
    _buildings.add(b);
    notifyListeners();

    // Feed the backend from the app (non-blocking background sync)
    _api.createBuilding(b.toJson()).catchError((_) => null);

    return b;
  }

  /// Importa um prédio completo vindo de JSON (substitui se ID já existe).
  Future<void> importBuilding(Building building) async {
    await _cache.saveBuilding(building);
    final idx = _buildings.indexWhere((x) => x.id == building.id);
    if (idx >= 0) {
      _buildings[idx] = building;
    } else {
      _buildings.add(building);
    }
    _selected = building;
    notifyListeners();

    // Feed the backend from the app (non-blocking best-effort update/create)
    _api.createBuilding(building.toJson()).then((_) {}).catchError((_) {
      _api.updateBuilding(building.id, building.toJson()).catchError((_) => null);
    });
  }

  /// Associa a imagem de planta baixa (caminho local de PNG) a um andar.
  Future<void> setFloorPlanImage({
    required String buildingId,
    required int floor,
    required String imagePath,
  }) async {
    final b = _buildings.firstWhere(
      (x) => x.id == buildingId,
      orElse: () => _selected!,
    );
    final updatedPlans = b.floorPlans.map((fp) {
      if (fp.floor == floor) {
        return FloorPlan(
          floor: fp.floor,
          imageUrl: imagePath,
          widthMeters: fp.widthMeters,
          heightMeters: fp.heightMeters,
        );
      }
      return fp;
    }).toList();

    final updated = Building(
      id: b.id,
      name: b.name,
      address: b.address,
      floorPlans: updatedPlans,
      nodes: b.nodes,
      edges: b.edges,
      fingerprints: b.fingerprints,
      lastSynced: b.lastSynced,
    );
    await _saveAndSelect(updated);
  }

  /// Remove um nó e todas as arestas que o referenciam.
  Future<void> removeNode(String nodeId) async {
    final b = _selected;
    if (b == null) return;
    final updated = Building(
      id: b.id,
      name: b.name,
      address: b.address,
      floorPlans: b.floorPlans,
      nodes: b.nodes.where((n) => n.id != nodeId).toList(),
      edges: b.edges
          .where((e) => e.fromNodeId != nodeId && e.toNodeId != nodeId)
          .toList(),
      fingerprints: b.fingerprints,
      lastSynced: b.lastSynced,
    );
    await _saveAndSelect(updated);
  }

  /// Atualiza a posição X, Y de um nó existente e recalcula o peso das arestas conectadas.
  Future<void> updateNodePosition(String nodeId, double x, double y) async {
    final b = _selected;
    if (b == null) return;
    final updatedNodes = b.nodes.map((n) {
      if (n.id == nodeId) {
        return NavNode(
          id: n.id,
          label: n.label,
          x: x,
          y: y,
          floor: n.floor,
          nodeTypeStr: n.nodeTypeStr,
          buildingId: n.buildingId,
        );
      }
      return n;
    }).toList();

    // Recalcula o comprimento das arestas conectadas a este nó
    final updatedEdges = b.edges.map((e) {
      if (e.fromNodeId == nodeId || e.toNodeId == nodeId) {
        final fromNode = updatedNodes.firstWhere((n) => n.id == e.fromNodeId);
        final toNode = updatedNodes.firstWhere((n) => n.id == e.toNodeId);
        final dx = fromNode.x - toNode.x;
        final dy = fromNode.y - toNode.y;
        final dist = sqrt(dx * dx + dy * dy);
        return NavEdge(
          id: e.id,
          fromNodeId: e.fromNodeId,
          toNodeId: e.toNodeId,
          weight: dist > 0 ? (dist < 1 ? 1 : dist) : 1,
          accessible: e.accessible,
          bidirectional: e.bidirectional,
        );
      }
      return e;
    }).toList();

    final updated = Building(
      id: b.id,
      name: b.name,
      address: b.address,
      floorPlans: b.floorPlans,
      nodes: updatedNodes,
      edges: updatedEdges,
      fingerprints: b.fingerprints,
      lastSynced: b.lastSynced,
    );
    await _saveAndSelect(updated);
  }

  /// Remove uma aresta pelo ID.
  Future<void> removeEdge(String edgeId) async {
    final b = _selected;
    if (b == null) return;
    final updated = Building(
      id: b.id,
      name: b.name,
      address: b.address,
      floorPlans: b.floorPlans,
      nodes: b.nodes,
      edges: b.edges.where((e) => e.id != edgeId).toList(),
      fingerprints: b.fingerprints,
      lastSynced: b.lastSynced,
    );
    await _saveAndSelect(updated);
  }

  /// Apaga o prédio do cache e da lista.
  Future<void> deleteBuilding(String buildingId) async {
    await _cache.deleteBuilding(buildingId);
    _buildings.removeWhere((b) => b.id == buildingId);
    if (_selected?.id == buildingId) _selected = null;
    notifyListeners();

    // Feed the delete to the backend (non-blocking background sync)
    _api.deleteBuilding(buildingId).catchError((_) => null);
  }

  Future<void> addNode(NavNode node) async {
    final b = _selected;
    if (b == null) return;
    final updated = Building(
      id: b.id,
      name: b.name,
      address: b.address,
      floorPlans: b.floorPlans,
      nodes: [...b.nodes, node],
      edges: b.edges,
      fingerprints: b.fingerprints,
      lastSynced: b.lastSynced,
    );
    await _saveAndSelect(updated);
  }

  Future<void> addEdge(NavEdge edge) async {
    final b = _selected;
    if (b == null) return;
    final updated = Building(
      id: b.id,
      name: b.name,
      address: b.address,
      floorPlans: b.floorPlans,
      nodes: b.nodes,
      edges: [...b.edges, edge],
      fingerprints: b.fingerprints,
      lastSynced: b.lastSynced,
    );
    await _saveAndSelect(updated);
  }

  Future<void> addFingerprint(WifiFingerprint fp) async {
    final b = _selected;
    if (b == null) return;
    final updated = Building(
      id: b.id,
      name: b.name,
      address: b.address,
      floorPlans: b.floorPlans,
      nodes: b.nodes,
      edges: b.edges,
      fingerprints: [...b.fingerprints, fp],
      lastSynced: b.lastSynced,
    );
    await _saveAndSelect(updated);

    // Upload to backend (non-blocking best-effort background sync)
    _api.uploadFingerprint(fp).catchError((_) => null);
  }

  Future<void> _saveAndSelect(Building b) async {
    await _cache.saveBuilding(b);
    _selected = b;
    final idx = _buildings.indexWhere((x) => x.id == b.id);
    if (idx >= 0) {
      _buildings[idx] = b;
    } else {
      _buildings.add(b);
    }
    notifyListeners();

    // Feed the backend from the app with the updated data (non-blocking background sync)
    _api.updateBuilding(b.id, b.toJson()).catchError((_) => null);
  }
}
