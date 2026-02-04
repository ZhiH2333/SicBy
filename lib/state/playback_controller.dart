import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'ui_models.dart';

/// Playback controller provider
final playbackControllerProvider =
    StateNotifierProvider<PlaybackController, UiPlaybackState>((ref) {
      return PlaybackController();
    });

/// Manages audio playback
class PlaybackController extends StateNotifier<UiPlaybackState> {
  final AudioPlayer _player = AudioPlayer();
  List<UiTrack> _queue = [];
  int _currentIndex = -1;

  PlaybackController() : super(const UiPlaybackState()) {
    _initListeners();
  }

  void _initListeners() {
    // Playing state
    _player.playingStream.listen((playing) {
      state = state.copyWith(isPlaying: playing);
    });

    // Position updates
    _player.positionStream.listen((position) {
      state = state.copyWith(position: position);
    });

    // Duration updates
    _player.durationStream.listen((duration) {
      if (duration != null) {
        state = state.copyWith(duration: duration);
      }
    });

    // Buffering state
    _player.processingStateStream.listen((processingState) {
      state = state.copyWith(
        isBuffering:
            processingState == ProcessingState.buffering ||
            processingState == ProcessingState.loading,
      );

      // Auto-advance on completion
      if (processingState == ProcessingState.completed) {
        next();
      }
    });
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

    state = state.copyWith(currentTrack: track);

    try {
      await _player.setFilePath(track.filePath);
      await _player.play();
    } catch (e) {
      // Handle error silently for now
      state = state.copyWith(isPlaying: false);
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  /// Seek to position (0.0 to 1.0)
  Future<void> seekTo(double percent) async {
    final position = Duration(
      milliseconds: (state.duration.inMilliseconds * percent).round(),
    );
    await _player.seek(position);
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
      await _player.seek(Duration.zero);
      return;
    }

    _currentIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
    final prevTrack = _queue[_currentIndex];
    await play(prevTrack, queue: _queue);
  }

  /// Stop playback
  Future<void> stop() async {
    await _player.stop();
    state = const UiPlaybackState();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
