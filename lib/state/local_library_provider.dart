import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/track.dart';
import '../domain/library_source.dart';
import '../services/file_system_service.dart';
import '../services/local_database_service.dart';
import '../services/audio_metadata_service.dart';
import '../shared/track_factory.dart';
import 'service_providers.dart';
import 'settings_controller.dart';
import 'settings_models.dart';
import 'ui_models.dart';
import 'metadata_overrides_controller.dart';
import 'metadata_overrides_models.dart';

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
        metadataService: ref.read(audioMetadataServiceProvider),
        settingsController: ref.read(settingsControllerProvider.notifier),
        settingsState: ref.read(settingsControllerProvider),
        metadataOverrides: ref.read(metadataOverridesProvider),
      );
      ref.listen(settingsControllerProvider, (previous, next) {
        controller.updateSettingsState(next);
      });
      ref.listen(metadataOverridesProvider, (previous, next) {
        controller.updateMetadataOverrides(next);
      });
      return controller;
    });

class LocalLibraryController extends StateNotifier<LocalLibraryState> {
  final FileSystemService _fileSystemService;
  final LocalDatabaseService _databaseService;
  final AudioMetadataService _metadataService;
  final SettingsController _settingsController;
  SettingsState _settingsState;
  Map<String, TrackMetadataOverride> _metadataOverrides;
  final TrackFactory _trackFactory = TrackFactory();
  int _scanToken = 0;
  bool _pendingRescan = false;

  LocalLibraryController({
    required FileSystemService fileSystemService,
    required LocalDatabaseService databaseService,
    required AudioMetadataService metadataService,
    required SettingsController settingsController,
    required SettingsState settingsState,
    required Map<String, TrackMetadataOverride> metadataOverrides,
  }) : _fileSystemService = fileSystemService,
       _databaseService = databaseService,
       _metadataService = metadataService,
       _settingsController = settingsController,
       _settingsState = settingsState,
       _metadataOverrides = metadataOverrides,
       super(const LocalLibraryState());

  void updateSettingsState(SettingsState state) {
    _settingsState = state;
  }

  void updateMetadataOverrides(Map<String, TrackMetadataOverride> overrides) {
    _metadataOverrides = overrides;
    _refreshTracksWithOverrides();
  }

  Future<void> scanFromSettings() async {
    if (state.isLoading) {
      _pendingRescan = true;
      return;
    }
    await scanPaths(_settingsState.settings.libraryPaths);
  }

  Future<void> scanPaths(List<String> paths) async {
    if (state.isLoading) {
      _pendingRescan = true;
      return;
    }
    if (paths.isEmpty) {
      state = state.copyWith(
        tracks: const [],
        scannedPaths: const [],
        isLoading: false,
        error: null,
      );
      return;
    }

    final currentToken = ++_scanToken;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final tracks = <Track>[];
      final preferMetadata = _settingsState.settings.metadataMode == 'metadata';
      for (final path in paths) {
        final files = await _fileSystemService.listAudioFiles(
          LibrarySource.folder(path),
          recursive: _settingsState.settings.scanRecursively,
          includeHidden: _settingsState.settings.includeHiddenFiles,
        );
        for (final file in files) {
          AudioMetadataResult? metadata;
          if (preferMetadata && file.locator.path != null) {
            try {
              metadata = await _metadataService
                  .read(
                    file.locator.path!,
                    modified: file.lastModified,
                  )
                  .timeout(const Duration(seconds: 2));
            } catch (_) {
              metadata = null;
            }
          }
          tracks.add(
            _trackFactory.createFromMediaFile(
              file,
              metadata: metadata,
              preferMetadata: preferMetadata,
            ),
          );
        }
      }

      await _databaseService.upsertTracks(tracks);
      final indexed = await _databaseService.getAllTracks();

      if (currentToken != _scanToken) return;
      state = state.copyWith(
        tracks: indexed.map(_toUiTrack).toList(growable: false),
        scannedPaths: List<String>.from(paths),
        isLoading: false,
      );
      if (_pendingRescan) {
        _pendingRescan = false;
        Future.microtask(scanFromSettings);
      }
    } catch (e) {
      if (currentToken != _scanToken) return;
      state = state.copyWith(isLoading: false, error: e.toString());
      if (_pendingRescan) {
        _pendingRescan = false;
        Future.microtask(scanFromSettings);
      }
    }
  }

  Future<void> addLibraryPath(String path) async {
    await _settingsController.addLibraryPath(path);
    final updatedPaths = List<String>.from(
      _settingsController.state.settings.libraryPaths,
    );
    _settingsState = _settingsState.copyWith(
      settings: _settingsState.settings.copyWith(libraryPaths: updatedPaths),
    );
  }

  Future<void> pickAndAddFolder() async {
    final source = await _fileSystemService.pickSource();
    if (source == null || source.folderPath == null) return;
    await addLibraryPath(source.folderPath!);
    await scanFromSettings();
  }

  Future<void> removeLibraryPath(String path) async {
    await _settingsController.removeLibraryPath(path);
    final updatedPaths = List<String>.from(
      _settingsController.state.settings.libraryPaths,
    );
    _settingsState = _settingsState.copyWith(
      settings: _settingsState.settings.copyWith(libraryPaths: updatedPaths),
    );
    state = state.copyWith(
      scannedPaths: List<String>.from(state.scannedPaths)..remove(path),
    );
    await scanFromSettings();
  }

  UiTrack _toUiTrack(Track track) {
    final override = _metadataOverrides[track.id];
    final title = override?.title ?? track.title;
    final artist = override?.artist ?? track.artistName;
    final album = override?.album ?? track.albumName;
    final artworkPath = override?.artworkPath ?? track.artworkPath;

    return UiTrack(
      id: track.id,
      title: title,
      artistName: artist,
      albumName: album,
      duration: track.duration,
      locator: track.locator,
      filePath: track.locator.path,
      artworkPath: artworkPath,
      availability: track.availability,
    );
  }

  void _refreshTracksWithOverrides() {
    if (state.tracks.isEmpty) return;
    state = state.copyWith(
      tracks: state.tracks
          .map((track) {
            final override = _metadataOverrides[track.id];
            if (override == null) return track;
            return UiTrack(
              id: track.id,
              title: override.title ?? track.title,
              artistName: override.artist ?? track.artistName,
              albumName: override.album ?? track.albumName,
              duration: track.duration,
              locator: track.locator,
              filePath: track.filePath,
              artworkPath: override.artworkPath ?? track.artworkPath,
              availability: track.availability,
            );
          })
          .toList(growable: false),
    );
  }
}
