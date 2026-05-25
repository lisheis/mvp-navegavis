import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_mode.dart';

const _kModeKey = 'app_mode';

/// Persists and exposes the current app mode (admin ↔ user).
/// Admin: cadastra prédios, edita mapas, treina Wi-Fi.
/// User : navega pelo prédio com voz.
class AppModeProvider extends ChangeNotifier {
  AppMode _mode = AppMode.user;
  bool _loaded = false;

  AppMode get mode => _mode;
  bool get isAdmin => _mode == AppMode.admin;
  bool get isUser => _mode == AppMode.user;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kModeKey);
    _mode = saved == 'admin' ? AppMode.admin : AppMode.user;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMode(AppMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kModeKey, mode.name);
  }

  Future<void> toggle() => setMode(isAdmin ? AppMode.user : AppMode.admin);
}
