import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/models/building.dart';
import '../../data/models/position.dart';
import '../../data/models/wifi_fingerprint.dart';
import '../../domain/algorithms/wifi_positioning.dart';
import '../../domain/algorithms/map_matching.dart';
import '../../services/wifi_service.dart';

class PositioningProvider extends ChangeNotifier {
  final WifiScanService _scanner;
  final WifiPositioningEngine _engine = WifiPositioningEngine(k: 3);
  final MapMatcher _mapMatcher = MapMatcher();

  Building? _building;
  int _currentFloor = 0;
  IndoorPosition? _position;
  bool _active = false;
  StreamSubscription<List<ApReading>>? _sub;

  PositioningProvider(this._scanner);

  IndoorPosition? get position => _position;
  bool get isActive => _active;
  int get currentFloor => _currentFloor;

  void setBuilding(Building building) {
    _building = building;
    _engine.reset();
    notifyListeners();
  }

  void setFloor(int floor) {
    _currentFloor = floor;
    notifyListeners();
  }

  Future<void> startPositioning() async {
    if (_active) return;
    _active = true;

    await _scanner.startScanning(intervalMs: 2000);
    _sub = _scanner.scanStream.listen(_onScan);
    notifyListeners();
  }

  void stopPositioning() {
    _sub?.cancel();
    _scanner.stopScanning();
    _active = false;
    notifyListeners();
  }

  void _onScan(List<ApReading> readings) {
    final b = _building;
    if (b == null) return;

    final rssiMap = {for (final r in readings) r.bssid: r.rssi.toDouble()};

    var pos = _engine.estimate(
      rawRssiScan: rssiMap,
      fingerprints: b.fingerprints,
      nodes: b.nodes,
      currentFloor: _currentFloor,
    );

    // Map matching — snap to graph
    pos = _mapMatcher.snap(
      position: pos,
      nodes: b.nodes,
      edges: b.edges,
      maxSnapDistanceMeters: 5.0,
    );

    _position = pos;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPositioning();
    super.dispose();
  }
}
