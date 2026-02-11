import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart' as tag_reader;
import 'package:flutter_media_metadata/flutter_media_metadata.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/audio_metadata.dart';

class MetadataExtractor {
  Future<AudioMetadata?> read(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final stat = await file.stat();
    Metadata? metadata;
    try {
      metadata = await MetadataRetriever.fromFile(file);
    } catch (_) {
      metadata = null;
    }
    var rawTitle = metadata?.trackName?.trim() ?? '';
    var rawArtist = metadata != null ? _resolveArtist(metadata) : '';
    var rawAlbum = metadata?.albumName?.trim() ?? '';
    var durationMs = metadata?.trackDuration ?? 0;
    List<int>? artworkBytes = metadata?.albumArt;

    if (_needsFallback(rawTitle, rawArtist, rawAlbum, artworkBytes)) {
      final fallback = _readFallbackMetadata(file);
      if (fallback != null) {
        if (rawTitle.isEmpty) rawTitle = fallback.title;
        if (rawArtist.isEmpty) rawArtist = fallback.artist;
        if (rawAlbum.isEmpty) rawAlbum = fallback.album;
        if ((artworkBytes == null || artworkBytes.isEmpty) &&
            fallback.artworkBytes != null &&
            fallback.artworkBytes!.isNotEmpty) {
          artworkBytes = fallback.artworkBytes;
        }
        if (durationMs == 0 && fallback.duration != null) {
          durationMs = fallback.duration!.inMilliseconds;
        }
      }
    }
    final duration = Duration(milliseconds: durationMs);
    final artworkPath = await _saveArtwork(filePath, artworkBytes);

    final fileName = path.basenameWithoutExtension(file.path);
    final parsed = (rawTitle.isEmpty || rawArtist.isEmpty || rawAlbum.isEmpty)
        ? _parseFilename(fileName)
        : const _ParsedTags();

    final title = _fallbackText(rawTitle, parsed.title, fileName);
    final artist = _fallbackText(rawArtist, parsed.artist, 'Unknown Artist');
    final album = _fallbackText(rawAlbum, parsed.album, 'Unknown Album');

    return AudioMetadata(
      path: filePath,
      title: title,
      artist: artist,
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

  String _fallbackText(String primary, String secondary, String fallback) {
    final value = primary.isNotEmpty ? primary : secondary;
    return value.isNotEmpty ? value : fallback;
  }

  String _resolveArtist(Metadata metadata) {
    final fromList = _joinArtists(metadata.trackArtistNames);
    if (fromList.isNotEmpty) return fromList;
    final candidates = [
      metadata.albumArtistName,
      metadata.authorName,
      metadata.writerName,
    ];
    for (final candidate in candidates) {
      final value = candidate?.trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  bool _needsFallback(
    String title,
    String artist,
    String album,
    List<int>? artworkBytes,
  ) {
    if (title.isNotEmpty && artist.isNotEmpty && album.isNotEmpty) {
      if (artworkBytes != null && artworkBytes.isNotEmpty) {
        return false;
      }
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

  String _joinArtists(List<String>? names) {
    if (names == null || names.isEmpty) return '';
    final cleaned = names
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    return cleaned.join(', ').trim();
  }

  _ParsedTags _parseFilename(String fileName) {
    final cleaned = _cleanFilename(fileName);
    if (cleaned.isEmpty) return const _ParsedTags();

    // Pattern: "Artist - Album - Title" or "Artist - Title"
    final dashParts = cleaned.split(' - ').map((part) => part.trim()).toList();
    if (dashParts.length >= 2) {
      final artist = dashParts.first;
      if (dashParts.length >= 3) {
        final album = dashParts[1];
        final title = dashParts.sublist(2).join(' - ').trim();
        return _ParsedTags(title: title, artist: artist, album: album);
      }
      final title = dashParts.sublist(1).join(' - ').trim();
      return _ParsedTags(title: title, artist: artist);
    }

    // Pattern: "01. Title" or "01 - Title"
    final trackMatch = RegExp(r'^\d+[\.\-\s]+(.+)$').firstMatch(cleaned);
    if (trackMatch != null) {
      return _ParsedTags(title: trackMatch.group(1)?.trim() ?? '');
    }

    // Pattern: "Title (feat. Artist)" or "Title [feat. Artist]"
    final featMatch = RegExp(
      r'^(.+?)\s*[\(\[](?:feat\.|ft\.|featuring)\s*(.+?)[\)\]]',
      caseSensitive: false,
    ).firstMatch(cleaned);
    if (featMatch != null) {
      return _ParsedTags(
        title: featMatch.group(1)?.trim() ?? '',
        artist: featMatch.group(2)?.trim() ?? '',
      );
    }

    return _ParsedTags(title: cleaned);
  }

  String _cleanFilename(String text) {
    var cleaned = text;
    cleaned = cleaned.replaceAll(
      RegExp(r'\[.*?(320|flac|mp3|aac|lossless).*?\]', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\(.*?(320|flac|mp3|aac|lossless).*?\)', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(
      RegExp(r'\[.*?(youtube|soundcloud|spotify).*?\]', caseSensitive: false),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned;
  }
}

class _ParsedTags {
  const _ParsedTags({this.title = '', this.artist = '', this.album = ''});

  final String title;
  final String artist;
  final String album;
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
