import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/track.dart';
import '../domain/library_source.dart';
import '../services/file_system_service.dart';
import '../services/local_database_service.dart';
import '../services/audio_metadata_service.dart';
import '../core/metadata/models/audio_metadata.dart';
import '../core/metadata/repositories/drift_metadata_repository.dart';
import '../core/metadata/db/metadata_db.dart';
import '../core/metadata/services/metadata_batch_scanner.dart';
import '../core/metadata/services/metadata_extractor.dart';
import '../services/background_scan_service.dart';
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
        backgroundScanService: ref.read(backgroundScanServiceProvider),
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
  final BackgroundScanService _backgroundScanService;
  final LocalDatabaseService _databaseService;
  final AudioMetadataService _metadataService;
  final SettingsController _settingsController;
  SettingsState _settingsState;
  Map<String, TrackMetadataOverride> _metadataOverrides;
  final TrackFactory _trackFactory = TrackFactory();
  final DriftMetadataRepository _metadataRepository =
      DriftMetadataRepository(MetadataDb());
  final MetadataBatchScanner _metadataBatchScanner =
      MetadataBatchScanner(MetadataExtractor());
  int _scanToken = 0;
  bool _pendingRescan = false;

  LocalLibraryController({
    required FileSystemService fileSystemService,
    required BackgroundScanService backgroundScanService,
    required LocalDatabaseService databaseService,
    required AudioMetadataService metadataService,
    required SettingsController settingsController,
    required SettingsState settingsState,
    required Map<String, TrackMetadataOverride> metadataOverrides,
  }) : _fileSystemService = fileSystemService,
       _backgroundScanService = backgroundScanService,
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
      final files = await _scanFiles(paths);
      final metadataByPath =
          preferMetadata ? await _loadMetadata(files) : const {};
      final ids = files.map(_trackFactory.idForMediaFile).toList();
      final existingTracks = await _databaseService.getTracksByIds(ids);
      final existingMap = {
        for (final track in existingTracks) track.id: track,
      };

      for (final file in files) {
        final id = _trackFactory.idForMediaFile(file);
        final existing = existingMap[id];
        final canReuse = existing != null && _matchesFile(existing, file);
        final artworkOk =
            !preferMetadata ||
            _metadataService.isArtworkAvailable(existing?.artworkPath);
        if (preferMetadata && canReuse && artworkOk) {
          tracks.add(existing);
          continue;
        }

        final metadata =
            preferMetadata && file.locator.path != null
                ? metadataByPath[file.locator.path!]
                : null;

        var track = _trackFactory.createFromMediaFile(
          file,
          metadata: metadata,
          preferMetadata: preferMetadata,
        );

        if (!preferMetadata && canReuse) {
          track = track.copyWith(
            duration: existing.duration,
            albumName: existing.albumName,
            artworkPath: existing.artworkPath,
          );
        }

        tracks.add(track);
      }

      await _databaseService.upsertTracks(tracks);
      final isFullScan = _isFullScan(paths);
      if (isFullScan) {
        await _databaseService.deleteTracksNotIn(ids.toSet());
      }
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

  Future<List<MediaFile>> _scanFiles(List<String> paths) async {
    final files = <MediaFile>[];
    for (final path in paths) {
      final source = LibrarySource.folder(path);
      final scanned = await _backgroundScanService.listAudioFiles(
        source,
        recursive: _settingsState.settings.scanRecursively,
        includeHidden: _settingsState.settings.includeHiddenFiles,
      );
      files.addAll(scanned);
    }

    if (files.isEmpty && _fileSystemService.supportsFileSelection) {
      for (final path in paths) {
        final source = LibrarySource.folder(path);
        final scanned = await _fileSystemService.listAudioFiles(
          source,
          recursive: _settingsState.settings.scanRecursively,
          includeHidden: _settingsState.settings.includeHiddenFiles,
        );
        files.addAll(scanned);
      }
    }

    return files;
  }

  Future<Map<String, AudioMetadataResult>> _loadMetadata(
    List<MediaFile> files,
  ) async {
    final paths = files
        .map((file) => file.locator.path)
        .whereType<String>()
        .toList(growable: false);
    if (paths.isEmpty) return {};

    final cached = await _metadataRepository.getByPaths(paths);
    final cachedByPath = {for (final item in cached) item.path: item};

    final stalePaths = <String>[];
    for (final file in files) {
      final path = file.locator.path;
      if (path == null) continue;
      final cachedItem = cachedByPath[path];
      if (!_isCacheValid(cachedItem, file)) {
        stalePaths.add(path);
      }
    }

    if (stalePaths.isNotEmpty) {
      try {
        final fresh = await _metadataBatchScanner.scan(stalePaths);
        for (final item in fresh) {
          await _metadataRepository.upsert(item);
          cachedByPath[item.path] = item;
        }
      } catch (_) {
        // Fall back to cached results only.
      }
    }

    final results = <String, AudioMetadataResult>{};
    for (final entry in cachedByPath.entries) {
      results[entry.key] = _toLegacyMetadata(entry.value);
    }
    return results;
  }

  bool _isCacheValid(AudioMetadata? cached, MediaFile file) {
    if (cached == null) return false;
    final modified = file.lastModified?.millisecondsSinceEpoch;
    final cachedModified = cached.lastModified?.millisecondsSinceEpoch;
    if (modified != cachedModified) return false;
    if (file.sizeBytes != cached.fileSizeBytes) return false;
    if (cached.artworkPath != null &&
        !_metadataService.isArtworkAvailable(cached.artworkPath)) {
      return false;
    }
    return true;
  }

  AudioMetadataResult _toLegacyMetadata(AudioMetadata metadata) {
    return AudioMetadataResult(
      title: metadata.title,
      artist: metadata.artist,
      album: metadata.album,
      duration: metadata.duration,
      artworkPath: metadata.artworkPath,
    );
  }

  bool _matchesFile(Track track, MediaFile file) {
    final modified = file.lastModified?.millisecondsSinceEpoch;
    final trackModified = track.lastModified?.millisecondsSinceEpoch;
    if (modified != trackModified) return false;
    if (file.sizeBytes != track.fileSizeBytes) return false;
    return true;
  }

  bool _isFullScan(List<String> paths) {
    final configured = _settingsState.settings.libraryPaths;
    if (configured.length != paths.length) return false;
    return configured.toSet().containsAll(paths);
  }

  UiTrack _toUiTrack(Track track) {
    final override = _metadataOverrides[track.id];
    final title = _cleanTextRequired(
      override?.title ?? track.title,
      fallback: 'Unknown',
    );
    final artist = _cleanTextRequired(
      override?.artist ?? track.artistName,
      fallback: 'Unknown Artist',
    );
    final album = _cleanTextOptional(override?.album ?? track.albumName);
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
              title: _cleanTextRequired(
                override.title ?? track.title,
                fallback: 'Unknown',
              ),
              artistName: _cleanTextRequired(
                override.artist ?? track.artistName,
                fallback: 'Unknown Artist',
              ),
              albumName: _cleanTextOptional(override.album ?? track.albumName),
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

  String _cleanTextRequired(String? value, {required String fallback}) {
    if (value == null) return fallback;
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String? _cleanTextOptional(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
