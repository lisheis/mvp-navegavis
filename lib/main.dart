import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'app.dart';
import 'services/cache_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Solicita as permissões do sistema (sem elas o Wi-Fi Scan e STT são silenciados pelo Android)
  await [
    Permission.microphone,
    Permission.location,
  ].request();

  // Initialize Cache / Hive Box before app starts to guarantee availability on all screens
  final cache = CacheService();
  await cache.init();

  // Lock to portrait by default (indoor navigation UX)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(NavegaVisApp(cache: cache));
}
