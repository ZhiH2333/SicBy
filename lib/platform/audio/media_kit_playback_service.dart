import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart' as mk;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

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
  SystemActionHandler? _systemActionHandler;
  File? _tempMediaFile;
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
    // 清理之前的临时文件
    await _cleanupTempFile();

    _state = _state.copyWith(
      trackId: track.id,
      isCompleted: false,
      position: Duration.zero,
    );
    _emit(_state);

    final media = await _createMedia(track.locator, track.id);
    await _player.open(media);
  }

  @override
  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // 对于某些音频格式（如 FLAC），duration 可能在播放开始后才可用
    // 因此我们等待 buffering 完成作为准备就绪的信号
    // 等待 buffering 状态变为 false（表示初始缓冲完成）
    await _player.stream.buffering
        .firstWhere((buffering) => !buffering)
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
    // 上层传递的音量范围是 0.0-1.0，需要转换为 media_kit 的 0-100 范围
    final volumePercent = (volume * 100.0).clamp(0.0, 100.0);
    await _player.setVolume(volumePercent);
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
    await _cleanupTempFile();
    await _player.dispose();
    await _stateController.close();
  }

  @override
  void setSystemActionHandler(SystemActionHandler? handler) {
    _systemActionHandler = handler;
    // media_kit 通过 libmpv 与 macOS MediaPlayer 框架集成
    // 系统媒体键（播放/暂停/下一首/上一首）由 libmpv 自动处理
    // 回调通过 SystemActionHandler 接口传递给上层业务逻辑
  }

  /// 创建 media_kit Media 对象
  Future<mk.Media> _createMedia(MediaLocator locator, String trackId) async {
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
        if (locator.bytes != null) {
          // 创建临时文件以支持字节流播放
          final tempFile = await _createTempFileFromBytes(
            locator.bytes!,
            trackId,
            locator.mimeType ?? 'audio/mpeg',
          );
          _tempMediaFile = tempFile;
          return mk.Media('file://${tempFile.path}');
        }
        break;
    }
    throw ArgumentError('Invalid media locator: $locator');
  }

  /// 从字节数组创建临时文件
  Future<File> _createTempFileFromBytes(
    List<int> bytes,
    String trackId,
    String mimeType,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final extension = _getExtensionFromMimeType(mimeType);
    final fileName = 'media_$trackId$extension';
    final tempFile = File(p.join(tempDir.path, fileName));

    await tempFile.writeAsBytes(bytes);
    return tempFile;
  }

  /// 根据 MIME 类型获取文件扩展名
  String _getExtensionFromMimeType(String mimeType) {
    final mimeMap = {
      'audio/mpeg': '.mp3',
      'audio/mp3': '.mp3',
      'audio/flac': '.flac',
      'audio/x-flac': '.flac',
      'audio/wav': '.wav',
      'audio/x-wav': '.wav',
      'audio/m4a': '.m4a',
      'audio/mp4': '.m4a',
      'audio/aac': '.aac',
      'audio/ogg': '.ogg',
      'audio/opus': '.opus',
    };
    return mimeMap[mimeType.toLowerCase()] ?? '.dat';
  }

  /// 清理临时媒体文件
  Future<void> _cleanupTempFile() async {
    if (_tempMediaFile != null) {
      try {
        if (await _tempMediaFile!.exists()) {
          await _tempMediaFile!.delete();
        }
      } catch (e) {
        // 忽略删除失败（文件可能已被删除）
      }
      _tempMediaFile = null;
    }
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
