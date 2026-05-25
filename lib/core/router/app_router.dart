import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/map/map_screen.dart';
import '../../presentation/screens/navigation/navigation_screen.dart';
import '../../presentation/screens/training/training_screen.dart';
import '../../presentation/screens/admin/building_setup_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const HomeScreen(),
    ),

    // ── Admin routes ────────────────────────────────────────────────────────

    // Wizard de cadastro/configuração de prédio
    // /setup            → novo prédio
    // /setup?id=xxx     → editar prédio existente
    GoRoute(
      path: '/setup',
      builder: (ctx, state) {
        final id = state.uri.queryParameters['id'];
        return BuildingSetupScreen(buildingId: id);
      },
    ),

    // Editor de grafo (nós + arestas)
    GoRoute(
      path: '/map/:buildingId',
      builder: (ctx, state) =>
          MapScreen(buildingId: state.pathParameters['buildingId']!),
    ),

    // Treinamento de fingerprints Wi-Fi
    GoRoute(
      path: '/training/:buildingId',
      builder: (ctx, state) =>
          TrainingScreen(buildingId: state.pathParameters['buildingId']!),
    ),

    // ── User routes ─────────────────────────────────────────────────────────

    // Navegação em tempo real
    GoRoute(
      path: '/navigate/:buildingId',
      builder: (ctx, state) =>
          NavigationScreen(buildingId: state.pathParameters['buildingId']!),
    ),
  ],
);
