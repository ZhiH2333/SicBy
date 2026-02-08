import 'dart:io';

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
  Widget build(BuildContext context) {
    final libraryState = ref.watch(localLibraryProvider);
    final libraryController = ref.read(localLibraryProvider.notifier);
    final playbackController = ref.read(playbackControllerProvider.notifier);
    final likedState = ref.watch(likeControllerProvider);
    final virtualState = ref.watch(virtualLibraryProvider);
    final folderById = {
      for (final folder in virtualState.folders) folder.id: folder,
    };

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Library'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => libraryController.pickAndAddFolder(context),
              tooltip: 'Add Folder',
            ),
          ],
          bottom: TabBar(
            dividerHeight: 0,
            dividerColor: Colors.transparent,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant,
            tabs: [
              _LibraryTab(icon: Icons.music_note, label: 'Tracks'),
              _LibraryTab(icon: Icons.album_outlined, label: 'Albums'),
              _LibraryTab(icon: Icons.mic_none, label: 'Artists'),
              _LibraryTab(icon: Icons.folder_outlined, label: 'Folders'),
            ],
          ),
        ),
        body: _buildBody(
          context,
          libraryState,
          playbackController,
          likedState,
          virtualState,
          folderById,
        ),
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

    return TabBarView(
      children: [
        _SongsView(
          tracks: state.tracks,
          likedTracks: likedTracks,
          playbackController: playbackController,
          likedState: likedState,
          virtualState: virtualState,
          folderById: folderById,
        ),
        _AlbumsView(
          tracks: state.tracks,
          playbackController: playbackController,
        ),
        _ArtistsView(
          tracks: state.tracks,
          playbackController: playbackController,
        ),
        _FoldersView(
          tracks: state.tracks,
          playbackController: playbackController,
        ),
      ],
    );
  }
}

class _LibraryTab extends StatelessWidget {
  const _LibraryTab({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _SongsView extends StatelessWidget {
  final List<UiTrack> tracks;
  final List<UiTrack> likedTracks;
  final PlaybackController playbackController;
  final LikedSongsState likedState;
  final VirtualLibraryState virtualState;
  final Map<String, VirtualFolder> folderById;

  const _SongsView({
    required this.tracks,
    required this.likedTracks,
    required this.playbackController,
    required this.likedState,
    required this.virtualState,
    required this.folderById,
  });

  @override
  Widget build(BuildContext context) {
    final headerCount = (likedTracks.isEmpty ? 0 : 1);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: tracks.length + headerCount,
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

        final trackIndex = index - headerCount;
        final track = tracks[trackIndex];
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
          onDetails: () => _showTrackDetails(context, track),
          onTap: () => playbackController.play(track, queue: tracks),
        );
      },
    );
  }
}

class _AlbumEntry {
  final String name;
  final List<UiTrack> tracks;

  _AlbumEntry({required this.name, required this.tracks});

  int get count => tracks.length;

  String? get artworkPath => tracks
      .firstWhere(
        (t) => t.artworkPath?.isNotEmpty ?? false,
        orElse: () => tracks.first,
      )
      .artworkPath;
}

class _AlbumsView extends StatelessWidget {
  final List<UiTrack> tracks;
  final PlaybackController playbackController;

  const _AlbumsView({required this.tracks, required this.playbackController});

