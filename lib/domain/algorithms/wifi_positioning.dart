import 'dart:math';
import '../../data/models/wifi_fingerprint.dart';
import '../../data/models/nav_node.dart';
import '../../data/models/position.dart';
import 'kalman_filter.dart';
import 'moving_average.dart';

/// Score between a live scan and a stored fingerprint.
/// Lower = better match.
double _euclideanDistance(
  Map<String, double> live,
  Map<String, double> stored,
) {
  final allBssids = {...live.keys, ...stored.keys};
  double sum = 0;
  for (final bssid in allBssids) {
    // Missing AP treated as -100 dBm (very weak / absent)
    final l = live[bssid] ?? -100;
    final s = stored[bssid] ?? -100;
    sum += pow(l - s, 2);
  }
  return sqrt(sum);
}

/// WiFi fingerprint-based indoor positioning engine.
///
/// Pipeline per update cycle:
///   raw RSSI scan
///   → Kalman smoothing (per BSSID)
///   → Moving average smoothing (per BSSID)
///   → kNN fingerprint matching
///   → weighted centroid position
///   → 2-D Kalman on (x,y)
///   → position smoother (anti-teleport)
class WifiPositioningEngine {
  final RssiKalmanBank _kalmanBank = RssiKalmanBank();
  final RssiMovingAverageBank _maBank = RssiMovingAverageBank(windowSize: 4);
  final KalmanFilter2D _positionKalman = KalmanFilter2D(
    processNoise: 0.01,
    measurementNoise: 1.5,
  );
  final PositionSmoother _smoother = PositionSmoother(alpha: 0.3);

  bool _initialized = false;

  /// kNN parameter — number of nearest fingerprints to use for centroid
  final int k;

  WifiPositioningEngine({this.k = 3});

  /// Given a live RSSI scan and the building's fingerprint database + nodes,
  /// returns an estimated [IndoorPosition].
  IndoorPosition estimate({
    required Map<String, double> rawRssiScan, // bssid → rssi(dBm)
    required List<WifiFingerprint> fingerprints,
    required List<NavNode> nodes,
    required int currentFloor,
  }) {
    if (fingerprints.isEmpty || rawRssiScan.isEmpty) {
      return const IndoorPosition(x: 0, y: 0, floor: 0, confidence: 0);
    }

    // Stage 1 – per-BSSID Kalman smoothing
    final kalmanSmoothed = _kalmanBank.smoothAll(rawRssiScan);

    // Stage 2 – moving average smoothing
    final smoothed = _maBank.smoothAll(kalmanSmoothed);

    // Stage 3 – kNN fingerprint matching
    final floorFingerprints =
        fingerprints.where((f) => f.floor == currentFloor).toList();

    if (floorFingerprints.isEmpty) {
      return IndoorPosition(x: 0, y: 0, floor: currentFloor, confidence: 0);
    }

    // Build stored fingerprint maps: nodeId → avg RSSI per BSSID
    final nodeVectors = <String, Map<String, double>>{};
    for (final fp in floorFingerprints) {
      final allBssids = fp.readings.map((r) => r.bssid).toSet();
      nodeVectors[fp.nodeId] = {
        for (final bssid in allBssids)
          bssid: fp.avgRssiFor(bssid)?.toDouble() ?? -100,
      };
    }

    // Compute distance from live scan to each stored fingerprint
    final distances = nodeVectors.entries.map((e) {
      return (nodeId: e.key, dist: _euclideanDistance(smoothed, e.value));
    }).toList()
      ..sort((a, b) => a.dist.compareTo(b.dist));

    final kNearest = distances.take(k).toList();
    if (kNearest.isEmpty) {
      return IndoorPosition(x: 0, y: 0, floor: currentFloor, confidence: 0);
    }

    // Stage 4 – weighted centroid (inverse-distance weighting)
    double totalWeight = 0;
    double wx = 0, wy = 0;
    for (final match in kNearest) {
      final node = nodes.firstWhere(
        (n) => n.id == match.nodeId,
        orElse: () => nodes.first,
      );
      // avoid division by zero
      final weight = 1.0 / (match.dist + 1e-6);
      wx += node.x * weight;
      wy += node.y * weight;
      totalWeight += weight;
    }
    final rawX = wx / totalWeight;
    final rawY = wy / totalWeight;

    // Stage 5 – 2-D Kalman on position
    if (!_initialized) {
      _positionKalman.reset(rawX, rawY);
      _smoother.reset(rawX, rawY);
      _initialized = true;
    }
    final (kx, ky) = _positionKalman.update(rawX, rawY);

    // Stage 6 – anti-teleport smoother
    final (sx, sy) = _smoother.update(kx, ky);

    // Confidence = 1 − normalized distance of best match
    // A perfect match = 0 dB distance → confidence 1.0
    final bestDist = kNearest.first.dist;
    final confidence = (1.0 - (bestDist / 200.0)).clamp(0.0, 1.0);

    final nearestNodeId = kNearest.first.nodeId;

    return IndoorPosition(
      x: sx,
      y: sy,
      floor: currentFloor,
      confidence: confidence,
      nearestNodeId: nearestNodeId,
    );
  }

  void reset() {
    _kalmanBank.clear();
    _maBank.clear();
    _initialized = false;
  }
}

/// Converts a list of [ApReading] from a live scan into bssid→rssi map.
Map<String, double> apReadingsToMap(List<ApReading> readings) => {
      for (final r in readings) r.bssid: r.rssi.toDouble(),
    };
