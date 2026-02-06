import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sicby/state/playback_controller.dart';
import 'package:sicby/state/ui_models.dart';
import 'package:sicby/state/virtual_library_controller.dart';
import 'package:sicby/state/virtual_library_models.dart';

class VirtualAlbumScreen extends ConsumerWidget {
  const VirtualAlbumScreen({
    super.key,
    required this.album,
    required this.tracks,
  });

  final VirtualFolder album;
  final List<UiTrack> tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackController = ref.read(playbackControllerProvider.notifier);
    final virtualController = ref.read(virtualLibraryProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(album.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${tracks.length} songs',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ),
      body: tracks.isEmpty
          ? const Center(child: Text('No songs in this album'))
          : ListView.builder(
              itemCount: tracks.length,
              itemBuilder: (context, index) {
                final track = tracks[index];
                return ListTile(
                  leading: _ArtworkTile(path: track.artworkPath),
                  title: Text(track.title, maxLines: 1),
                  subtitle: Text(track.artistName, maxLines: 1),
                  onTap: () => playbackController.play(track, queue: tracks),
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
                                leading: const Icon(
                                  Icons.remove_circle_outline,
                                ),
                                title: const Text('Remove from album'),
                                onTap: () async {
                                  await virtualController.assignTrack(
                                    track.id,
                                    null,
                                  );
                                  if (!context.mounted) return;
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
    );
  }
}

class _ArtworkTile extends StatelessWidget {
  const _ArtworkTile({this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(Icons.music_note, color: scheme.onSurfaceVariant),
    );

    if (path?.isEmpty ?? true) {
      return fallback;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.file(
        File(path!),
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}
