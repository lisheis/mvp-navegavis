import 'package:flutter/material.dart';

class AppTheme {
  static const _primary = Color(0xFF1976D2);
  static const _secondary = Color(0xFF00BCD4);
  static const _surface = Color(0xFF121212);

  static ThemeData get dark => ThemeData(
        colorScheme: ColorScheme.dark(
          primary: _primary,
          secondary: _secondary,
          surface: _surface,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A2E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E1E2E),
          elevation: 4,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
        ),
      );

  static ThemeData get light => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _primary,
          secondary: _secondary,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(elevation: 0),
      );
}
