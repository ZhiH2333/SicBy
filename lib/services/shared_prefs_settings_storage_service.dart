import 'package:shared_preferences/shared_preferences.dart';

import '../state/settings_models.dart';
import 'settings_storage_service.dart';

class SharedPrefsSettingsStorageService implements SettingsStorageService {
  static const _keyVersion = 'settings_version';
  static const _keyScanRecursively = 'settings_scan_recursively';
  static const _keyIncludeHidden = 'settings_include_hidden';
  static const _keyRememberLastFolder = 'settings_remember_last_folder';
  static const _keyPlaybackSpeed = 'settings_playback_speed';
  static const _keyGaplessEnabled = 'settings_gapless_enabled';

  @override
  Future<AppSettings> read() async {
    final prefs = await SharedPreferences.getInstance();
    final storedVersion = prefs.getInt(_keyVersion);

    if (storedVersion == null) {
      final defaults = AppSettings.defaults();
      await write(defaults);
      return defaults;
    }

    final settings = AppSettings.fromMap({
      'version': storedVersion,
      'scanRecursively': prefs.getBool(_keyScanRecursively),
      'includeHiddenFiles': prefs.getBool(_keyIncludeHidden),
      'rememberLastFolder': prefs.getBool(_keyRememberLastFolder),
      'playbackSpeed': prefs.getDouble(_keyPlaybackSpeed),
      'gaplessEnabled': prefs.getBool(_keyGaplessEnabled),
    });

    return _migrateIfNeeded(settings);
  }

  @override
  Future<void> write(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyVersion, settings.version);
    await prefs.setBool(_keyScanRecursively, settings.scanRecursively);
    await prefs.setBool(_keyIncludeHidden, settings.includeHiddenFiles);
    await prefs.setBool(_keyRememberLastFolder, settings.rememberLastFolder);
    await prefs.setDouble(_keyPlaybackSpeed, settings.playbackSpeed);
    await prefs.setBool(_keyGaplessEnabled, settings.gaplessEnabled);
  }

  @override
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyVersion);
    await prefs.remove(_keyScanRecursively);
    await prefs.remove(_keyIncludeHidden);
    await prefs.remove(_keyRememberLastFolder);
    await prefs.remove(_keyPlaybackSpeed);
    await prefs.remove(_keyGaplessEnabled);
  }

  AppSettings _migrateIfNeeded(AppSettings settings) {
    if (settings.version == AppSettings.currentVersion) {
      return settings;
    }

    var updated = settings;

    if (settings.version < 1) {
      updated = updated.copyWith(version: 1);
    }

    return updated.copyWith(version: AppSettings.currentVersion);
  }
}
