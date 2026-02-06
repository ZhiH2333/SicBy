import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sicby/state/playback_controller.dart';
import 'package:sicby/state/service_providers.dart';
import 'package:sicby/state/settings_controller.dart';
import 'package:sicby/state/ui_models.dart';
import 'package:sicby/domain/repeat_mode.dart';
import 'package:sicby/state/liked_songs_provider.dart';
import 'package:sicby/state/metadata_overrides_controller.dart';
import 'package:sicby/state/metadata_overrides_models.dart';
import 'package:sicby/ui/screens/queue_screen.dart';
import 'package:sicby/ui/widgets/now_playing_modals.dart';
import 'package:sicby/services/local_lyrics_service.dart';

/// Now Playing Screen - full playback UI
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key, this.asSheet = false});

  final bool asSheet;

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  bool _showLyrics = false;
  Future<List<LyricLine>>? _lyricsFuture;
  String? _lyricsTrackId;

  void _toggleLyrics() {
    final enabled = ref.read(settingsControllerProvider).settings.lyricsEnabled;
    if (!enabled) return;
    setState(() => _showLyrics = !_showLyrics);
  }

  void _ensureLyricsFuture(UiTrack? track, TrackMetadataOverride? override) {
    if (track == null) return;
    if (_lyricsTrackId != track.id) {
      _lyricsTrackId = track.id;
      final overrideLyrics = override?.lyrics;
      if (overrideLyrics != null && overrideLyrics.trim().isNotEmpty) {
        final service = ref.read(localLyricsServiceProvider);
        _lyricsFuture = Future.value(service.parseText(overrideLyrics));
        return;
      }
      _lyricsFuture = ref.read(localLyricsServiceProvider).load(track.locator);
    }
  }

  UiTrack? _applyOverride(UiTrack? track, TrackMetadataOverride? override) {
    if (track == null || override == null) return track;
    String? clean(String? value) {
      if (value == null) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return UiTrack(
      id: track.id,
      title: clean(override.title) ?? track.title.trim(),
      artistName: clean(override.artist) ?? track.artistName.trim(),
      albumName: clean(override.album) ?? track.albumName?.trim(),
      duration: track.duration,
      locator: track.locator,
      filePath: track.filePath,
      artworkPath: override.artworkPath ?? track.artworkPath,
      availability: track.availability,
    );
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
                final overrides = ref.read(metadataOverridesProvider.notifier);
                overrides.updateOverride(
                  track.id,
                  title: titleController.text.trim(),
                  artist: artistController.text.trim(),
                  album: albumController.text.trim(),
                );
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showEditLyricsDialog(BuildContext context, UiTrack track) {
    final overrides = ref.read(metadataOverridesProvider);
    final existing = overrides[track.id]?.lyrics ?? '';
    final controller = TextEditingController(text: existing);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Lyrics'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Paste lyrics or LRC text',
            ),
            keyboardType: TextInputType.multiline,
            maxLines: 8,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await ref
                    .read(metadataOverridesProvider.notifier)
                    .clearLyrics(track.id);
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: const Text('Clear'),
            ),
            FilledButton(
              onPressed: () async {
                await ref
                    .read(metadataOverridesProvider.notifier)
                    .updateOverride(track.id, lyrics: controller.text.trim());
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showEditCoverArtDialog(BuildContext context, UiTrack track) {
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
                onTap: () async {
                  Navigator.of(context).pop();
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.image,
                    withData: true,
                  );
                  if (result == null || result.files.isEmpty) return;
                  final file = result.files.first;
                  final cache = ref.read(artworkCacheServiceProvider);
                  String? path;
                  if (file.path != null) {
                    path = await cache.saveArtworkFile(
                      track.id,
                      File(file.path!),
                    );
                  } else if (file.bytes != null) {
                    path = await cache.saveArtworkBytes(track.id, file.bytes!);
                  }
                  if (path == null) return;
                  await ref
                      .read(metadataOverridesProvider.notifier)
                      .updateOverride(track.id, artworkPath: path);
                },
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Search Online'),
                onTap: () {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Online search is disabled for local-only'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Remove Art'),
                textColor: Colors.red,
                iconColor: Colors.red,
                onTap: () async {
                  Navigator.of(context).pop();
                  await ref
                      .read(metadataOverridesProvider.notifier)
                      .clearArtwork(track.id);
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
    final scheme = Theme.of(context).colorScheme;
    final playbackState = ref.watch(playbackControllerProvider);
    final playbackController = ref.read(playbackControllerProvider.notifier);
    final settingsState = ref.watch(settingsControllerProvider);
    final overridesState = ref.watch(metadataOverridesProvider);

    final track =
        playbackState.currentTrack ??
        playbackState.pendingTrack ??
        playbackState.selectedTrack;
    final override = track == null ? null : overridesState[track.id];
    final effectiveTrack = _applyOverride(track, override);
    final lyricsEnabled = settingsState.settings.lyricsEnabled;

    if (_showLyrics && !lyricsEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _showLyrics = false);
        }
      });
    }

    if (_showLyrics && lyricsEnabled) {
      _ensureLyricsFuture(effectiveTrack, override);
    }

    final content = SafeArea(
      top: true,
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
                        case 'stop':
                          playbackController.stop();
                          break;
                        case 'metadata':
                          _showEditMetadataDialog(context, track);
                          break;
                        case 'cover':
                          _showEditCoverArtDialog(context, track);
                          break;
                        case 'lyrics':
                          _showEditLyricsDialog(context, track);
                          break;
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'stop',
                            child: ListTile(
                              leading: Icon(Icons.stop_circle_outlined),
                              title: Text('Stop playback'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeInOut,
                        switchOutCurve: Curves.easeInOut,
                        child: _showLyrics && lyricsEnabled
                            ? _LyricsPanel(
                                key: ValueKey(
                                  'lyrics_${effectiveTrack?.id ?? 'empty'}',
                                ),
                                track: effectiveTrack,
                                lyricsFuture: _lyricsFuture,
                                position: playbackState.position,
                              )
                            : _ArtworkPanel(
                                key: ValueKey(
                                  'art_${effectiveTrack?.id ?? 'empty'}',
                                ),
                                track: effectiveTrack,
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            child: Column(
                              key: ValueKey(effectiveTrack?.id ?? 'empty'),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  effectiveTrack?.title ?? 'Not Playing',
                                  style: TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.1,
                                    color: scheme.onSurface,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  effectiveTrack?.artistName ?? '',
                                  style: TextStyle(
                                    fontSize: 13,
                                    letterSpacing: 0.2,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            effectiveTrack != null &&
                                    ref
                                        .watch(likeControllerProvider)
                                        .trackIds
                                        .contains(effectiveTrack.id)
                                ? Icons.favorite
                                : Icons.favorite_border,
                          ),
                          color: scheme.onSurface,
                          onPressed: effectiveTrack != null
                              ? () => ref
                                    .read(likeControllerProvider.notifier)
                                    .toggleLike(effectiveTrack.id)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SeekBar(
                      position: playbackState.position,
                      duration:
                          playbackState.duration == Duration.zero &&
                              effectiveTrack != null
                          ? effectiveTrack.duration
                          : playbackState.duration,
                      onSeek: (percent) {
                        if (effectiveTrack == null ||
                            playbackState.downloadStatus ==
                                DownloadStatus.downloading) {
                          return;
                        }
                        playbackController.seekTo(percent);
                      },
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final centerSize = min(
                          70.0,
                          constraints.maxWidth * 0.22,
                        );
                        final iconSize = centerSize * 0.5;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.shuffle,
                                color: playbackState.shuffleEnabled
                                    ? scheme.onSurface
                                    : scheme.onSurfaceVariant,
                              ),
                              onPressed: effectiveTrack != null
                                  ? () => playbackController.toggleShuffle()
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              iconSize: 34,
                              icon: const Icon(Icons.skip_previous),
                              onPressed:
                                  effectiveTrack != null &&
                                      playbackState.downloadStatus !=
                                          DownloadStatus.downloading
                                  ? () => playbackController.previous()
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: centerSize,
                              height: centerSize,
                              decoration: BoxDecoration(
                                color: scheme.onSurface,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                iconSize: iconSize,
                                color: scheme.surface,
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 160),
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: ScaleTransition(
                                        scale: Tween<double>(
                                          begin: 0.92,
                                          end: 1.0,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child:
                                      playbackState.isBuffering ||
                                          playbackState.downloadStatus ==
                                              DownloadStatus.downloading
                                      ? SizedBox(
                                          key: const ValueKey('loading'),
                                          width: iconSize,
                                          height: iconSize,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: scheme.surface,
                                          ),
                                        )
                                      : Icon(
                                          playbackState.isPlaying
                                              ? Icons.pause
                                              : Icons.play_arrow,
                                          key: ValueKey(
                                            playbackState.isPlaying
                                                ? 'pause'
                                                : 'play',
                                          ),
                                        ),
                                ),
                                onPressed:
                                    effectiveTrack != null &&
                                        playbackState.downloadStatus !=
                                            DownloadStatus.downloading
                                    ? () => playbackController.togglePlayPause()
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              iconSize: 34,
                              icon: const Icon(Icons.skip_next),
                              onPressed:
                                  effectiveTrack != null &&
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
                                color:
                                    playbackState.repeatMode != RepeatMode.off
                                    ? scheme.onSurface
                                    : scheme.onSurfaceVariant,
                              ),
                              onPressed: effectiveTrack != null
                                  ? () => playbackController.cycleRepeatMode()
                                  : null,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    _VolumeRow(
                      value: playbackState.volume,
                      onChanged: playbackController.setVolume,
                    ),
                    const SizedBox(height: 8),
                    BottomActionBar(
                      track: effectiveTrack,
                      showLyrics: _showLyrics,
                      lyricsEnabled: lyricsEnabled,
                      onToggleLyrics: _toggleLyrics,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    return Scaffold(backgroundColor: scheme.surface, body: content);
  }
}

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({
    super.key,
    required this.track,
    required this.showLyrics,
    required this.lyricsEnabled,
    required this.onToggleLyrics,
  });

  final UiTrack? track;
  final bool showLyrics;
  final bool lyricsEnabled;
  final VoidCallback onToggleLyrics;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: true,
      top: false,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.devices),
              color: scheme.onSurfaceVariant,
              onPressed: track != null ? () => showDevicePicker(context) : null,
              tooltip: 'Devices',
            ),
            IconButton(
              icon: const Icon(Icons.queue_music),
              color: scheme.onSurface,
              onPressed: track != null
                  ? () => showQueueSheet(
                      context,
                      (controller) => QueueList(scrollController: controller),
                    )
                  : null,
              tooltip: 'Queue',
            ),
            IconButton(
              icon: Icon(showLyrics ? Icons.lyrics : Icons.lyrics_outlined),
              color: showLyrics ? scheme.primary : scheme.onSurfaceVariant,
              onPressed: track != null && lyricsEnabled ? onToggleLyrics : null,
              tooltip: lyricsEnabled ? 'Lyrics' : 'Lyrics disabled in settings',
            ),
            IconButton(
              icon: const Icon(Icons.share),
              color: scheme.onSurfaceVariant,
              onPressed: track != null ? () => showShareModal(context) : null,
              tooltip: 'Share',
            ),
          ],
        ),
      ),
    );
  }
}

