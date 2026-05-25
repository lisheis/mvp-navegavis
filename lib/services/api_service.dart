import 'package:dio/dio.dart';
import '../data/models/building.dart';
import '../data/models/wifi_fingerprint.dart';

/// REST API client for backend synchronization.
/// All navigation logic works offline; this is used only for sync.
class ApiService {
  final Dio _dio;

  // Default to the Android emulator host mapping. Override via constructor when needed.
  ApiService({String baseUrl = 'http://10.0.2.2:3000/api'})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ));

  // ── Buildings ──────────────────────────────────────────────────────────────

  Future<List<Building>> fetchBuildings() async {
    final res = await _dio.get('/buildings');
    return (res.data as List)
        .map((b) => Building.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  Future<Building> fetchBuilding(String id) async {
    final res = await _dio.get('/buildings/$id');
    return Building.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Building> createBuilding(Map<String, dynamic> json) async {
    final res = await _dio.post('/buildings', data: json);
    return Building.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> updateBuilding(String id, Map<String, dynamic> json) =>
      _dio.put('/buildings/$id', data: json);

  Future<void> deleteBuilding(String id) =>
      _dio.delete('/buildings/$id');

  // ── Fingerprints ───────────────────────────────────────────────────────────

  Future<void> uploadFingerprint(WifiFingerprint fp) =>
      _dio.post('/fingerprints', data: fp.toJson());

  Future<List<WifiFingerprint>> fetchFingerprints(String buildingId) async {
    final res = await _dio.get('/fingerprints', queryParameters: {
      'buildingId': buildingId,
    });
    return (res.data as List)
        .map((f) => WifiFingerprint.fromJson(f as Map<String, dynamic>))
        .toList();
  }

  // ── Graph ──────────────────────────────────────────────────────────────────

  Future<void> syncGraph(String buildingId, Map<String, dynamic> graphJson) =>
      _dio.put('/buildings/$buildingId/graph', data: graphJson);
}
