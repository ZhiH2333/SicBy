/// UI View Models for SicBy
/// These are UI-only data classes, not domain entities.
library;

import '../domain/media_locator.dart';
import '../domain/track_availability.dart';

/// Represents a track for UI display
class UiTrack {
  final String id;
  final String title;
  final String artistName;
  final String? albumName;
  final String? artworkPath;
  final Duration duration;
  final MediaLocator locator;
  final String? filePath;
  final TrackAvailability availability;

  const UiTrack({
    required this.id,
    required this.title,
    required this.artistName,
    this.albumName,
    this.artworkPath,
    required this.duration,
    required this.locator,
    this.filePath,
    this.availability = TrackAvailability.local,
  });

  UiTrack copyWith({TrackAvailability? availability}) {
    return UiTrack(
      id: id,
      title: title,
      artistName: artistName,
      albumName: albumName,
      artworkPath: artworkPath,
      duration: duration,
      locator: locator,
      filePath: filePath,
      availability: availability ?? this.availability,
    );
  }

  String get durationFormatted {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  bool get isCloud => availability == TrackAvailability.cloudOnly;
  bool get isDownloaded =>
      availability == TrackAvailability.local ||
      availability == TrackAvailability.ready;
}

/// Playback repeat mode
enum RepeatMode { off, one, all }

enum DownloadStatus { idle, downloading, completed, failed }

/// Represents playback state for UI
class UiPlaybackState {
  final UiTrack? currentTrack;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final bool shuffleEnabled;
  final RepeatMode repeatMode;
  final DownloadStatus downloadStatus;
  final double downloadProgress; // 0.0 to 1.0
  final String? downloadingTrackId;
  final String? downloadFailureReason;

  const UiPlaybackState({
    this.currentTrack,
    this.isPlaying = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.shuffleEnabled = false,
    this.repeatMode = RepeatMode.off,
    this.downloadStatus = DownloadStatus.idle,
    this.downloadProgress = 0.0,
    this.downloadingTrackId,
    this.downloadFailureReason,
  });

  double get progressPercent => duration.inMilliseconds > 0
      ? position.inMilliseconds / duration.inMilliseconds
      : 0.0;

  String get positionFormatted => _formatDuration(position);
  String get durationFormatted => _formatDuration(duration);

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  UiPlaybackState copyWith({
    UiTrack? currentTrack,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
    bool? shuffleEnabled,
    RepeatMode? repeatMode,
    DownloadStatus? downloadStatus,
    double? downloadProgress,
    String? downloadingTrackId,
    String? downloadFailureReason,
  }) {
    return UiPlaybackState(
      currentTrack: currentTrack ?? this.currentTrack,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      repeatMode: repeatMode ?? this.repeatMode,
      downloadStatus: downloadStatus ?? this.downloadStatus,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadingTrackId: downloadingTrackId ?? this.downloadingTrackId,
      downloadFailureReason: downloadFailureReason,
    );
  }
}

/// Library state for UI
class UiLibraryState {
  final List<UiTrack> tracks;
  final bool isLoading;
  final String? error;
  final String? currentFolderPath;

  const UiLibraryState({
    this.tracks = const [],
    this.isLoading = false,
    this.error,
    this.currentFolderPath,
  });

  UiLibraryState copyWith({
    List<UiTrack>? tracks,
    bool? isLoading,
    String? error,
    String? currentFolderPath,
  }) {
    return UiLibraryState(
      tracks: tracks ?? this.tracks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentFolderPath: currentFolderPath ?? this.currentFolderPath,
    );
  }
}
