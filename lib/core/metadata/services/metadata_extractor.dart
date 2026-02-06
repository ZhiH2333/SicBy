import 'dart:io';

import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

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
    final artworkPath = await _saveArtwork(path, metadata.albumArt);

    return AudioMetadata(
      path: path,
      title: title.isEmpty ? file.uri.pathSegments.last : title,
      artist: artist.isEmpty ? 'Unknown Artist' : artist,
      album: album,
      duration: duration,
      artworkPath: artworkPath,
      lastModified: stat.modified,
      fileSizeBytes: stat.size,
    );
  }

  Future<String?> _saveArtwork(String filePath, List<int>? bytes) async {
    if (bytes == null || bytes.isEmpty) return null;
    final directory = await getApplicationSupportDirectory();
    final cacheDir = Directory(path.join(directory.path, 'metadata_artwork'));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    final filename = _safeFilename(filePath);
    final output = File(path.join(cacheDir.path, '$filename.jpg'));
    if (!await output.exists()) {
      await output.writeAsBytes(bytes, flush: true);
    }
    return output.path;
  }

  String _safeFilename(String filePath) {
    final base = path.basenameWithoutExtension(filePath);
    final sanitized = base.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return sanitized.isEmpty
        ? 'art_${DateTime.now().millisecondsSinceEpoch}'
        : sanitized;
  }
}
