import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sicby/state/playback_controller.dart';

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = const QueueList();

    if (embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: content,
    );
  }
}

class QueueList extends ConsumerWidget {
  const QueueList({super.key, this.scrollController});

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackState = ref.watch(playbackControllerProvider);
    final playbackController = ref.read(playbackControllerProvider.notifier);
    final queue = playbackState.queue;
    final currentIndex = playbackState.queueIndex;

    if (queue.isEmpty) {
      return const Center(child: Text('Queue is empty'));
    }

    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      scrollController: scrollController,
      padding: const EdgeInsets.only(bottom: 24),
      onReorder: (oldIndex, newIndex) {
        playbackController.reorderQueue(oldIndex, newIndex);
      },
      itemCount: queue.length,
      itemBuilder: (context, index) {
        final track = queue[index];
        final isPlaying = index == currentIndex;
        final scheme = Theme.of(context).colorScheme;

        return ListTile(
          key: ValueKey(track.id),
          leading: isPlaying
              ? Icon(Icons.volume_up, color: scheme.primary)
              : Text(
                  '${index + 1}',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
          title: Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isPlaying ? scheme.primary : null,
              fontWeight: isPlaying ? FontWeight.bold : null,
            ),
          ),
          subtitle: Text(
            track.artistName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          trailing: ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.drag_handle, color: scheme.onSurfaceVariant),
          ),
          onTap: () {
            playbackController.play(track, queue: queue);
          },
        );
      },
    );
  }
}
