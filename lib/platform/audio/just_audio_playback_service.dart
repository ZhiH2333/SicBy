import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

import '../../domain/media_locator.dart';
import '../../domain/playback_state.dart';
import '../../domain/repeat_mode.dart';
import '../../domain/track.dart';
import '../../services/audio_playback_service.dart';

class JustAudioPlaybackService implements AudioPlaybackService {
  final AudioPlayer _player = AudioPlayer();
  final StreamController<PlaybackState> _stateController =
      StreamController<PlaybackState>.broadcast();

  PlaybackState _state = const PlaybackState();
  StreamSubscription<PlaybackState>? _stateSubscription;
  bool _isSeeking = false;
  int _logSeq = 0;
  final Stopwatch _logStopwatch = Stopwatch();

  JustAudioPlaybackService() {
    _logStopwatch.start();
    _setupAggregatedListeners();
  }

  /// 使用 Rx.combineLatest6 聚合所有流，确保状态同时更新
  void _setupAggregatedListeners() {
    _stateSubscription =
        Rx.combineLatest6(
          _player.playingStream,
          _player.positionStream,
          _player.durationStream,
          _player.processingStateStream,
          _player.shuffleModeEnabledStream,
          _player.loopModeStream,
          (
            playing,
            position,
            duration,
            processingState,
            shuffleEnabled,
            loopMode,
          ) {
            // 从聚合的流事件构建完整的 PlaybackState
            final buffering =
                processingState == ProcessingState.buffering ||
                processingState == ProcessingState.loading;
            final completed = processingState == ProcessingState.completed;
            
            // CRITICAL FIX: Never use stale duration from previous track
            // Only accept fresh duration from engine, or zero while loading
            final finalDuration = duration ?? Duration.zero;
            
            final finalPosition = completed && finalDuration > Duration.zero
                ? finalDuration
                : position;

            return PlaybackState(
              trackId: _state.trackId,
              isPlaying: playing,
              isBuffering: buffering,
              isCompleted: completed,
              position: finalPosition,
              duration: finalDuration,
              shuffleEnabled: shuffleEnabled,
              repeatMode: _toRepeatMode(loopMode),
            );
          },
        ).listen(
          (newState) {
            final seq = ++_logSeq;
            final ts = _logStopwatch.elapsedMilliseconds;
            // Seek 期间跳过流事件，避免状态冲击
            if (_isSeeking) {
              print('[$seq][${ts}ms] [combineLatest] ⏭️  Skipped (seeking in progress)');
              return;
            }
            print('[$seq][${ts}ms] 📊 [combineLatest] State updated:');
            print('   trackId: ${newState.trackId}');
            print('   duration: ${newState.duration}');
            print('   position: ${newState.position}');
            _emit(newState);
          },
          onError: (error) {
            // 错误处理
            final seq = ++_logSeq;
            final ts = _logStopwatch.elapsedMilliseconds;
            print('[$seq][${ts}ms] ❌ Error in aggregated streams: $error');
          },
        );
  }

  @override
  Stream<PlaybackState> get playbackStateStream => _stateController.stream;

  @override
  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_player.processingState == ProcessingState.ready) return;
    try {
      await _player.processingStateStream
          .firstWhere((s) => s == ProcessingState.ready)
          .timeout(timeout);
    } on TimeoutException {
      // proceed so play() can still be attempted
    }
  }

  @override
  Future<void> load(Track track) async {
    final seq = ++_logSeq;
    final ts = _logStopwatch.elapsedMilliseconds;
    print('[$seq][${ts}ms] 🎵 [load] Loading track: ${track.id}');
    _emit(
      _state.copyWith(
        trackId: track.id,
        isCompleted: false,
        position: Duration.zero,
        duration: Duration.zero,  // 清零 duration，防止旧值被使用
      ),
    );
    final seq2 = ++_logSeq;
    final ts2 = _logStopwatch.elapsedMilliseconds;
    print('[$seq2][${ts2}ms] 🎵 [load] Emitted: trackId=${track.id}, duration=0, position=0');
    final locator = track.locator;
    try {
      switch (locator.kind) {
        case MediaLocatorKind.path:
          if (locator.path != null) {
            // 使用 AudioSource.file 处理本地文件（特别是大文件）
            // 避免 URI 解析开销，直接使用文件描述符
            await _player.setAudioSource(AudioSource.file(locator.path!));
          }
          break;
        case MediaLocatorKind.uri:
          if (locator.uri != null) {
            await _player.setAudioSource(
              AudioSource.uri(Uri.parse(locator.uri!)),
            );
          }
          break;
        case MediaLocatorKind.bytes:
          if (locator.bytes != null) {
            final mimeType = locator.mimeType ?? 'application/octet-stream';
            final uri = Uri.dataFromBytes(locator.bytes!, mimeType: mimeType);
            await _player.setAudioSource(AudioSource.uri(uri));
          }
          break;
      }
    } catch (e) {
      print('❌ Failed to load track ${track.id}: $e');
      rethrow;
    }
  }

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    if (_isSeeking) return;
    _isSeeking = true;
    try {
      final Duration? engineDuration = _player.duration;
      if (engineDuration == null || engineDuration == Duration.zero) {
        return;
      }
      final int maxMs = engineDuration.inMilliseconds;
      final int requestedMs = position.inMilliseconds.clamp(0, maxMs);
      final Duration target = Duration(milliseconds: requestedMs);
      await _player.seek(target);
      _emit(
        _state.copyWith(
          position: _player.position,
          isCompleted: false,
        ),
      );
    } finally {
      _isSeeking = false;
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _emit(const PlaybackState());
  }

  @override
  Future<void> dispose() async {
    await _stateSubscription?.cancel();
    await _player.dispose();
    await _stateController.close();
  }

  @override
  Future<void> setShuffleMode(bool enabled) async {
    await _player.setShuffleModeEnabled(enabled);
    // Explicitly emit state update as JustAudio stream might be async/delayed
    _emit(_state.copyWith(shuffleEnabled: enabled));
  }

  @override
  Future<void> setRepeatMode(RepeatMode mode) async {
    final loopMode = _toLoopMode(mode);
    await _player.setLoopMode(loopMode);
    _emit(_state.copyWith(repeatMode: mode));
  }

  LoopMode _toLoopMode(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.off:
        return LoopMode.off;
      case RepeatMode.one:
        return LoopMode.one;
      case RepeatMode.all:
        return LoopMode.all;
    }
  }

  RepeatMode _toRepeatMode(LoopMode mode) {
    switch (mode) {
      case LoopMode.off:
        return RepeatMode.off;
      case LoopMode.one:
        return RepeatMode.one;
      case LoopMode.all:
        return RepeatMode.all;
    }
  }

  void _emit(PlaybackState next) {
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }

  @override
  void setSystemActionHandler(SystemActionHandler? handler) {
    // No-op for foreground-only playback.
  }
}
