import '../domain/playback_state.dart';
import '../domain/track.dart';

abstract class AudioPlaybackService {
  Stream<PlaybackState> get playbackStateStream;

  Future<void> load(Track track);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> stop();
  Future<void> dispose();
}
