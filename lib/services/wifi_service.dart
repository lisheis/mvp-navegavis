import 'dart:async';
import 'package:wifi_scan/wifi_scan.dart';
import '../data/models/wifi_fingerprint.dart';

/// Continuously scans for nearby Wi-Fi APs and exposes a stream of [ApReading] lists.
///
/// Wi-Fi is used as a passive sensor — no connections are made.
/// This works entirely offline; internet is not required.
class WifiScanService {
  final StreamController<List<ApReading>> _controller =
      StreamController.broadcast();

  Timer? _timer;
  bool _isScanning = false;

  Stream<List<ApReading>> get scanStream => _controller.stream;

  bool get isScanning => _isScanning;

  Future<bool> checkPermissions() async {
    final can = await WiFiScan.instance.canStartScan(askPermissions: true);
    return can == CanStartScan.yes;
  }

  /// Start periodic scanning every [intervalMs] ms.
  Future<void> startScanning({int intervalMs = 2000}) async {
    if (_isScanning) return;

    final hasPermission = await checkPermissions();
    if (!hasPermission) return;

    _isScanning = true;
    await _doScan();

    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) => _doScan());
  }

  Future<void> _doScan() async {
    try {
      await WiFiScan.instance.startScan();
      final results = await WiFiScan.instance.getScannedResults();
      final readings = results.map((r) => ApReading(
            bssid: r.bssid,
            ssid: r.ssid,
            rssi: r.level,
            frequency: r.frequency,
          )).toList();
      if (!_controller.isClosed) _controller.add(readings);
    } catch (_) {
      // Silent — sensor failure should not crash app
    }
  }

  /// One-shot scan; waits for results.
  Future<List<ApReading>> scanOnce() async {
    await WiFiScan.instance.startScan();
    await Future.delayed(const Duration(milliseconds: 800));
    final results = await WiFiScan.instance.getScannedResults();
    return results.map((r) => ApReading(
          bssid: r.bssid,
          ssid: r.ssid,
          rssi: r.level,
          frequency: r.frequency,
        )).toList();
  }

  void stopScanning() {
    _timer?.cancel();
    _timer = null;
    _isScanning = false;
  }

  void dispose() {
    stopScanning();
    _controller.close();
  }
}
