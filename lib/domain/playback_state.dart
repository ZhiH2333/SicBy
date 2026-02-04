class PlaybackState {
  final String? trackId;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;

  const PlaybackState({
    this.trackId,
    this.isPlaying = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  PlaybackState copyWith({
    String? trackId,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
  }) {
    return PlaybackState(
      trackId: trackId ?? this.trackId,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }
}

enum PlaybackStatus { idle, ready, playing, paused, pendingDownload }
