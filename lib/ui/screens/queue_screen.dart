import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sicby/state/playback_controller.dart';

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackState = ref.watch(playbackControllerProvider);
    final playbackController = ref.read(playbackControllerProvider.notifier);
    final queue = playbackState.queue;
    final currentIndex = playbackState.queueIndex;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: queue.isEmpty
          ? const Center(child: Text('Queue is empty'))
          : ReorderableListView.builder(
              padding: const EdgeInsets.only(bottom: 100), // MiniPlayer space
              onReorder: (oldIndex, newIndex) {
                playbackController.reorderQueue(oldIndex, newIndex);
              },
              itemCount: queue.length,
              itemBuilder: (context, index) {
                final track = queue[index];
                final isPlaying = index == currentIndex;

                return ListTile(
                  key: ValueKey('${track.id}_$index'),
                  leading: isPlaying
                      ? const Icon(Icons.volume_up, color: Colors.green)
                      : Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                  title: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isPlaying ? Colors.green : null,
                      fontWeight: isPlaying ? FontWeight.bold : null,
                    ),
                  ),
                  subtitle: Text(
                    track.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.drag_handle, color: Colors.grey),
                  onTap: () {
                    playbackController.play(track, queue: queue);
                  },
                );
              },
            ),
    );
  }
}
