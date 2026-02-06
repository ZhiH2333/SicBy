import 'dart:io';

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

    final metadata = await MetadataRetriever.fromFile(file);
    final title = metadata.trackName;
    final artist = metadata.trackArtistNames?.join(', ');
    final album = metadata.albumName;
    final durationMs = metadata.trackDuration;
    final duration = durationMs != null
        ? Duration(milliseconds: durationMs)
        : null;

    String? artworkPath;
    final artBytes = metadata.albumArt;
    if (artBytes != null && artBytes.isNotEmpty) {
      artworkPath = await _artworkCacheService.saveArtworkBytes(
        cacheKey,
        artBytes,
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
}
