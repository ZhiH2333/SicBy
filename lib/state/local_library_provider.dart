import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/track.dart';
import '../domain/library_source.dart';
import '../services/file_system_service.dart';
import '../services/local_database_service.dart';
import '../shared/track_factory.dart';
import 'service_providers.dart';
import 'settings_controller.dart';
import 'settings_models.dart';
import 'ui_models.dart';

class LocalLibraryState {
  final List<UiTrack> tracks;
  final bool isLoading;
  final String? error;
  final List<String> scannedPaths;

  const LocalLibraryState({
    this.tracks = const [],
    this.isLoading = false,
    this.error,
    this.scannedPaths = const [],
  });

  LocalLibraryState copyWith({
    List<UiTrack>? tracks,
    bool? isLoading,
    String? error,
    List<String>? scannedPaths,
  }) {
    return LocalLibraryState(
      tracks: tracks ?? this.tracks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      scannedPaths: scannedPaths ?? this.scannedPaths,
    );
  }
}

final localLibraryProvider =
    StateNotifierProvider<LocalLibraryController, LocalLibraryState>((ref) {
      final controller = LocalLibraryController(
        fileSystemService: ref.read(fileSystemServiceProvider),
        databaseService: ref.read(localDatabaseServiceProvider),
        settingsController: ref.read(settingsControllerProvider.notifier),
        settingsState: ref.read(settingsControllerProvider),
      );
      ref.listen(settingsControllerProvider, (previous, next) {
        controller.updateSettingsState(next);
      });
      return controller;
    });

class LocalLibraryController extends StateNotifier<LocalLibraryState> {
  final FileSystemService _fileSystemService;
  final LocalDatabaseService _databaseService;
  final SettingsController _settingsController;
  SettingsState _settingsState;
  final TrackFactory _trackFactory = TrackFactory();

  LocalLibraryController({
    required FileSystemService fileSystemService,
    required LocalDatabaseService databaseService,
    required SettingsController settingsController,
    required SettingsState settingsState,
  })  : _fileSystemService = fileSystemService,
        _databaseService = databaseService,
        _settingsController = settingsController,
        _settingsState = settingsState,
        super(const LocalLibraryState());

  void updateSettingsState(SettingsState state) {
    _settingsState = state;
  }

  Future<void> scanFromSettings() async {
    await scanPaths(_settingsState.settings.libraryPaths);
  }

  Future<void> scanPaths(List<String> paths) async {
    if (paths.isEmpty) {
      state = state.copyWith(
        tracks: const [],
        scannedPaths: const [],
        isLoading: false,
        error: null,
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final tracks = <Track>[];
      for (final path in paths) {
        final files = await _fileSystemService.listAudioFiles(
          LibrarySource.folder(path),
        );
        tracks.addAll(files.map(_trackFactory.createFromMediaFile));
      }

      await _databaseService.upsertTracks(tracks);
      final indexed = await _databaseService.getAllTracks();

      state = state.copyWith(
        tracks: indexed.map(_toUiTrack).toList(growable: false),
        scannedPaths: List<String>.from(paths),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> addLibraryPath(String path) async {
    await _settingsController.addLibraryPath(path);
    _settingsState = _settingsState.copyWith(
      settings: _settingsState.settings.copyWith(
        libraryPaths: List<String>.from(_settingsState.settings.libraryPaths)
          ..add(path),
      ),
    );
  }

  Future<void> removeLibraryPath(String path) async {
    await _settingsController.removeLibraryPath(path);
    _settingsState = _settingsState.copyWith(
      settings: _settingsState.settings.copyWith(
        libraryPaths: List<String>.from(_settingsState.settings.libraryPaths)
          ..remove(path),
      ),
    );
  }

  UiTrack _toUiTrack(Track track) {
    return UiTrack(
      id: track.id,
      title: track.title,
      artistName: track.artistName,
      albumName: track.albumName,
      duration: track.duration,
      locator: track.locator,
      filePath: track.locator.path,
      availability: track.availability,
    );
  }
}
