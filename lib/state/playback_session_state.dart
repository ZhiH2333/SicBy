import '../domain/track_availability.dart';

enum PlaybackSource { local, cloud }

class PlaybackSessionState {
  final String? currentTrackId;
  final List<String> queueIds;
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final PlaybackSource source;
  final TrackAvailability availability;

  const PlaybackSessionState({
    required this.currentTrackId,
    required this.queueIds,
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.source,
    required this.availability,
  });

  factory PlaybackSessionState.initial() {
    return const PlaybackSessionState(
      currentTrackId: null,
      queueIds: [],
      position: Duration.zero,
      duration: Duration.zero,
      isPlaying: false,
      source: PlaybackSource.local,
      availability: TrackAvailability.local,
    );
  }

  PlaybackSessionState copyWith({
    String? currentTrackId,
    List<String>? queueIds,
    Duration? position,
    Duration? duration,
    bool? isPlaying,
    PlaybackSource? source,
    TrackAvailability? availability,
  }) {
    return PlaybackSessionState(
      currentTrackId: currentTrackId ?? this.currentTrackId,
      queueIds: queueIds ?? this.queueIds,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      isPlaying: isPlaying ?? this.isPlaying,
      source: source ?? this.source,
      availability: availability ?? this.availability,
    );
  }
}
