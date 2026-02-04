import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'ui_models.dart';

/// Library controller provider
final libraryControllerProvider =
    StateNotifierProvider<LibraryController, UiLibraryState>((ref) {
      return LibraryController();
    });

/// Manages library state - scanning folders and listing tracks
class LibraryController extends StateNotifier<UiLibraryState> {
  LibraryController() : super(const UiLibraryState());

  /// Pick a folder and scan for audio files
  Future<void> pickFolder() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result == null) {
        state = state.copyWith(isLoading: false);
        return;
      }

      await scanFolder(result);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Scan a folder for audio files
  Future<void> scanFolder(String folderPath) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      currentFolderPath: folderPath,
    );

    try {
      final dir = Directory(folderPath);
      final tracks = <UiTrack>[];
      var id = 0;

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final ext = entity.path.split('.').last.toLowerCase();
          if (['mp3', 'flac', 'wav', 'm4a', 'aac', 'ogg'].contains(ext)) {
            final filename = entity.path.split('/').last;
            final nameWithoutExt = filename.replaceAll(RegExp(r'\.[^.]+$'), '');

            tracks.add(
              UiTrack(
                id: 'track_${id++}',
                title: nameWithoutExt,
                artistName: 'Unknown Artist', // No metadata parsing yet
                duration: Duration.zero, // Will be populated by player
                filePath: entity.path,
              ),
            );
          }
        }
      }

      state = state.copyWith(tracks: tracks, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Clear library
  void clear() {
    state = const UiLibraryState();
  }
}
