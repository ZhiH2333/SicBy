import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sicby/state/library_controller.dart';
import 'package:sicby/state/playback_controller.dart';
import 'package:sicby/state/ui_models.dart';
import 'package:sicby/ui/widgets/cloud_confirmation_dialog.dart';

/// Library Screen - displays list of tracks
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(libraryControllerProvider);
    final libraryController = ref.read(libraryControllerProvider.notifier);
    final playbackController = ref.read(playbackControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: () => libraryController.pickFolder(),
            tooltip: 'Select Folder',
          ),
        ],
      ),
      body: _buildBody(context, libraryState, playbackController),
    );
  }

  Widget _buildBody(
    BuildContext context,
    UiLibraryState state,
    PlaybackController playbackController,
  ) {
    // Loading state
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Error state
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error: ${state.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      );
    }

    // Empty state
    if (state.tracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.library_music, size: 64, color: Colors.grey[600]),
              const SizedBox(height: 16),
              Text(
                state.currentFolderPath != null
                    ? 'No audio files found'
                    : 'Select a folder to scan',
                style: TextStyle(fontSize: 18, color: Colors.grey[400]),
              ),
              const SizedBox(height: 8),
              if (state.currentFolderPath != null)
                Text(
                  state.currentFolderPath!,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
            ],
          ),
        ),
      );
    }

    // Track list
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Folder path header
        if (state.currentFolderPath != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[900],
            child: Row(
              children: [
                Icon(Icons.folder, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.currentFolderPath!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${state.tracks.length} tracks',
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                ),
              ],
            ),
          ),
        // Track list
        Expanded(
          child: ListView.builder(
            itemCount: state.tracks.length,
            itemBuilder: (context, index) {
              final track = state.tracks[index];
              return _TrackListTile(
                track: track,
                onTap: () {
                  if (track.isCloud && !track.isDownloaded) {
                    showDialog(
                      context: context,
                      builder: (context) => CloudConfirmationDialog(
                        trackTitle: track.title,
                        fileSize: '3.5 MB', // TODO: Get actual size
                        onConfirm: () {
                          playbackController.play(track, queue: state.tracks);
                        },
                      ),
                    );
                  } else {
                    playbackController.play(track, queue: state.tracks);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Simple track list tile
class _TrackListTile extends StatelessWidget {
  final UiTrack track;
  final VoidCallback onTap;

  const _TrackListTile({required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.music_note, color: Colors.white54),
      ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        track.artistName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey[500]),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (track.isCloud && !track.isDownloaded)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(
                Icons.cloud_download_outlined,
                size: 16,
                color: Colors.grey,
              ),
            ),
          if (track.duration != Duration.zero)
            Text(
              track.durationFormatted,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}
