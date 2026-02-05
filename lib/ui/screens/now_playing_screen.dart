import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sicby/state/playback_controller.dart';
import 'package:sicby/state/ui_models.dart';
import 'package:sicby/domain/repeat_mode.dart';
import 'package:sicby/state/liked_songs_provider.dart';
import 'package:sicby/ui/screens/queue_screen.dart';
import 'package:sicby/ui/widgets/now_playing_modals.dart';

/// Now Playing Screen - full playback UI
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  bool _showLyrics = false;

  void _toggleLyrics() {
    setState(() => _showLyrics = !_showLyrics);
  }

  void _showEditMetadataDialog(BuildContext context, UiTrack track) {
    final titleController = TextEditingController(text: track.title);
    final artistController = TextEditingController(text: track.artistName);
    final albumController = TextEditingController(text: track.albumName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Metadata'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: artistController,
                decoration: const InputDecoration(labelText: 'Artist'),
              ),
              TextField(
                controller: albumController,
                decoration: const InputDecoration(labelText: 'Album'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                // TODO: Save changes to local storage via controller
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Metadata updated (Local only)'),
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showEditCoverArtDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Cover Art'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Select from Gallery'),
                onTap: () {
                  Navigator.of(context).pop();
                  // TODO: Pick image
                },
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Search Online'),
                onTap: () {
                  Navigator.of(context).pop();
                  // TODO: Search online
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Remove Art'),
                textColor: Colors.red,
                iconColor: Colors.red,
                onTap: () {
                  Navigator.of(context).pop();
                  // TODO: Remove art
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final playbackState = ref.watch(playbackControllerProvider);
    final playbackController = ref.read(playbackControllerProvider.notifier);

    final track = playbackState.currentTrack;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        // Reserve bottom safe area only for BottomActionBar below
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Expanded(
                    child: Text(
                      'Now Playing',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (track == null) return;
                      switch (value) {
                        case 'metadata':
                          _showEditMetadataDialog(context, track);
                          break;
                        case 'cover':
                          _showEditCoverArtDialog(context);
                          break;
                        case 'lyrics':
                          if (!_showLyrics) _toggleLyrics();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Edit Lyrics - Coming Soon'),
                            ),
                          );
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'metadata',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit metadata'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'cover',
                        child: ListTile(
                          leading: Icon(Icons.image_outlined),
                          title: Text('Edit cover art'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'lyrics',
                        child: ListTile(
                          leading: Icon(Icons.lyrics_outlined),
                          title: Text('Edit lyrics'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Album artwork - fixed layout with AnimatedSwitcher to
                    // avoid jitter when track changes. We keep a stable size
                    // using AspectRatio inside a FractionallySizedBox.
                    FractionallySizedBox(
                      widthFactor: 0.9,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 240),
                          switchInCurve: Curves.easeInOut,
                          switchOutCurve: Curves.easeInOut,
                          child: ClipRRect(
                            key: ValueKey(track?.id ?? 'empty_art'),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              color: Colors.grey[850],
                              child: track?.artworkPath != null
                                  ? Image.file(
                                      // artworkPath is expected to be a local file path
                                      // (UI-only: if not available we fall back)
                                      File(track!.artworkPath!),
                                      fit: BoxFit.cover,
                                    )
                                  : const Icon(
                                      Icons.music_note,
                                      size: 96,
                                      color: Colors.grey,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track?.title ?? 'Not Playing',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                track?.artistName ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withAlpha(153),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Like / Favorite button - connected to persisted liked songs provider
                        IconButton(
                          icon: Icon(
                            track != null && ref.watch(likeControllerProvider).trackIds.contains(track.id)
                                ? Icons.favorite
                                : Icons.favorite_border,
                          ),
                          color: Colors.white,
                          onPressed: track != null
                              ? () => ref.read(likeControllerProvider.notifier).toggleLike(track.id)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _SeekBar(
                      position: playbackState.position,
                      duration:
                          playbackState.duration == Duration.zero && track != null
                              ? track.duration
                              : playbackState.duration,
                      onSeek: (percent) {
                        if (track == null ||
                            playbackState.downloadStatus ==
                                DownloadStatus.downloading) {
                          return;
                        }
                        playbackController.seekTo(percent);
                      },
                    ),
                    const SizedBox(height: 32),
                      // Playback controls layout: left/right groups with a dominant
                      // center play button to match Spotify spacing.
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.shuffle,
                                    color: playbackState.shuffleEnabled
                                        ? Colors.white
                                        : Colors.white.withAlpha(153),
                                  ),
                                  onPressed: track != null
                                      ? () => playbackController.toggleShuffle()
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  iconSize: 36,
                                  icon: const Icon(Icons.skip_previous),
                                  onPressed: track != null &&
                                          playbackState.downloadStatus !=
                                              DownloadStatus.downloading
                                      ? () => playbackController.previous()
                                      : null,
                                ),
                              ],
                            ),
                          ),
                          // Center Play/Pause (dominant)
                          Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              iconSize: 36,
                              color: Colors.black,
                              icon: playbackState.isBuffering ||
                                      playbackState.downloadStatus ==
                                          DownloadStatus.downloading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                  : Icon(
                                      playbackState.isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                    ),
                              onPressed: track != null &&
                                      playbackState.downloadStatus !=
                                          DownloadStatus.downloading
                                  ? () => playbackController.togglePlayPause()
                                  : null,
                            ),
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                const SizedBox(width: 12),
                                IconButton(
                                  iconSize: 36,
                                  icon: const Icon(Icons.skip_next),
                                  onPressed: track != null &&
                                          playbackState.downloadStatus !=
                                              DownloadStatus.downloading
                                      ? () => playbackController.next()
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(
                                    playbackState.repeatMode == RepeatMode.one
                                        ? Icons.repeat_one
                                        : Icons.repeat,
                                    color: playbackState.repeatMode !=
                                            RepeatMode.off
                                        ? Colors.white
                                        : Colors.white.withAlpha(153),
                                  ),
                                  onPressed: track != null
                                      ? () => playbackController.cycleRepeatMode()
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 32),
                    // BottomActionBar moved out of scroll area to guarantee
                    // isolation from progress bar and consistent hit testing.
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      // Bottom action bar is outside the main SafeArea and gets its own
      // SafeArea(bottom: true) so only it respects the device bottom inset.
      bottomSheet: BottomActionBar(
        track: track,
        showLyrics: _showLyrics,
        onToggleLyrics: _toggleLyrics,
      ),
    );
  }
}

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.track,
    required this.showLyrics,
    required this.onToggleLyrics,
  });

  final dynamic track;
  final bool showLyrics;
  final VoidCallback onToggleLyrics;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: true,
      top: false,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.devices),
              color: Colors.white.withAlpha(153),
              onPressed: track != null ? () {} : null,
              tooltip: 'Devices',
            ),
            // Ensure queue button has a full hit target and no overflow
            SizedBox(
              height: 48,
              width: 48,
              child: IconButton(
                icon: const Icon(Icons.queue_music),
                color: Colors.white,
                onPressed: track != null
                    ? () => showQueueSheet(context, const QueueScreen())
                    : null,
                tooltip: 'Queue',
              ),
            ),
            IconButton(
              icon: Icon(showLyrics ? Icons.lyrics : Icons.lyrics_outlined),
              color: showLyrics
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white.withAlpha(153),
              onPressed: track != null ? onToggleLyrics : null,
              tooltip: 'Lyrics',
            ),
            IconButton(
              icon: const Icon(Icons.share),
              color: Colors.white.withAlpha(153),
              onPressed: track != null ? () {} : null,
              tooltip: 'Share',
            ),
          ],
        ),
      ),
    );
  }
}

// Removed unused _LyricsView placeholder to reduce visual noise. Lyrics are
// shown via the `showLyricsModal` bottom sheet in `now_playing_modals.dart`.

/// Seek bar with time display
class _SeekBar extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<double> onSeek;

  const _SeekBar({
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final percent = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: percent.clamp(0.0, 1.0),
            onChanged: onSeek,
            activeColor: Colors.white,
            inactiveColor: Colors.grey[700],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              Text(
                _formatDuration(duration),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
