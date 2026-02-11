import '../domain/playback_state.dart';
import '../domain/track.dart';
import '../domain/repeat_mode.dart';

abstract class SystemActionHandler {
  Future<void> onSkipNext();
  Future<void> onSkipPrevious();
  Future<void> onStop();
}

abstract class AudioPlaybackService {
  Stream<PlaybackState> get playbackStateStream;

  Future<void> load(Track track);
  /// Completes when the current source is ready to play (e.g. duration available).
  Future<void> waitUntilReady({Duration timeout = const Duration(seconds: 30)});
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  Future<void> setShuffleMode(bool enabled);
  Future<void> setRepeatMode(RepeatMode mode);
  Future<void> stop();
  Future<void> dispose();

  void setSystemActionHandler(SystemActionHandler? handler);
}
