import 'package:audio_service/audio_service.dart';
import '../state/playback_controller.dart';
import '../state/ui_models.dart';

/// 处理后台音频和系统媒体控制的 AudioHandler
/// 
/// 功能：
/// - 后台播放保活
/// - 系统通知栏控制
/// - 锁屏控制集成
/// - 媒体按钮事件处理
class SicbyAudioHandler extends BaseAudioHandler {
  PlaybackController? _playbackController;
  
  SicbyAudioHandler() {
    // 初始化时更新一次状态
    updatePlaybackState();
  }

  /// 设置 PlaybackController
  /// 
  /// 由 ServiceProviders 在初始化后调用
  void setPlaybackController(PlaybackController controller) {
    _playbackController = controller;
    updatePlaybackState();
  }

  /// 更新系统播放状态
  /// 
  /// 当 PlaybackController 状态变化时调用
  /// 更新通知栏、锁屏等系统媒体信息
  void updatePlaybackState([UiPlaybackState? state]) {
    if (state == null) return;
    
    // 更新 MediaItem (当前播放的曲目信息)
    if (state.currentTrack != null) {
      mediaItem.add(_trackToMediaItem(state.currentTrack!));
    }
    
    // 更新播放状态
    final controls = <MediaControl>[];
    
    // 添加上一曲按钮
    controls.add(MediaControl.skipToPrevious);
    
    // 添加播放/暂停按钮
    if (state.isPlaying) {
      controls.add(MediaControl.pause);
    } else {
      controls.add(MediaControl.play);
    }
    
    // 添加下一曲按钮
    controls.add(MediaControl.skipToNext);
    
    playbackState.add(PlaybackState(
      controls: controls,
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _getProcessingState(state),
      playing: state.isPlaying,
      updatePosition: state.position,
      bufferedPosition: state.position,
      speed: 1.0,
      queueIndex: state.queueIndex,
    ));
  }

  /// 根据播放状态获取处理状态
  AudioProcessingState _getProcessingState(UiPlaybackState state) {
    if (state.isBuffering) {
      return AudioProcessingState.buffering;
    } else if (state.isPlaying) {
      return AudioProcessingState.ready;
    } else if (state.currentTrack != null) {
      return AudioProcessingState.ready;
    } else {
      return AudioProcessingState.idle;
    }
  }

  /// 将 UiTrack 转换为 MediaItem
  MediaItem _trackToMediaItem(UiTrack track) {
    return MediaItem(
      id: track.id,
      album: track.albumName ?? '未知专辑',
      title: track.title,
      artist: track.artistName,
      duration: track.duration,
      artUri: _getArtUri(track),
    );
  }

  /// 获取专辑封面 URI
  Uri? _getArtUri(UiTrack track) {
    if (track.artworkPath == null) return null;
    
    try {
      // 如果已经是 URI 格式，直接解析
      if (track.artworkPath!.startsWith('http') || 
          track.artworkPath!.startsWith('file://')) {
        return Uri.parse(track.artworkPath!);
      }
      
      // 本地文件路径，转换为 file:// URI
      return Uri.file(track.artworkPath!);
    } catch (e) {
      // 解析失败，返回 null
      // ignore: avoid_print
      print('⚠️ [AudioHandler] 封面 URI 解析失败: $e');
      return null;
    }
  }

  // ========== 系统媒体按钮事件处理 ==========

  @override
  Future<void> play() async {
    if (_playbackController == null) return;
    
    // 切换到播放状态
    await _playbackController!.togglePlayPause();
  }

  @override
  Future<void> pause() async {
    if (_playbackController == null) return;
    
    // 切换到暂停状态
    await _playbackController!.togglePlayPause();
  }

  @override
  Future<void> skipToNext() async {
    if (_playbackController == null) return;
    await _playbackController!.next();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_playbackController == null) return;
    await _playbackController!.previous();
  }

  @override
  Future<void> seek(Duration position) async {
    if (_playbackController == null) return;
    await _playbackController!.seekToMilliseconds(position.inMilliseconds);
  }

  @override
  Future<void> stop() async {
    if (_playbackController == null) return;
    await _playbackController!.stop();
    await super.stop(); // 关闭 AudioService
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    // 跳转到队列中的指定歌曲
    // 注意：这需要访问当前队列，暂时留空
    // 将来可以通过传递队列状态来实现
    // ignore: avoid_print
    print('⚠️ [AudioHandler] skipToQueueItem not implemented yet');
  }

  /// 用户从任务列表移除应用
  @override
  Future<void> onTaskRemoved() async {
    // 用户明确移除应用，停止播放
    await stop();
  }
}
