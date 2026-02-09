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

  JustAudioPlaybackService() {
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
            // Seek 期间跳过流事件，避免状态冲击
            if (_isSeeking) {
              print('   [combineLatest] ⏭️  Skipped (seeking in progress)');
              return;
            }
            print('📊 [combineLatest] State updated:');
            print('   trackId: ${newState.trackId}');
            print('   duration: ${newState.duration}');
            print('   position: ${newState.position}');
            _emit(newState);
          },
          onError: (error) {
            // 错误处理
            print('❌ Error in aggregated streams: $error');
          },
        );
  }

  @override
  Stream<PlaybackState> get playbackStateStream => _stateController.stream;

  @override
  Future<void> load(Track track) async {
    print('🎵 [load] Loading track: ${track.id}');
    _emit(
      _state.copyWith(
        trackId: track.id,
        isCompleted: false,
        position: Duration.zero,
        duration: Duration.zero,  // 清零 duration，防止旧值被使用
      ),
    );
    print('🎵 [load] Emitted: trackId=${track.id}, duration=0, position=0');
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
    print('🎯 [seek] START - target position: ${position.inMilliseconds}ms (${_formatDuration(position)})');
    
    // 防护：防止并发 seek 导致随机状态
    if (_isSeeking) {
      print('🎯 [seek] ❌ REJECTED: Seek already in progress');
      return;
    }

    // 标记 Seeking 状态，阻止流事件广播
    _isSeeking = true;

    try {
      // 获取实际时长：优先使用引擎的 duration（更可靠），回退到状态中的 duration
      final duration = _player.duration ?? _state.duration;
      print('🎯 [seek] Duration sources:');
      print('   _player.duration: ${_player.duration}');
      print('   _state.duration: ${_state.duration}');
      print('   Using: ${duration} (${_formatDuration(duration)})');

      // 防护：如果 duration 仍为 0，说明音频还未加载完成，不执行 Seek
      if (duration == Duration.zero) {
        print('🎯 [seek] ❌ ABORTED: duration is zero (audio still loading)');
        return;
      }

      // 末尾保护：如果目标非常接近文件末尾，调整目标位置
      Duration targetPosition = position;
      if (duration > Duration.zero &&
          (duration - position) < const Duration(milliseconds: 200)) {
        print('🎯 [seek] ⚠️  End-of-file protection triggered');
        // 离末尾太近，跳到 duration - 100ms
        targetPosition = Duration(
          milliseconds: (duration.inMilliseconds - 100).clamp(
            0,
            duration.inMilliseconds,
          ),
        );
        print('🎯 [seek] Adjusted target: ${targetPosition.inMilliseconds}ms (${_formatDuration(targetPosition)})');
      }

      // 执行底层跳转
      print('🎯 [seek] Executing _player.seek($targetPosition)...');
      await _player.seek(targetPosition);

      // 直接读取实际位置（不等待流事件）
      final actualPosition = _player.position ?? targetPosition;
      print('🎯 [seek] ✅ Seek completed. Actual position: ${actualPosition.inMilliseconds}ms (${_formatDuration(actualPosition)})');

      // 立即广播新状态
      _emit(
        _state.copyWith(
          position: actualPosition,
          isCompleted: false,
        ),
      );
    } catch (e) {
      print('🎯 [seek] ❌ FAILED: $e');
      rethrow;
    } finally {
      // 清除 Seeking 标志，恢复流监听
      _isSeeking = false;
      print('🎯 [seek] END - _isSeeking reset to false');
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
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
