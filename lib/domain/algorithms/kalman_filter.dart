/// 1-D Kalman filter for smoothing a noisy scalar signal (e.g. RSSI or x/y coordinate).
///
/// State equation:   x_k  = x_{k-1}          (no motion model, position = signal)
/// Observation eq.:  z_k  = x_k + noise
///
/// Q – process noise covariance (how much the true value can change between steps)
/// R – measurement noise covariance (sensor noise level)
class KalmanFilter1D {
  double _x;   // current state estimate
  double _p;   // current error covariance
  final double q; // process noise
  final double r; // measurement noise

  KalmanFilter1D({
    required double initialValue,
    this.q = 0.008,
    this.r = 3.0,
    double initialErrorCovariance = 1.0,
  })  : _x = initialValue,
        _p = initialErrorCovariance;

  double get value => _x;

  /// Feed a new measurement and return the filtered estimate.
  double update(double measurement) {
    // Predict
    final pPred = _p + q;

    // Update (Kalman gain)
    final k = pPred / (pPred + r);
    _x = _x + k * (measurement - _x);
    _p = (1 - k) * pPred;

    return _x;
  }

  void reset(double value) {
    _x = value;
    _p = 1.0;
  }
}

/// 2-D Kalman filter for (x, y) position smoothing.
class KalmanFilter2D {
  final KalmanFilter1D _kx;
  final KalmanFilter1D _ky;

  KalmanFilter2D({
    double initialX = 0,
    double initialY = 0,
    double processNoise = 0.01,
    double measurementNoise = 2.0,
  })  : _kx = KalmanFilter1D(
          initialValue: initialX,
          q: processNoise,
          r: measurementNoise,
        ),
        _ky = KalmanFilter1D(
          initialValue: initialY,
          q: processNoise,
          r: measurementNoise,
        );

  (double x, double y) get position => (_kx.value, _ky.value);

  (double, double) update(double x, double y) {
    return (_kx.update(x), _ky.update(y));
  }

  void reset(double x, double y) {
    _kx.reset(x);
    _ky.reset(y);
  }
}

/// Per-BSSID Kalman filter bank — one filter per access point.
/// Used to smooth individual RSSI readings before fingerprint matching.
class RssiKalmanBank {
  final Map<String, KalmanFilter1D> _filters = {};
  final double processNoise;
  final double measurementNoise;

  RssiKalmanBank({
    this.processNoise = 0.008,
    this.measurementNoise = 4.0,
  });

  /// Smooth the RSSI for a given BSSID.
  double smooth(String bssid, double rawRssi) {
    _filters.putIfAbsent(
      bssid,
      () => KalmanFilter1D(
        initialValue: rawRssi,
        q: processNoise,
        r: measurementNoise,
      ),
    );
    return _filters[bssid]!.update(rawRssi);
  }

  Map<String, double> smoothAll(Map<String, double> rawReadings) {
    return {
      for (final entry in rawReadings.entries)
        entry.key: smooth(entry.key, entry.value),
    };
  }

  void clear() => _filters.clear();
}
