import 'dart:collection';

/// Simple sliding-window moving average for a scalar signal.
class MovingAverage {
  final int windowSize;
  final Queue<double> _buffer = Queue();
  double _sum = 0;

  MovingAverage({this.windowSize = 5});

  double update(double value) {
    _buffer.addLast(value);
    _sum += value;
    if (_buffer.length > windowSize) {
      _sum -= _buffer.removeFirst();
    }
    return _sum / _buffer.length;
  }

  double get current => _buffer.isEmpty ? 0.0 : _sum / _buffer.length;

  void reset() {
    _buffer.clear();
    _sum = 0;
  }
}

/// Sliding-window moving average per BSSID (same role as RssiKalmanBank
/// but simpler — used as second-stage smoother after Kalman).
class RssiMovingAverageBank {
  final int windowSize;
  final Map<String, MovingAverage> _averages = {};

  RssiMovingAverageBank({this.windowSize = 4});

  double smooth(String bssid, double rssi) {
    _averages.putIfAbsent(bssid, () => MovingAverage(windowSize: windowSize));
    return _averages[bssid]!.update(rssi);
  }

  Map<String, double> smoothAll(Map<String, double> readings) => {
        for (final e in readings.entries) e.key: smooth(e.key, e.value),
      };

  void clear() => _averages.clear();
}

/// Position buffer that prevents "teleport" by blending new position
/// with a weighted history. More aggressive than simple moving average.
class PositionSmoother {
  double _x;
  double _y;
  final double alpha; // 0..1 — weight of new measurement (lower = smoother)

  PositionSmoother({
    double initialX = 0,
    double initialY = 0,
    this.alpha = 0.25,
  })  : _x = initialX,
        _y = initialY;

  (double x, double y) get position => (_x, _y);

  (double, double) update(double newX, double newY) {
    _x = alpha * newX + (1 - alpha) * _x;
    _y = alpha * newY + (1 - alpha) * _y;
    return (_x, _y);
  }

  void reset(double x, double y) {
    _x = x;
    _y = y;
  }
}
