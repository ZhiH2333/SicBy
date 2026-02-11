class AudioMetadata {
  final String path;
  final String title;
  final String artist;
  final String? album;
  final Duration duration;
  final String? artworkPath;
  final DateTime? lastModified;
  final int? fileSizeBytes;

  const AudioMetadata({
    required this.path,
    required this.title,
    required this.artist,
    required this.duration,
    this.album,
    this.artworkPath,
    this.lastModified,
    this.fileSizeBytes,
  });

  AudioMetadata copyWith({
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? artworkPath,
    DateTime? lastModified,
    int? fileSizeBytes,
  }) {
    return AudioMetadata(
      path: path,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      artworkPath: artworkPath ?? this.artworkPath,
      lastModified: lastModified ?? this.lastModified,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    );
  }
}
