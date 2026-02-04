/// SicBy Queue Screen
///
/// Responsibility:
/// - Display upcoming tracks in playback queue
/// - Allow reordering (drag & drop)
/// - Allow removal of tracks
///
/// State Dependencies:
/// - QueueController: provides List<UiTrack> (queue items)
/// - PlaybackController: provides current track index
///
/// Actions:
/// - onReorder(oldIndex, newIndex) -> QueueController.reorder()
/// - onRemove(trackId) -> QueueController.remove(trackId)
/// - onTrackTap(index) -> PlaybackController.skipTo(index)
/// - onClearQueue() -> QueueController.clear()
///
/// Layout:
/// - Mobile: Full screen or bottom sheet
/// - Desktop: Side panel in Now Playing view
///
/// Status: Placeholder - implementation pending

import 'package:flutter/material.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Implement with ReorderableListView
    return const Scaffold(body: Center(child: Text('Queue - Placeholder')));
  }
}
