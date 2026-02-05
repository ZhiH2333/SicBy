import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sicby/state/local_library_provider.dart';
import 'package:sicby/state/liked_songs_provider.dart';
import 'package:sicby/state/playback_controller.dart';

class FileManagerScreen extends ConsumerWidget {
  const FileManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(localLibraryProvider);
    final libraryController = ref.read(localLibraryProvider.notifier);
    final playbackController = ref.read(playbackControllerProvider.notifier);
    final likeController = ref.read(likeControllerProvider.notifier);
    final likedState = ref.watch(likeControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Files'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => libraryController.scanFromSettings(),
            tooltip: 'Rescan',
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => libraryController.pickAndAddFolder(),
            tooltip: 'Add Folder',
          ),
        ],
      ),
      body: ListView(
        children: [
          _Section(
            title: 'Folders',
            children: [
              if (libraryState.scannedPaths.isEmpty)
                const ListTile(
                  title: Text('No folders added'),
                ),
              ...libraryState.scannedPaths.map(
                (path) => ListTile(
                  title: Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => libraryController.removeLibraryPath(path),
                  ),
                ),
              ),
            ],
          ),
          _Section(
            title: 'Tracks',
            children: [
              if (libraryState.isLoading)
                const ListTile(
                  title: Text('Scanning...'),
                ),
              if (!libraryState.isLoading && libraryState.tracks.isEmpty)
                const ListTile(
                  title: Text('No tracks found'),
                ),
              ...libraryState.tracks.map(
                (track) {
                  final isLiked = likedState.trackIds.contains(track.id);
                  return ListTile(
                    title: Text(track.title, maxLines: 1),
                    subtitle: Text(track.artistName, maxLines: 1),
                    trailing: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : null,
                    ),
                    onTap: () => playbackController.play(
                      track,
                      queue: libraryState.tracks,
                    ),
                    onLongPress: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) {
                          return SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.queue_music),
                                  title: const Text('Add to queue'),
                                  onTap: () {
                                    playbackController.addToQueue(track);
                                    Navigator.of(context).pop();
                                  },
                                ),
                                ListTile(
                                  leading: Icon(
                                    isLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                  ),
                                  title: Text(
                                    isLiked ? 'Remove from liked' : 'Add to liked',
                                  ),
                                  onTap: () {
                                    likeController.toggleLike(track.id);
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
