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

  AudioMetadataService(this._artworkCacheService);

  Future<AudioMetadataResult?> read(String path, {DateTime? modified}) async {
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
      final key = '$path:${modified?.millisecondsSinceEpoch ?? ''}';
      artworkPath = await _artworkCacheService.saveArtworkBytes(key, artBytes);
    }

    return AudioMetadataResult(
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      artworkPath: artworkPath,
    );
  }
}
