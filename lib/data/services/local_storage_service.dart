import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/constants.dart';

class LocalStorageService {
  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  Future<String?> readAppMode() async {
    final p = await _prefs;
    return p.getString(LocalKeys.appMode);
  }

  Future<void> saveAppMode(String mode) async {
    final p = await _prefs;
    await p.setString(LocalKeys.appMode, mode);
  }

  Future<void> clearAppMode() async {
    final p = await _prefs;
    await p.remove(LocalKeys.appMode);
  }

  Future<bool> readBiometricEnabled() async {
    final p = await _prefs;
    return p.getBool(LocalKeys.isBiometricEnabled) ?? false;
  }

  Future<void> saveBiometricEnabled(bool enabled) async {
    final p = await _prefs;
    await p.setBool(LocalKeys.isBiometricEnabled, enabled);
  }

  Future<void> clearBiometricEnabled() async {
    final p = await _prefs;
    await p.remove(LocalKeys.isBiometricEnabled);
  }

  Future<String?> readThemeMode() async {
    final p = await _prefs;
    return p.getString(LocalKeys.themeMode);
  }

  Future<void> saveThemeMode(String mode) async {
    final p = await _prefs;
    await p.setString(LocalKeys.themeMode, mode);
  }

  Future<void> clearThemeMode() async {
    final p = await _prefs;
    await p.remove(LocalKeys.themeMode);
  }

  Future<String?> readAiInsightCache(String key) async {
    final p = await _prefs;
    return p.getString(key);
  }

  Future<void> saveAiInsightCache(String key, String value) async {
    final p = await _prefs;
    await p.setString(key, value);
  }

  Future<void> removeAiInsightCache(String key) async {
    final p = await _prefs;
    await p.remove(key);
  }

  Future<void> clearAll() async {
    final p = await _prefs;
    await p.clear();
  }
}
