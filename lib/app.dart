import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'presentation/providers/app_mode_provider.dart';
import 'presentation/providers/building_provider.dart';
import 'presentation/providers/navigation_provider.dart';
import 'presentation/providers/positioning_provider.dart';
import 'services/api_service.dart';
import 'services/cache_service.dart';
import 'services/tts_service.dart';
import 'services/stt_service.dart';
import 'services/wifi_service.dart';

class NavegaVisApp extends StatelessWidget {
  final CacheService cache;
  const NavegaVisApp({super.key, required this.cache});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ── Services (singletons) ─────────────────────────────────────────
        Provider<CacheService>.value(value: cache),
        Provider<ApiService>(create: (_) => ApiService()),
        Provider<TtsService>(create: (_) => TtsService()),
        Provider<SttService>(create: (_) => SttService()),
        Provider<WifiScanService>(create: (_) => WifiScanService()),

        // ── App mode (admin / user) ───────────────────────────────────────
        ChangeNotifierProvider<AppModeProvider>(
          create: (_) => AppModeProvider(),
        ),

        // ── State providers ───────────────────────────────────────────────
        ChangeNotifierProxyProvider2<CacheService, ApiService, BuildingProvider>(
          create: (ctx) => BuildingProvider(
            ctx.read<CacheService>(),
            ctx.read<ApiService>(),
          ),
          update: (_, cache, api, prev) =>
              prev ?? BuildingProvider(cache, api),
        ),
        ChangeNotifierProxyProvider<WifiScanService, PositioningProvider>(
          create: (ctx) => PositioningProvider(ctx.read<WifiScanService>()),
          update: (_, wifi, prev) => prev ?? PositioningProvider(wifi),
        ),
        ChangeNotifierProxyProvider2<TtsService, SttService, NavigationProvider>(
          create: (ctx) => NavigationProvider(
            ctx.read<TtsService>(),
            ctx.read<SttService>(),
          ),
          update: (_, tts, stt, prev) => prev ?? NavigationProvider(tts, stt),
        ),
      ],
      child: MaterialApp.router(
        title: 'NavegaVis',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        routerConfig: appRouter,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
