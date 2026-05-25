import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/models/building.dart';

const _kBuildingsBox = 'buildings_cache';

/// Local cache for building data (maps, graphs, fingerprints).
/// Uses Hive for fast, offline-capable JSON storage.
class CacheService {
  late Box<String> _box;
  bool _initialized = false;
  Future<void>? _initFuture;

  Future<void> init() async {
    if (_initialized) return;
    _initFuture ??= _doInit();
    return _initFuture;
  }

  Future<void> _doInit() async {
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_kBuildingsBox);
    _initialized = true;
  }

  Future<void> saveBuilding(Building building) async {
    await _box.put(building.id, jsonEncode(building.toJson()));
  }

  Building? getBuilding(String id) {
    final raw = _box.get(id);
    if (raw == null) return null;
    return Building.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  List<Building> getAllBuildings() {
    return _box.values
        .map((raw) =>
            Building.fromJson(jsonDecode(raw) as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteBuilding(String id) => _box.delete(id);

  Future<void> clearAll() => _box.clear();
}
