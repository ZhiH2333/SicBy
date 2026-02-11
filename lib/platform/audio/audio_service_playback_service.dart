import 'dart:async';

import 'package:audio_service/audio_service.dart' as audio_service;

import '../../domain/playback_state.dart';
import '../../domain/repeat_mode.dart';
import '../../domain/track.dart';
import '../../services/audio_playback_service.dart';
import 'sicby_audio_handler.dart';

class AudioServicePlaybackService implements AudioPlaybackService {
  final StreamController<PlaybackState> _stateController =
      StreamController<PlaybackState>.broadcast();
  final Future<SicByAudioHandler> _handlerFuture;
  SicByAudioHandler? _handler;
  PlaybackState _state = const PlaybackState();
  audio_service.MediaItem? _currentItem;

  AudioServicePlaybackService._(this._handlerFuture) {
    _init();
  }

  static AudioServicePlaybackService create() {
    final Future<SicByAudioHandler> handlerFuture =
        audio_service.AudioService.init(
          builder: () => SicByAudioHandler(),
          config: audio_service.AudioServiceConfig(
            androidNotificationChannelId: 'com.example.sicby.playback',
            androidNotificationChannelName: 'Playback',
            androidNotificationOngoing: false,
            androidStopForegroundOnPause: false,
          ),
        );

    return AudioServicePlaybackService._(handlerFuture);
  }

  @override
  Stream<PlaybackState> get playbackStateStream => _stateController.stream;

  @override
  Future<void> load(Track track) async {
    await _withHandler((handler) async {
      await handler.setTrack(track);
    });
    _emit(_state.copyWith(trackId: track.id, isCompleted: false));
  }

  @override
  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_handler != null) {
      await _handler!.waitUntilReady(timeout: timeout);
    }
  }

  @override
  Future<void> play() async {
    await _withHandler((handler) => handler.play());
  }

  @override
  Future<void> pause() async {
    await _withHandler((handler) => handler.pause());
  }

  @override
  Future<void> seek(Duration position) async {
    await _withHandler((handler) => handler.seek(position));
  }

  @override
  Future<void> setVolume(double volume) async {
    await _withHandler((handler) => handler.setVolume(volume));
  }

  @override
  Future<void> setShuffleMode(bool enabled) async {
    await _withHandler((handler) => handler.setShuffleEnabled(enabled));
    _emit(_state.copyWith(shuffleEnabled: enabled));
  }

  @override
  Future<void> setRepeatMode(RepeatMode mode) async {
    await _withHandler((handler) => handler.setRepeatModeInternal(mode));
    _emit(_state.copyWith(repeatMode: mode));
  }

  @override
  Future<void> stop() async {
    await _withHandler((handler) => handler.stopFromApp());
    _emit(const PlaybackState());
  }

  @override
  Future<void> dispose() async {
    await _stateController.close();
  }

  @override
  void setSystemActionHandler(SystemActionHandler? handler) {
    unawaited(_withHandler((audioHandler) {
      audioHandler.setSystemActionHandler(handler);
      return Future.value();
    }));
  }

  Future<void> _init() async {
    final handler = await _handlerFuture;
    _handler = handler;
    handler.playbackState.listen(_onPlaybackState);
    handler.mediaItem.listen(_onMediaItem);
  }

  Future<T> _withHandler<T>(
    Future<T> Function(SicByAudioHandler handler) action,
  ) async {
    final handler = _handler ?? await _handlerFuture;
    _handler = handler;
    return action(handler);
  }

  void _onMediaItem(audio_service.MediaItem? item) {
    _currentItem = item;
    if (item == null) return;
    _emit(
      _state.copyWith(
        trackId: item.id,
        duration: item.duration ?? _state.duration,
      ),
    );
  }

  void _onPlaybackState(audio_service.PlaybackState state) {
    final isBuffering =
        state.processingState == audio_service.AudioProcessingState.loading ||
        state.processingState == audio_service.AudioProcessingState.buffering;
    final isCompleted =
        state.processingState == audio_service.AudioProcessingState.completed;
    final duration = _currentItem?.duration ?? _state.duration;
    final position =
        isCompleted && duration > Duration.zero ? duration : state.updatePosition;
    _emit(
      _state.copyWith(
        trackId: _currentItem?.id,
        isPlaying: state.playing,
        isBuffering: isBuffering,
        isCompleted: isCompleted,
        position: position,
        duration: duration,
        shuffleEnabled:
            state.shuffleMode == audio_service.AudioServiceShuffleMode.all,
        repeatMode: _toRepeatMode(state.repeatMode),
      ),
    );
  }

  RepeatMode _toRepeatMode(audio_service.AudioServiceRepeatMode mode) {
    switch (mode) {
      case audio_service.AudioServiceRepeatMode.none:
        return RepeatMode.off;
      case audio_service.AudioServiceRepeatMode.one:
        return RepeatMode.one;
      case audio_service.AudioServiceRepeatMode.all:
      case audio_service.AudioServiceRepeatMode.group:
        return RepeatMode.all;
    }
  }

  void _emit(PlaybackState next) {
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }
}
