class TrackMetadataOverride {
  final String? title;
  final String? artist;
  final String? album;
  final String? artworkPath;
  final String? lyrics;

  const TrackMetadataOverride({
    this.title,
    this.artist,
    this.album,
    this.artworkPath,
    this.lyrics,
  });

  TrackMetadataOverride copyWith({
    String? title,
    String? artist,
    String? album,
    String? artworkPath,
    String? lyrics,
  }) {
    return TrackMetadataOverride(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      artworkPath: artworkPath ?? this.artworkPath,
      lyrics: lyrics ?? this.lyrics,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'title': title,
      'artist': artist,
      'album': album,
      'artworkPath': artworkPath,
      'lyrics': lyrics,
    };
  }

  factory TrackMetadataOverride.fromMap(Map<String, Object?> map) {
    return TrackMetadataOverride(
      title: map['title'] as String?,
      artist: map['artist'] as String?,
      album: map['album'] as String?,
      artworkPath: map['artworkPath'] as String?,
      lyrics: map['lyrics'] as String?,
    );
  }
}
