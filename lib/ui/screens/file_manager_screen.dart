import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sicby/state/library_controller.dart';
import 'package:sicby/state/ui_models.dart';
import 'package:sicby/state/like_controller.dart';

/// File Manager - UI-only view for local folders and tracks
class FileManagerScreen extends ConsumerWidget {
  const FileManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('File Manager'),
      ),
      body: _buildBody(context, ref, state),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, UiLibraryState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.tracks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            state.currentFolderPath != null
                ? 'No audio files found in the selected folder.'
                : 'Select a music folder in Settings to manage files.',
            style: TextStyle(color: Colors.grey[400]),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.currentFolderPath != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              state.currentFolderPath!,
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
        Expanded(
          child: ListView.separated(
            separatorBuilder: (_, __) => Divider(color: Colors.grey[850], height: 1),
            itemCount: state.tracks.length,
            itemBuilder: (context, index) {
              final track = state.tracks[index];
              return _FileTrackTile(track: track);
            },
          ),
        ),
      ],
    );
  }
}

class _FileTrackTile extends ConsumerWidget {
  final UiTrack track;

  const _FileTrackTile({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLiked = ref.watch(likeControllerProvider).contains(track.id);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.music_note, color: Colors.white54),
      ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(track.artistName, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
            color: isLiked ? Theme.of(context).colorScheme.primary : Colors.grey[400],
            onPressed: () => ref.read(likeControllerProvider.notifier).toggleLike(track.id),
            tooltip: 'Like',
          ),
          if (track.duration != Duration.zero)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(track.durationFormatted, style: TextStyle(color: Colors.grey[500])),
            ),
        ],
      ),
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Play ${track.title}'))),
      onLongPress: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.black,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        builder: (context) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.play_arrow),
                title: const Text('Play now'),
                onTap: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Play ${track.title}')));
                },
              ),
              ListTile(
                leading: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
                title: Text(isLiked ? 'Remove from Liked' : 'Add to Liked'),
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(likeControllerProvider.notifier).toggleLike(track.id);
                },
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}