class _ArtworkPanel extends StatelessWidget {
  const _ArtworkPanel({super.key, required this.track});

  final UiTrack? track;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FractionallySizedBox(
      widthFactor: 0.9,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.48,
        ),
        child: AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              color: scheme.surfaceContainerHighest,
              child: track?.artworkPath != null
                  ? Image.file(
                      File(track!.artworkPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(
                          Icons.music_note,
                          size: 96,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(
                        Icons.music_note,
                        size: 96,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LyricsPanel extends StatelessWidget {
  const _LyricsPanel({
    super.key,
    required this.track,
    required this.lyricsFuture,
    required this.position,
  });

  final UiTrack? track;
  final Future<List<LyricLine>>? lyricsFuture;
  final Duration position;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outline),
      ),
      child: track == null
          ? const Center(child: Text('No track playing'))
          : FutureBuilder<List<LyricLine>>(
              future: lyricsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final lines = snapshot.data ?? const <LyricLine>[];
                if (lines.isEmpty) {
                  return const Center(
                    child: Text('No lyrics found for this track'),
                  );
                }

                return _LyricsList(lines: lines, position: position);
              },
            ),
    );
  }
}

class _LyricsList extends StatefulWidget {
  const _LyricsList({required this.lines, required this.position});

  final List<LyricLine> lines;
  final Duration position;

