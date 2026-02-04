import 'media_locator.dart';

class Track {
  final String id;
  final String title;
  final String artistName;
  final Duration duration;
  final MediaLocator locator;
  final String? albumName;
  final DateTime? lastModified;
  final int? fileSizeBytes;

  const Track({
    required this.id,
    required this.title,
    required this.artistName,
    required this.duration,
    required this.locator,
    this.albumName,
    this.lastModified,
    this.fileSizeBytes,
  });
}