  @override
  Widget build(BuildContext context) {
    final albums = _groupByAlbum(tracks);
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 900
        ? 4
        : width >= 680
        ? 3
        : 2;
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.78,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return _AlbumCard(
          album: album,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _AlbumTracksView(
                  title: album.name,
                  tracks: album.tracks,
                  playbackController: playbackController,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ArtistEntry {
  final String name;
  final List<UiTrack> tracks;

  _ArtistEntry({required this.name, required this.tracks});

  int get count => tracks.length;
}

class _ArtistsView extends StatelessWidget {
  final List<UiTrack> tracks;
  final PlaybackController playbackController;

  const _ArtistsView({required this.tracks, required this.playbackController});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final artists = _groupByArtist(tracks);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: scheme.surfaceContainerHighest,
            child: Text(
              artist.name.isNotEmpty ? artist.name[0].toUpperCase() : '?',
            ),
          ),
          title: Text(artist.name, textAlign: TextAlign.left, maxLines: 1),
          subtitle: Text('${artist.count} songs'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _ArtistTracksView(
                  title: artist.name,
                  tracks: artist.tracks,
                  playbackController: playbackController,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FolderEntry {
  final String path;
  final List<UiTrack> tracks;

  _FolderEntry({required this.path, required this.tracks});

  int get count => tracks.length;
}

class _FoldersView extends StatelessWidget {
  final List<UiTrack> tracks;
  final PlaybackController playbackController;

  const _FoldersView({required this.tracks, required this.playbackController});

  @override
  Widget build(BuildContext context) {
    final folders = _groupByFolder(tracks);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folder = folders[index];
        return ListTile(
          leading: const Icon(Icons.folder),
          title: Text(
            folder.path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text('${folder.count} songs'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _FolderTracksView(
                  title: folder.path,
                  tracks: folder.tracks,
                  playbackController: playbackController,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Simple track list tile
class _TrackListTile extends StatelessWidget {
  final UiTrack track;
  final VoidCallback onTap;
  final VoidCallback onDetails;
  final bool isLiked;
  final String? locationLabel;

  const _TrackListTile({
    required this.track,
    required this.onTap,
    required this.onDetails,
    required this.isLiked,
    this.locationLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final artworkPath = track.artworkPath;
    final durationText = track.duration != Duration.zero
        ? ' \u2022 ${track.durationFormatted}'
        : '';
    return ListTile(
      leading: _ArtworkTile(path: artworkPath),
      title: Text(
        track.title,
        textAlign: TextAlign.left,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: locationLabel == null
          ? Text(
              '${track.artistName}$durationText',
              textAlign: TextAlign.left,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.onSurfaceVariant),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${track.artistName}$durationText',
                  textAlign: TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                Text(
                  locationLabel!,
                  textAlign: TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLiked) Icon(Icons.favorite, size: 16, color: Colors.red),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: onDetails,
          ),
        ],
      ),
      onTap: onTap,
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
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.music_note, color: scheme.onSurfaceVariant),
    );

    if (path?.isEmpty ?? true) {
      return fallback;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(path!),
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final _AlbumEntry album;
  final VoidCallback onTap;

  const _AlbumCard({required this.album, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: album.artworkPath?.isNotEmpty == true
                  ? Image.file(
                      File(album.artworkPath!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _AlbumFallback(scheme: scheme),
                    )
                  : _AlbumFallback(scheme: scheme),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    album.tracks.first.artistName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumFallback extends StatelessWidget {
  final ColorScheme scheme;

  const _AlbumFallback({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: scheme.surfaceContainerHighest,
      child: Icon(Icons.music_note, size: 48, color: scheme.onSurfaceVariant),
    );
  }
}

class _AlbumTracksView extends StatelessWidget {
  final String title;
  final List<UiTrack> tracks;
  final PlaybackController playbackController;

  const _AlbumTracksView({
    required this.title,
    required this.tracks,
    required this.playbackController,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.builder(
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          return ListTile(
            leading: _ArtworkTile(path: track.artworkPath),
            title: Text(track.title, textAlign: TextAlign.left, maxLines: 1),
            subtitle: Text(
              track.artistName,
              textAlign: TextAlign.left,
              maxLines: 1,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showTrackDetails(context, track),
            ),
            onTap: () => playbackController.play(track, queue: tracks),
          );
        },
      ),
    );
  }
}

class _ArtistTracksView extends StatelessWidget {
  final String title;
  final List<UiTrack> tracks;
  final PlaybackController playbackController;

  const _ArtistTracksView({
    required this.title,
    required this.tracks,
    required this.playbackController,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.builder(
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          return ListTile(
            leading: _ArtworkTile(path: track.artworkPath),
            title: Text(track.title, textAlign: TextAlign.left, maxLines: 1),
            subtitle: Text(
              track.albumName ?? '',
              textAlign: TextAlign.left,
              maxLines: 1,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showTrackDetails(context, track),
            ),
            onTap: () => playbackController.play(track, queue: tracks),
          );
        },
      ),
    );
  }
}

class _FolderTracksView extends StatelessWidget {
  final String title;
  final List<UiTrack> tracks;
  final PlaybackController playbackController;

  const _FolderTracksView({
    required this.title,
    required this.tracks,
    required this.playbackController,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.builder(
        itemCount: tracks.length,
        itemBuilder: (context, index) {
          final track = tracks[index];
          return ListTile(
            leading: _ArtworkTile(path: track.artworkPath),
            title: Text(track.title, textAlign: TextAlign.left, maxLines: 1),
            subtitle: Text(
              track.artistName,
              textAlign: TextAlign.left,
              maxLines: 1,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showTrackDetails(context, track),
            ),
            onTap: () => playbackController.play(track, queue: tracks),
          );
        },
      ),
    );
  }
}

List<_AlbumEntry> _groupByAlbum(List<UiTrack> tracks) {
  final map = <String, List<UiTrack>>{};
  for (final track in tracks) {
    final key = track.albumName?.trim().isNotEmpty == true
        ? track.albumName!.trim()
        : 'Unknown Album';
    map.putIfAbsent(key, () => []).add(track);
  }
  return map.entries
      .map((entry) => _AlbumEntry(name: entry.key, tracks: entry.value))
      .toList(growable: false);
}

List<_ArtistEntry> _groupByArtist(List<UiTrack> tracks) {
  final map = <String, List<UiTrack>>{};
  for (final track in tracks) {
    final key = track.artistName.trim().isNotEmpty
        ? track.artistName.trim()
        : 'Unknown Artist';
    map.putIfAbsent(key, () => []).add(track);
  }
  return map.entries
      .map((entry) => _ArtistEntry(name: entry.key, tracks: entry.value))
      .toList(growable: false);
}

List<_FolderEntry> _groupByFolder(List<UiTrack> tracks) {
  final map = <String, List<UiTrack>>{};
  for (final track in tracks) {
    final path = track.filePath ?? '';
    final folder = path.isEmpty ? 'Unknown Folder' : File(path).parent.path;
    map.putIfAbsent(folder, () => []).add(track);
  }
  return map.entries
      .map((entry) => _FolderEntry(path: entry.key, tracks: entry.value))
      .toList(growable: false);
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
            leading: _ArtworkTile(path: track.artworkPath),
            title: Text(track.title, textAlign: TextAlign.left, maxLines: 1),
            subtitle: Text(
              track.artistName,
              textAlign: TextAlign.left,
              maxLines: 1,
            ),
            trailing: IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showTrackDetails(context, track),
            ),
            onTap: () => playbackController.play(track, queue: tracks),
          );
        },
      ),
    );
  }
}

Future<void> _showTrackDetails(BuildContext context, UiTrack track) async {
  final artworkPath = track.artworkPath;
  final filePath = track.filePath;
  FileStat? stat;
  if (filePath != null && filePath.isNotEmpty) {
    final file = File(filePath);
    if (file.existsSync()) {
      stat = file.statSync();
    }
  }
  await showModalBottomSheet(
    context: context,
    builder: (context) {
      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (artworkPath != null &&
                artworkPath.isNotEmpty &&
                File(artworkPath).existsSync())
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 240,
                    maxHeight: 240,
                  ),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(artworkPath),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.music_note, size: 64),
                      ),
                    ),
                  ),
                ),
              )
            else
              const Center(child: Icon(Icons.music_note, size: 64)),
            const SizedBox(height: 16),
            _detailRow('Title', track.title),
            _detailRow('Artist', track.artistName),
            _detailRow('Album', track.albumName ?? 'Unknown Album'),
            _detailRow('Duration', track.durationFormatted),
            _detailRow('Track ID', track.id),
            _detailRow('Availability', track.availability.name),
            _detailRow('Locator Kind', track.locator.kind.name),
            _detailRow('Locator Name', track.locator.displayName),
            _detailRow(
              'Locator Path',
              track.locator.path?.isNotEmpty == true
                  ? track.locator.path!
                  : 'None',
            ),
            _detailRow(
              'Locator URI',
              track.locator.uri?.isNotEmpty == true
                  ? track.locator.uri!
                  : 'None',
            ),
            _detailRow(
              'Mime Type',
              track.locator.mimeType?.isNotEmpty == true
                  ? track.locator.mimeType!
                  : 'None',
            ),
            _detailRow(
              'Bytes',
              track.locator.bytes == null
                  ? 'None'
                  : '${track.locator.bytes!.length} bytes',
            ),
            _detailRow('File Path', filePath ?? 'None'),
            _detailRow(
              'Last Modified',
              stat?.modified.toIso8601String() ?? 'Unknown',
            ),
            _detailRow('Size', stat == null ? 'Unknown' : '${stat.size} bytes'),
            _detailRow(
              'Artwork Path',
              artworkPath?.isNotEmpty == true ? artworkPath! : 'None',
            ),
          ],
        ),
      );
    },
  );
}

Widget _detailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value),
      ],
    ),
  );
}
