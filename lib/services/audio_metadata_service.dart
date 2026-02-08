import 'dart:io';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart' as tag_reader;
import 'package:flutter_media_metadata/flutter_media_metadata.dart';

import 'artwork_cache_service.dart';

class AudioMetadataResult {
  final String? title;
  final String? artist;
  final String? album;
  final Duration? duration;
  final String? artworkPath;

  const AudioMetadataResult({
    this.title,
    this.artist,
    this.album,
    this.duration,
    this.artworkPath,
  });
}

class AudioMetadataService {
  final ArtworkCacheService _artworkCacheService;
  final Map<String, AudioMetadataResult> _memoryCache = {};

  AudioMetadataService(this._artworkCacheService);

  bool isArtworkAvailable(String? path) {
    if (path == null || path.isEmpty) return false;
    return File(path).existsSync();
  }

  Future<AudioMetadataResult?> read(String path, {DateTime? modified}) async {
    final cacheKey = '$path:${modified?.millisecondsSinceEpoch ?? ''}';
    final cached = _memoryCache[cacheKey];
    if (cached != null) {
      if (cached.artworkPath == null ||
          isArtworkAvailable(cached.artworkPath)) {
        return cached;
      }
      _memoryCache.remove(cacheKey);
    }
    final file = File(path);
    if (!await file.exists()) return null;

    Metadata? metadata;
    try {
      metadata = await MetadataRetriever.fromFile(file);
    } catch (_) {
      metadata = null;
    }
    var title = metadata?.trackName?.trim();
    var artist = metadata != null ? _resolveArtist(metadata) : null;
    var album = metadata?.albumName?.trim();
    var durationMs = metadata?.trackDuration;
    List<int>? artworkBytes = metadata?.albumArt;

    if (_needsFallback(title, artist, album, artworkBytes)) {
      final fallback = _readFallbackMetadata(file);
      if (fallback != null) {
        if (title == null || title.isEmpty) title = fallback.title;
        if (artist == null || artist.isEmpty) artist = fallback.artist;
        if (album == null || album.isEmpty) album = fallback.album;
        if ((artworkBytes == null || artworkBytes.isEmpty) &&
            fallback.artworkBytes != null &&
            fallback.artworkBytes!.isNotEmpty) {
          artworkBytes = fallback.artworkBytes;
        }
        if ((durationMs == null || durationMs == 0) &&
            fallback.duration != null) {
          durationMs = fallback.duration!.inMilliseconds;
        }
      }
    }
    final duration = durationMs != null
        ? Duration(milliseconds: durationMs)
        : null;

    String? artworkPath;
    if (artworkBytes != null && artworkBytes.isNotEmpty) {
      final bytes = artworkBytes is Uint8List
          ? artworkBytes
          : Uint8List.fromList(artworkBytes);
      artworkPath = await _artworkCacheService.saveArtworkBytes(
        cacheKey,
        bytes,
      );
    }

    final result = AudioMetadataResult(
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      artworkPath: artworkPath,
    );
    _memoryCache[cacheKey] = result;
    return result;
  }

  String? _resolveArtist(Metadata metadata) {
    final fromList = _joinArtists(metadata.trackArtistNames);
    if (fromList != null && fromList.isNotEmpty) return fromList;
    final candidates = [
      metadata.albumArtistName,
      metadata.authorName,
      metadata.writerName,
    ];
    for (final candidate in candidates) {
      final value = candidate?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  String? _joinArtists(List<String>? names) {
    if (names == null || names.isEmpty) return null;
    final cleaned = names
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    if (cleaned.isEmpty) return null;
    return cleaned.join(', ').trim();
  }

  bool _needsFallback(
    String? title,
    String? artist,
    String? album,
    List<int>? artworkBytes,
  ) {
    final hasCore =
        (title != null && title.isNotEmpty) &&
        (artist != null && artist.isNotEmpty) &&
        (album != null && album.isNotEmpty);
    if (hasCore && artworkBytes != null && artworkBytes.isNotEmpty) {
      return false;
    }
    return true;
  }

  _ReaderFallback? _readFallbackMetadata(File file) {
    try {
      final metadata = tag_reader.readMetadata(file, getImage: true);
      final title = metadata.title?.trim() ?? '';
      final artist = _resolveReaderArtist(metadata);
      final album = metadata.album?.trim() ?? '';
      final artworkBytes = _selectReaderArtwork(metadata);
      return _ReaderFallback(
        title: title,
        artist: artist,
        album: album,
        duration: metadata.duration,
        artworkBytes: artworkBytes,
      );
    } catch (_) {
      return null;
    }
  }

  String _resolveReaderArtist(tag_reader.AudioMetadata metadata) {
    final rawArtist = metadata.artist?.trim() ?? '';
    if (rawArtist.isNotEmpty) return rawArtist;
    if (metadata.performers.isEmpty) return '';
    final cleaned = metadata.performers
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    return cleaned.join(', ').trim();
  }

  List<int>? _selectReaderArtwork(tag_reader.AudioMetadata metadata) {
    if (metadata.pictures.isEmpty) return null;
    final cover = metadata.pictures.firstWhere(
      (picture) => picture.pictureType == tag_reader.PictureType.coverFront,
      orElse: () => metadata.pictures.first,
    );
    return cover.bytes;
  }
}

class _ReaderFallback {
  final String title;
  final String artist;
  final String album;
  final Duration? duration;
  final List<int>? artworkBytes;

  const _ReaderFallback({
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.artworkBytes,
  });
}
