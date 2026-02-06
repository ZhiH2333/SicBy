import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/local_library_provider.dart';
import '../../state/playback_controller.dart';
import '../../state/search_controller.dart';
import '../../state/ui_models.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchControllerProvider);
    final searchController = ref.read(searchControllerProvider.notifier);
    final libraryState = ref.watch(localLibraryProvider);
    final playbackController = ref.read(playbackControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    if (_controller.text != searchState.query) {
      _controller.text = searchState.query;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }

    final query = searchState.query.trim().toLowerCase();
    final tracks = libraryState.tracks;
    final filteredTracks = query.isEmpty
        ? const <UiTrack>[]
        : tracks
            .where(
              (track) =>
                  track.title.toLowerCase().contains(query) ||
                  track.artistName.toLowerCase().contains(query) ||
                  (track.albumName ?? '').toLowerCase().contains(query),
            )
            .toList(growable: false);

    final albums = _groupByAlbum(filteredTracks);
    final artists = _groupByArtist(filteredTracks);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        actions: [
          if (searchState.history.isNotEmpty)
            IconButton(
              tooltip: 'Clear history',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => searchController.clearHistory(),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              onChanged: searchController.updateQuery,
              onSubmitted: (value) => searchController.addHistory(value),
              decoration: InputDecoration(
                hintText: 'Search songs, albums, artists',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchState.query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          searchController.updateQuery('');
                          _focusNode.requestFocus();
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                if (query.isEmpty)
                  _HistorySection(
                    history: searchState.history,
                    onSelect: (value) {
                      searchController.updateQuery(value);
                      searchController.addHistory(value);
                    },
                    onRemove: searchController.removeHistory,
                  )
                else if (filteredTracks.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        'No results found',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  )
                else ...[
                  _SectionHeader(title: 'Songs'),
                  SliverList.separated(
                    itemCount: filteredTracks.length,
                    itemBuilder: (context, index) {
                      final track = filteredTracks[index];
                      return ListTile(
                        leading: _ArtworkTile(path: track.artworkPath, size: 42),
                        title: Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          track.artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          playbackController.play(track, queue: filteredTracks);
                        },
                      );
                    },
                    separatorBuilder: (context, index) =>
                        Divider(color: scheme.outlineVariant),
                  ),
                  if (albums.isNotEmpty) _SectionHeader(title: 'Albums'),
                  if (albums.isNotEmpty)
                    SliverList.separated(
                      itemCount: albums.length,
                      itemBuilder: (context, index) {
                        final album = albums[index];
                        return ListTile(
                          leading: _ArtworkTile(
                            path: album.artworkPath,
                            size: 42,
                          ),
                          title: Text(
                            album.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('${album.count} songs'),
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
                      separatorBuilder: (context, index) =>
                          Divider(color: scheme.outlineVariant),
                    ),
                  if (artists.isNotEmpty) _SectionHeader(title: 'Artists'),
                  if (artists.isNotEmpty)
                    SliverList.separated(
                      itemCount: artists.length,
                      itemBuilder: (context, index) {
                        final artist = artists[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: scheme.surfaceContainerHighest,
                            child: Text(
                              artist.name.isNotEmpty
                                  ? artist.name[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          title: Text(
                            artist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text('${artist.count} songs'),
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
                      separatorBuilder: (context, index) =>
                          Divider(color: scheme.outlineVariant),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySection extends StatelessWidget {
  final List<String> history;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onRemove;

  const _HistorySection({
    required this.history,
    required this.onSelect,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent searches', style: TextStyle(color: scheme.onSurface)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: history
                  .map(
                    (item) => InputChip(
                      label: Text(item),
                      onPressed: () => onSelect(item),
                      onDeleted: () => onRemove(item),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
        child: Text(
          title,
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class _ArtworkTile extends StatelessWidget {
  final String? path;
  final double size;

  const _ArtworkTile({required this.path, required this.size});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        Icons.music_note,
        size: size * 0.5,
        color: scheme.onSurfaceVariant,
      ),
    );

    if (path?.isEmpty ?? true) {
      return fallback;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.file(
        File(path!),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }
}

class _AlbumEntry {
  final String name;
  final List<UiTrack> tracks;

  _AlbumEntry({required this.name, required this.tracks});

  int get count => tracks.length;

  String? get artworkPath =>
      tracks.firstWhere((t) => t.artworkPath?.isNotEmpty ?? false,
          orElse: () => tracks.first).artworkPath;
}

class _ArtistEntry {
  final String name;
  final List<UiTrack> tracks;

  _ArtistEntry({required this.name, required this.tracks});

  int get count => tracks.length;
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
            leading: _ArtworkTile(path: track.artworkPath, size: 42),
            title: Text(track.title, maxLines: 1),
            subtitle: Text(track.artistName, maxLines: 1),
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
            leading: _ArtworkTile(path: track.artworkPath, size: 42),
            title: Text(track.title, maxLines: 1),
            subtitle: Text(track.albumName ?? '', maxLines: 1),
            onTap: () => playbackController.play(track, queue: tracks),
          );
        },
      ),
    );
  }
}
