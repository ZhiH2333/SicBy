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

  Track copyWith({TrackAvailability? availability, String? artworkPath}) {
    return Track(
      id: id,
      title: title,
      artistName: artistName,
      duration: duration,
      locator: locator,
      albumName: albumName,
      artworkPath: artworkPath ?? this.artworkPath,
      lastModified: lastModified,
      fileSizeBytes: fileSizeBytes,
      availability: availability ?? this.availability,
    );
  }
}
