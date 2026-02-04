import '../domain/playback_state.dart';
import '../domain/track.dart';
import '../domain/repeat_mode.dart';

abstract class AudioPlaybackService {
  Stream<PlaybackState> get playbackStateStream;

  Future<void> load(Track track);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setShuffleMode(bool enabled);
  Future<void> setRepeatMode(RepeatMode mode);
  Future<void> stop();
  Future<void> dispose();
}
