import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui_models.dart';
import '../domain/playback_state.dart';
import '../domain/track.dart';
import '../services/audio_playback_service.dart';
import 'service_providers.dart';

/// Playback controller provider
final playbackControllerProvider =
    StateNotifierProvider<PlaybackController, UiPlaybackState>((ref) {
      final audioService = ref.read(audioPlaybackServiceProvider);
      ref.onDispose(audioService.dispose);
      return PlaybackController(audioPlaybackService: audioService);
    });

/// Manages audio playback
class PlaybackController extends StateNotifier<UiPlaybackState> {
  final AudioPlaybackService _audioPlaybackService;
  List<UiTrack> _queue = [];
  int _currentIndex = -1;

  PlaybackController({required AudioPlaybackService audioPlaybackService})
    : _audioPlaybackService = audioPlaybackService,
      super(const UiPlaybackState()) {
    _audioPlaybackService.playbackStateStream.listen(_onPlaybackState);
  }

  /// Play a track from the library
  Future<void> play(UiTrack track, {List<UiTrack>? queue}) async {
    if (queue != null) {
      _queue = queue;
      _currentIndex = queue.indexOf(track);
    } else {
      _queue = [track];
      _currentIndex = 0;
    }

    try {
      final domainTrack = _toDomainTrack(track);
      await _audioPlaybackService.load(domainTrack);
      await _audioPlaybackService.play();
      state = state.copyWith(currentTrack: track);
    } catch (e) {
      // Handle error silently for now
      state = state.copyWith(isPlaying: false);
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await _audioPlaybackService.pause();
      return;
    }
    await _audioPlaybackService.play();
  }

  /// Seek to position (0.0 to 1.0)
  Future<void> seekTo(double percent) async {
    final position = Duration(
      milliseconds: (state.duration.inMilliseconds * percent).round(),
    );
    await _audioPlaybackService.seek(position);
  }

  /// Skip to next track
  Future<void> next() async {
    if (_queue.isEmpty) return;

    _currentIndex = (_currentIndex + 1) % _queue.length;
    final nextTrack = _queue[_currentIndex];
    await play(nextTrack, queue: _queue);
  }

  /// Skip to previous track
  Future<void> previous() async {
    if (_queue.isEmpty) return;

    // If more than 3 seconds in, restart current track
    if (state.position.inSeconds > 3) {
      await _audioPlaybackService.seek(Duration.zero);
      return;
    }

    _currentIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
    final prevTrack = _queue[_currentIndex];
    await play(prevTrack, queue: _queue);
  }

  /// Stop playback
  Future<void> stop() async {
    await _audioPlaybackService.stop();
    state = const UiPlaybackState();
  }

  void _onPlaybackState(PlaybackState playbackState) {
    state = state.copyWith(
      isPlaying: playbackState.isPlaying,
      isBuffering: playbackState.isBuffering,
      position: playbackState.position,
      duration: playbackState.duration,
    );
  }

  Track _toDomainTrack(UiTrack track) {
    return Track(
      id: track.id,
      title: track.title,
      artistName: track.artistName,
      duration: track.duration,
      locator: track.locator,
      albumName: track.albumName,
    );
  }
}
