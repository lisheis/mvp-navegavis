import 'package:hive/hive.dart';

part 'wifi_fingerprint.g.dart';

/// One AP reading inside a fingerprint sample
@HiveType(typeId: 2)
class ApReading extends HiveObject {
  @HiveField(0)
  final String bssid;

  @HiveField(1)
  final String ssid;

  @HiveField(2)
  final int rssi; // dBm

  @HiveField(3)
  final int frequency; // MHz

  ApReading({
    required this.bssid,
    required this.ssid,
    required this.rssi,
    required this.frequency,
  });

  factory ApReading.fromJson(Map<String, dynamic> json) => ApReading(
        bssid: json['bssid'] as String,
        ssid: json['ssid'] as String? ?? '',
        rssi: json['rssi'] as int,
        frequency: json['frequency'] as int? ?? 2400,
      );

  Map<String, dynamic> toJson() => {
        'bssid': bssid,
        'ssid': ssid,
        'rssi': rssi,
        'frequency': frequency,
      };
}

/// A complete fingerprint sample tied to a node
@HiveType(typeId: 3)
class WifiFingerprint extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String nodeId;

  @HiveField(2)
  final String buildingId;

  @HiveField(3)
  final int floor;

  @HiveField(4)
  final List<ApReading> readings;

  @HiveField(5)
  final DateTime collectedAt;

  WifiFingerprint({
    required this.id,
    required this.nodeId,
    required this.buildingId,
    required this.floor,
    required this.readings,
    required this.collectedAt,
  });

  factory WifiFingerprint.fromJson(Map<String, dynamic> json) => WifiFingerprint(
        id: json['id'] as String,
        nodeId: json['nodeId'] as String,
        buildingId: json['buildingId'] as String,
        floor: json['floor'] as int,
        readings: (json['readings'] as List)
            .map((r) => ApReading.fromJson(r as Map<String, dynamic>))
            .toList(),
        collectedAt: DateTime.parse(json['collectedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nodeId': nodeId,
        'buildingId': buildingId,
        'floor': floor,
        'readings': readings.map((r) => r.toJson()).toList(),
        'collectedAt': collectedAt.toIso8601String(),
      };

  /// Average RSSI for a given BSSID across this fingerprint's readings
  int? avgRssiFor(String bssid) {
    final matching = readings.where((r) => r.bssid == bssid).toList();
    if (matching.isEmpty) return null;
    return (matching.map((r) => r.rssi).reduce((a, b) => a + b) / matching.length)
        .round();
  }
}
