import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/settings_storage_service.dart';
import 'settings_models.dart';
import 'service_providers.dart';

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, SettingsState>((ref) {
      final storage = ref.read(settingsStorageServiceProvider);
      return SettingsController(storage);
    });

class SettingsController extends StateNotifier<SettingsState> {
  final SettingsStorageService _storage;

  SettingsController(this._storage) : super(SettingsState.initial()) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final settings = await _storage.read();
      state = state.copyWith(settings: settings, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateSettings(AppSettings settings) async {
    state = state.copyWith(settings: settings);
    try {
      await _storage.write(settings);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> reset() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _storage.reset();
      final defaults = AppSettings.defaults();
      await _storage.write(defaults);
      state = state.copyWith(settings: defaults, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> setScanRecursively(bool value) async {
    await updateSettings(state.settings.copyWith(scanRecursively: value));
  }

  Future<void> setIncludeHiddenFiles(bool value) async {
    await updateSettings(state.settings.copyWith(includeHiddenFiles: value));
  }

  Future<void> setRememberLastFolder(bool value) async {
    await updateSettings(state.settings.copyWith(rememberLastFolder: value));
  }

  Future<void> setPlaybackSpeed(double value) async {
    await updateSettings(state.settings.copyWith(playbackSpeed: value));
  }

  Future<void> setGaplessEnabled(bool value) async {
    await updateSettings(state.settings.copyWith(gaplessEnabled: value));
  }

  Future<void> setThemeMode(String value) async {
    await updateSettings(state.settings.copyWith(themeMode: value));
  }

  Future<void> setAccentColor(int value) async {
    await updateSettings(state.settings.copyWith(accentColor: value));
  }

  Future<void> setShuffleDefault(bool value) async {
    await updateSettings(state.settings.copyWith(shuffleDefault: value));
  }

  Future<void> setRepeatModeDefault(String value) async {
    await updateSettings(state.settings.copyWith(repeatModeDefault: value));
  }

  Future<void> setAutoRefreshOnLaunch(bool value) async {
    await updateSettings(state.settings.copyWith(autoRefreshOnLaunch: value));
  }

  Future<void> setMetadataMode(String value) async {
    await updateSettings(state.settings.copyWith(metadataMode: value));
  }

  Future<void> setAutoDownloadCloudTracks(bool value) async {
    await updateSettings(
      state.settings.copyWith(autoDownloadCloudTracks: value),
    );
  }

  Future<void> setShowCloudOnlyTracks(bool value) async {
    await updateSettings(state.settings.copyWith(showCloudOnlyTracks: value));
  }

  Future<void> setAutoDownloadOnPlay(bool value) async {
    await updateSettings(state.settings.copyWith(autoDownloadOnPlay: value));
  }

  Future<void> setResumeAfterDownload(bool value) async {
    await updateSettings(state.settings.copyWith(resumeAfterDownload: value));
  }

  Future<void> setDisableSwitchDuringDownload(bool value) async {
    await updateSettings(
      state.settings.copyWith(disableSwitchDuringDownload: value),
    );
  }

  Future<void> setLyricsEnabled(bool value) async {
    await updateSettings(state.settings.copyWith(lyricsEnabled: value));
  }

  Future<void> setLibraryPaths(List<String> paths) async {
    await updateSettings(state.settings.copyWith(libraryPaths: paths));
  }

  Future<void> addLibraryPath(String path) async {
    final updated = List<String>.from(state.settings.libraryPaths);
    if (!updated.contains(path)) {
      updated.add(path);
      await setLibraryPaths(updated);
    }
  }

  Future<void> removeLibraryPath(String path) async {
    final updated = List<String>.from(state.settings.libraryPaths)
      ..remove(path);
    await setLibraryPaths(updated);
  }
}
