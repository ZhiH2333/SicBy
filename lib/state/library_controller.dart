import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui_models.dart';
import '../domain/library_source.dart';
import '../domain/track.dart';
import '../services/file_system_service.dart';
import '../services/local_database_service.dart';
import '../shared/track_factory.dart';
import 'service_providers.dart';

/// Library controller provider
final libraryControllerProvider =
    StateNotifierProvider<LibraryController, UiLibraryState>((ref) {
      return LibraryController(
        fileSystemService: ref.read(fileSystemServiceProvider),
        databaseService: ref.read(localDatabaseServiceProvider),
      );
    });

/// Manages library state - scanning folders and listing tracks
class LibraryController extends StateNotifier<UiLibraryState> {
  final FileSystemService _fileSystemService;
  final LocalDatabaseService _databaseService;
  final TrackFactory _trackFactory = TrackFactory();

  LibraryController({
    required FileSystemService fileSystemService,
    required LocalDatabaseService databaseService,
  })  : _fileSystemService = fileSystemService,
        _databaseService = databaseService,
        super(const UiLibraryState());

  /// Pick a folder and scan for audio files
  Future<void> pickFolder() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final source = await _fileSystemService.pickSource();
      if (source == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      await _scanSource(source);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Scan a folder for audio files
  Future<void> scanFolder(String folderPath) async {
    try {
      final source = LibrarySource.folder(folderPath);
      await _scanSource(source);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Clear library
  Future<void> clear() async {
    await _databaseService.clear();
    state = const UiLibraryState();
  }

  Future<void> _scanSource(LibrarySource source) async {
    final folderPath = source.kind == LibrarySourceKind.folder
        ? source.folderPath
        : 'Selected files';

    state = state.copyWith(
      isLoading: true,
      error: null,
      currentFolderPath: folderPath,
    );

    final mediaFiles = await _fileSystemService.listAudioFiles(source);
    final tracks = mediaFiles.map(_trackFactory.createFromMediaFile).toList();

    await _databaseService.upsertTracks(tracks);
    final indexedTracks = await _databaseService.getAllTracks();

    state = state.copyWith(
      tracks: indexedTracks.map(_toUiTrack).toList(growable: false),
      isLoading: false,
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
    );
  }
}