  @override
  State<_LyricsList> createState() => _LyricsListState();
}

class _LyricsListState extends State<_LyricsList> {
  final ScrollController _controller = ScrollController();
  int _activeIndex = -1;

  @override
  void initState() {
    super.initState();
    _activeIndex = _activeIndexFor(widget.position);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
  }

  @override
  void didUpdateWidget(covariant _LyricsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIndex = _activeIndexFor(widget.position);
    if (nextIndex != _activeIndex) {
      _activeIndex = nextIndex;
      _scrollToActive();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _activeIndexFor(Duration position) {
    var index = -1;
    for (var i = 0; i < widget.lines.length; i++) {
      final timestamp = widget.lines[i].timestamp;
      if (timestamp == Duration.zero) {
        continue;
      }
      if (timestamp <= position) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }

  void _scrollToActive() {
    if (_activeIndex < 0 || !_controller.hasClients) return;
    final offset = (_activeIndex * 36).toDouble();
    _controller.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      controller: _controller,
      itemExtent: 36,
      itemCount: widget.lines.length,
      itemBuilder: (context, index) {
        final line = widget.lines[index];
        final isActive = index == _activeIndex;
        return AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: isActive ? scheme.onSurface : scheme.onSurfaceVariant,
            fontSize: isActive ? 16 : 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
          child: Text(
            line.text.isEmpty ? '...' : line.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}

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
    final scheme = Theme.of(context).colorScheme;
    final safeDuration = duration.inMilliseconds > 0
        ? duration.inMilliseconds
        : 1;
    final safePosition = position.inMilliseconds.clamp(0, safeDuration);
    final percent = duration.inMilliseconds > 0
        ? safePosition / safeDuration
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
            onChanged: duration.inMilliseconds > 0 ? onSeek : null,
            activeColor: scheme.primary,
            inactiveColor: scheme.surfaceContainerHighest,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              Text(
                _formatDuration(duration),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
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

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.volume_down, size: 18, color: scheme.onSurfaceVariant),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: value.clamp(0.0, 1.0),
              onChanged: onChanged,
              activeColor: scheme.primary,
              inactiveColor: scheme.surfaceContainerHighest,
            ),
          ),
        ),
        Icon(Icons.volume_up, size: 18, color: scheme.onSurfaceVariant),
      ],
    );
  }
}
