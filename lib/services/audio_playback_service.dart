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
  Stream<Duration> get positionStream;
  Stream<Duration> get bufferedPositionStream;
  Stream<Duration?> get durationStream;

  Future<void> load(Track track);
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
