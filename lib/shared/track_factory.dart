import '../domain/track.dart';
import '../domain/track_availability.dart';
import '../services/file_system_service.dart';
import '../services/audio_metadata_service.dart';

class TrackFactory {
  Track createFromMediaFile(
    MediaFile file, {
    AudioMetadataResult? metadata,
    bool preferMetadata = true,
  }) {
    final parsed = _parseTitleArtist(file.name);
    final title = _clean(
      preferMetadata ? (metadata?.title ?? parsed.title) : parsed.title,
    );
    final artist = _clean(
      preferMetadata ? (metadata?.artist ?? parsed.artist) : parsed.artist,
    );
    final album = _clean(preferMetadata ? metadata?.album : null);
    final duration = preferMetadata
        ? (metadata?.duration ?? Duration.zero)
        : Duration.zero;
    final artworkPath = preferMetadata ? metadata?.artworkPath : null;
    final id = _deterministicId(file);

    return Track(
      id: id,
      title: title.isEmpty ? parsed.title : title,
      artistName: artist.isEmpty ? parsed.artist : artist,
      duration: duration,
      locator: file.locator,
      albumName: album,
      artworkPath: artworkPath,
      lastModified: file.lastModified,
      fileSizeBytes: file.sizeBytes,
      availability: TrackAvailability.local,
    );
  }

  _ParsedTitle _parseTitleArtist(String name) {
    final dotIndex = name.lastIndexOf('.');
    final base = dotIndex <= 0 ? name : name.substring(0, dotIndex);
    final separatorIndex = base.indexOf(' - ');
    if (separatorIndex > 0) {
      final artist = _clean(base.substring(0, separatorIndex));
      final title = _clean(base.substring(separatorIndex + 3));
      return _ParsedTitle(title: title, artist: artist);
    }
    return _ParsedTitle(title: _clean(base), artist: 'Unknown Artist');
  }

  String _clean(String? value) {
    if (value == null) return '';
    return value.trim();
  }

  String _deterministicId(MediaFile file) {
    final locator = file.locator;
    if (locator.path != null && locator.path!.isNotEmpty) {
      return locator.path!;
    }
    if (locator.uri != null && locator.uri!.isNotEmpty) {
      return locator.uri!;
    }

    final size = file.sizeBytes ?? locator.bytes?.length ?? 0;
    return '${file.name}|$size';
  }
}

class _ParsedTitle {
  final String title;
  final String artist;

  const _ParsedTitle({required this.title, required this.artist});
}
