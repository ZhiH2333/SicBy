import 'media_locator.dart';
import 'track_availability.dart';

class Track {
  final String id;
  final String title;
  final String artistName;
  final Duration duration;
  final MediaLocator locator;
  final String? albumName;
  final String? artworkPath;
  final DateTime? lastModified;
  final int? fileSizeBytes;
  final TrackAvailability availability;

  const Track({
    required this.id,
    required this.title,
    required this.artistName,
    required this.duration,
    required this.locator,
    this.albumName,
    this.artworkPath,
    this.lastModified,
    this.fileSizeBytes,
    this.availability = TrackAvailability.local,
  });

  Track copyWith({
    String? title,
    String? artistName,
    Duration? duration,
    MediaLocator? locator,
    String? albumName,
    String? artworkPath,
    DateTime? lastModified,
    int? fileSizeBytes,
    TrackAvailability? availability,
  }) {
    return Track(
      id: id,
      title: title ?? this.title,
      artistName: artistName ?? this.artistName,
      duration: duration ?? this.duration,
      locator: locator ?? this.locator,
      albumName: albumName ?? this.albumName,
      artworkPath: artworkPath ?? this.artworkPath,
      lastModified: lastModified ?? this.lastModified,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      availability: availability ?? this.availability,
    );
  }
}
