import 'dart:async';

import 'package:media_kit/media_kit.dart' as mk;

import '../../domain/media_locator.dart';
import '../../domain/playback_state.dart';
import '../../domain/repeat_mode.dart';
import '../../domain/track.dart' as domain;
import '../../services/audio_playback_service.dart';

/// 基于 media_kit 的播放服务实现
/// macOS 使用 libmpv 后端，提供精确的 seek 和 duration 支持
class MediaKitPlaybackService implements AudioPlaybackService {
  final mk.Player _player = mk.Player();
  final StreamController<PlaybackState> _stateController =
      StreamController<PlaybackState>.broadcast();

  PlaybackState _state = const PlaybackState();
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<bool>? _bufferingSubscription;
  StreamSubscription<bool>? _completedSubscription;

  MediaKitPlaybackService() {
    _setupListeners();
  }

  /// 设置所有播放状态监听器
  void _setupListeners() {
    // 监听播放位置
    _positionSubscription = _player.stream.position.listen((position) {
      _emit(_state.copyWith(position: position));
    });

    // 监听时长（仅使用引擎提供的真实时长）
    _durationSubscription = _player.stream.duration.listen((duration) {
      if (duration > Duration.zero) {
        _emit(_state.copyWith(duration: duration));
      }
    });

    // 监听播放状态
    _playingSubscription = _player.stream.playing.listen((playing) {
      _emit(_state.copyWith(isPlaying: playing));
    });

    // 监听缓冲状态
    _bufferingSubscription = _player.stream.buffering.listen((buffering) {
      _emit(_state.copyWith(isBuffering: buffering));
    });

    // 监听播放完成
    _completedSubscription = _player.stream.completed.listen((completed) {
      if (completed) {
        _emit(_state.copyWith(isCompleted: true));
      }
    });
  }

  @override
  Stream<PlaybackState> get playbackStateStream => _stateController.stream;

  @override
  Future<void> load(domain.Track track) async {
    _state = _state.copyWith(
      trackId: track.id,
      isCompleted: false,
      position: Duration.zero,
    );
    _emit(_state);

    final media = _createMedia(track.locator);
    await _player.open(media);
  }

  @override
  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // 等待 duration 流发出非零值
    await _player.stream.duration
        .firstWhere((duration) => duration > Duration.zero)
        .timeout(timeout);
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
    await _player.seek(position);
  }

  @override
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 100.0));
  }

  @override
  Future<void> setShuffleMode(bool enabled) async {
    // media_kit 不直接支持 shuffle，在上层处理
    _emit(_state.copyWith(shuffleEnabled: enabled));
  }

  @override
  Future<void> setRepeatMode(RepeatMode mode) async {
    final playlistMode = _toPlaylistMode(mode);
    await _player.setPlaylistMode(playlistMode);
    _emit(_state.copyWith(repeatMode: mode));
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _emit(const PlaybackState());
  }

  @override
  Future<void> dispose() async {
    await _positionSubscription?.cancel();
    await _durationSubscription?.cancel();
    await _playingSubscription?.cancel();
    await _bufferingSubscription?.cancel();
    await _completedSubscription?.cancel();
    await _player.dispose();
    await _stateController.close();
  }

  @override
  void setSystemActionHandler(SystemActionHandler? handler) {
    // media_kit 不直接支持系统媒体控制
    // 需要通过平台通道或第三方插件实现
    // 暂时保持空实现
  }

  /// 创建 media_kit Media 对象
  mk.Media _createMedia(MediaLocator locator) {
    switch (locator.kind) {
      case MediaLocatorKind.path:
        if (locator.path != null) {
          return mk.Media('file://${locator.path}');
        }
        break;
      case MediaLocatorKind.uri:
        if (locator.uri != null) {
          return mk.Media(locator.uri!);
        }
        break;
      case MediaLocatorKind.bytes:
        // media_kit 不直接支持字节流
        // 需要先写入临时文件
        throw UnsupportedError('Bytes locator not yet supported');
    }
    throw ArgumentError('Invalid media locator: $locator');
  }

  /// 将 RepeatMode 转换为 PlaylistMode
  mk.PlaylistMode _toPlaylistMode(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.off:
        return mk.PlaylistMode.none;
      case RepeatMode.one:
        return mk.PlaylistMode.single;
      case RepeatMode.all:
        return mk.PlaylistMode.loop;
    }
  }

  /// 发射状态更新
  void _emit(PlaybackState next) {
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }
}
