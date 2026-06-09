import 'package:flutter/material.dart';

import '../../data/services/local_storage_service.dart';

class ThemeController extends ChangeNotifier {
  final LocalStorageService _localStorage;

  ThemeController(this._localStorage);

  ThemeMode _themeMode = ThemeMode.light;
  bool _isLoading = false;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLoading => _isLoading;

  Future<void> loadThemeMode() async {
    _isLoading = true;
    notifyListeners();
    try {
      final saved = await _localStorage.readThemeMode();
      _themeMode = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setDarkMode(bool enabled) async {
    final nextMode = enabled ? ThemeMode.dark : ThemeMode.light;
    if (_themeMode == nextMode) return;
    _themeMode = nextMode;
    notifyListeners();
    await _localStorage.saveThemeMode(enabled ? 'dark' : 'light');
  }
}
