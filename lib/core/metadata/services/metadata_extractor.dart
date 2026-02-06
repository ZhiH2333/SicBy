import 'dart:io';

import 'package:flutter_media_metadata/flutter_media_metadata.dart';

import '../models/audio_metadata.dart';

class MetadataExtractor {
  Future<AudioMetadata?> read(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;

    final stat = await file.stat();
    final metadata = await MetadataRetriever.fromFile(file);
    final title = metadata.trackName?.trim() ?? '';
    final artist = metadata.trackArtistNames?.join(', ').trim() ?? '';
    final album = metadata.albumName?.trim();
    final durationMs = metadata.trackDuration ?? 0;
    final duration = Duration(milliseconds: durationMs);

    return AudioMetadata(
      path: path,
      title: title.isEmpty ? file.uri.pathSegments.last : title,
      artist: artist.isEmpty ? 'Unknown Artist' : artist,
      album: album,
      duration: duration,
      lastModified: stat.modified,
      fileSizeBytes: stat.size,
    );
  }
}
