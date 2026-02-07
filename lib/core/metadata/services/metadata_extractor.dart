import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/audio_metadata.dart';

class MetadataExtractor {
  Future<AudioMetadata?> read(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;

    final stat = await file.stat();
    final metadata = await MetadataRetriever.fromFile(file);
    final rawTitle = metadata.trackName ?? '';
    _debugTitle(rawTitle, path);
    final title = _cleanTitle(rawTitle);
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

  String _cleanTitle(String title) {
    if (title.isEmpty) return title;
    String cleaned = title;
    // Remove BOM and zero-width characters.
    cleaned = cleaned.replaceAll('\uFEFF', '');
    cleaned = cleaned.replaceAll('\uFFFE', '');
    cleaned = cleaned.replaceAll(RegExp(r'[\u200B-\u200D]'), '');
    // Remove null bytes and control characters.
    cleaned = cleaned.replaceAll('\u0000', '');
    cleaned = cleaned.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    // Normalize whitespace and trim.
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty && title.isNotEmpty) {
      return title.trim();
    }
    return cleaned;
  }

  void _debugTitle(String title, String filePath) {
    if (!kDebugMode || title.isEmpty) return;
    final fileName = path.basename(filePath);
    final previewLength = min(10, title.length);
    final preview = title.substring(0, previewLength);
    final bytes = utf8.encode(title);
    final bytePreview = bytes
        .take(20)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(' ');

    debugPrint('═══════════════════════════════════════');
    debugPrint('File: $fileName');
    debugPrint('Title: "$title"');
    debugPrint('Length: ${title.length} chars');
    debugPrint('First 10 chars: $preview');

    if (title.startsWith('\uFEFF')) {
      debugPrint('⚠️ BOM detected at start!');
    }

    debugPrint('First 20 bytes (hex): $bytePreview');

    final trimmed = title.trim();
    if (trimmed.length != title.length) {
      debugPrint('⚠️ Leading/trailing whitespace detected!');
      debugPrint('  Original length: ${title.length}');
      debugPrint('  Trimmed length: ${trimmed.length}');
      debugPrint('  Removed: ${title.length - trimmed.length} chars');
    }

    if (title.contains('\u0000')) {
      debugPrint('⚠️ Null bytes detected!');
      final nullCount = '\u0000'.allMatches(title).length;
      debugPrint('  Count: $nullCount');
    }

    final zwChars = ['\u200B', '\u200C', '\u200D', '\uFEFF'];
    for (final zw in zwChars) {
      if (title.contains(zw)) {
        debugPrint(
          '⚠️ Zero-width char detected: U+${zw.codeUnitAt(0).toRadixString(16).toUpperCase()}',
        );
      }
    }

    debugPrint(
      'First char code: U+${title.codeUnitAt(0).toRadixString(16).padLeft(4, '0').toUpperCase()}',
    );
    debugPrint('═══════════════════════════════════════');
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
