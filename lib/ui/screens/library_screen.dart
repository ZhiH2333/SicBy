import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sicby/state/local_library_provider.dart';
import 'package:sicby/state/liked_songs_provider.dart';
import 'package:sicby/state/playback_controller.dart';
import 'package:sicby/state/ui_models.dart';
import 'package:sicby/state/virtual_library_controller.dart';
import 'package:sicby/state/virtual_library_models.dart';

/// Library Screen - displays list of tracks
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(localLibraryProvider.notifier).scanFromSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(localLibraryProvider);
    final libraryController = ref.read(localLibraryProvider.notifier);
    final playbackController = ref.read(playbackControllerProvider.notifier);
    final likedState = ref.watch(likeControllerProvider);
    final virtualState = ref.watch(virtualLibraryProvider);
    final folderById = {
      for (final folder in virtualState.folders) folder.id: folder,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: () => libraryController.pickAndAddFolder(),
            tooltip: 'Select Folder',
          ),
        ],
      ),
      body: _buildBody(
        context,
        libraryState,
        playbackController,
        likedState,
        virtualState,
        folderById,
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    LocalLibraryState state,
    PlaybackController playbackController,
    LikedSongsState likedState,
    VirtualLibraryState virtualState,
    Map<String, VirtualFolder> folderById,
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
                state.scannedPaths.isNotEmpty
                    ? 'No audio files found'
                    : 'Select a folder to scan',
                style: TextStyle(fontSize: 18, color: Colors.grey[400]),
              ),
              const SizedBox(height: 8),
              if (state.scannedPaths.isNotEmpty)
                Text(
                  state.scannedPaths.join(', '),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
            ],
          ),
        ),
      );
    }

    final likedTracks = state.tracks
        .where((track) => likedState.trackIds.contains(track.id))
        .toList(growable: false);

    return ListView.builder(
      itemCount: state.tracks.length + (likedTracks.isEmpty ? 0 : 1),
      itemBuilder: (context, index) {
        if (likedTracks.isNotEmpty && index == 0) {
          return ListTile(
            leading: const Icon(Icons.favorite),
            title: const Text('Liked Songs'),
            subtitle: Text('${likedTracks.length} songs'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => _LikedSongsView(
                    tracks: likedTracks,
                    playbackController: playbackController,
                  ),
                ),
              );
            },
          );
        }

        final trackIndex = likedTracks.isNotEmpty ? index - 1 : index;
        final track = state.tracks[trackIndex];
        final isLiked = likedState.trackIds.contains(track.id);
        final folderId = virtualState.assignments[track.id];
        final folder = folderId != null ? folderById[folderId] : null;
        final locationLabel = folder == null
            ? null
            : folder.type == VirtualFolderType.album
            ? 'Album: ${folder.name}'
            : 'Folder: ${folder.name}';
        return _TrackListTile(
          track: track,
          isLiked: isLiked,
          locationLabel: locationLabel,
          onTap: () => playbackController.play(track, queue: state.tracks),
        );
      },
    );
  }
}

/// Simple track list tile
class _TrackListTile extends StatelessWidget {
  final UiTrack track;
  final VoidCallback onTap;
  final bool isLiked;
  final String? locationLabel;

  const _TrackListTile({
    required this.track,
    required this.onTap,
    required this.isLiked,
    this.locationLabel,
  });

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
      subtitle: locationLabel == null
          ? Text(
              track.artistName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[500]),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[500]),
                ),
                Text(
                  locationLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLiked ? Icons.favorite : Icons.favorite_border,
            size: 16,
            color: isLiked ? Colors.red : Colors.grey,
          ),
          const SizedBox(width: 8),
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

class _LikedSongsView extends StatelessWidget {
  final List<UiTrack> tracks;
  final PlaybackController playbackController;

  const _LikedSongsView({
    required this.tracks,
    required this.playbackController,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Liked Songs')),
      body: ListView.builder(
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          return ListTile(
            title: Text(track.title, maxLines: 1),
            subtitle: Text(track.artistName, maxLines: 1),
            onTap: () => playbackController.play(track, queue: tracks),
          );
        },
      ),
    );
  }
}
