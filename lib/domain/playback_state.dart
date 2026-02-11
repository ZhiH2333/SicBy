import 'repeat_mode.dart';

class PlaybackState {
  final String? trackId;
  final bool isPlaying;
  final bool isBuffering;
  final bool isCompleted;
  final Duration position;
  final Duration duration;
  final bool shuffleEnabled;
  final RepeatMode repeatMode;

  const PlaybackState({
    this.trackId,
    this.isPlaying = false,
    this.isBuffering = false,
    this.isCompleted = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.shuffleEnabled = false,
    this.repeatMode = RepeatMode.off,
  });

  PlaybackState copyWith({
    String? trackId,
    bool? isPlaying,
    bool? isBuffering,
    bool? isCompleted,
    Duration? position,
    Duration? duration,
    bool? shuffleEnabled,
    RepeatMode? repeatMode,
  }) {
    return PlaybackState(
      trackId: trackId ?? this.trackId,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      isCompleted: isCompleted ?? this.isCompleted,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      repeatMode: repeatMode ?? this.repeatMode,
    );
  }
}

enum PlaybackStatus { idle, ready, playing, paused, pendingDownload }
