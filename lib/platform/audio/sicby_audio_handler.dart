import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../../domain/media_locator.dart';
import '../../domain/repeat_mode.dart';
import '../../domain/track.dart';
import '../../services/audio_playback_service.dart';

class SicByAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  SystemActionHandler? _systemActionHandler;
  bool _resumeOnFocusGain = false;
  double? _duckedVolume;
  bool _suppressStopCallback = false;
  bool _needsPositionReset = false;

  SicByAudioHandler() {
    _configureSession();
    _listenToPlayer();
  }

  void setSystemActionHandler(SystemActionHandler? handler) {
    _systemActionHandler = handler;
  }

  Future<void> setTrack(Track track) async {
    final mediaItem = MediaItem(
      id: track.id,
      title: track.title,
      artist: track.artistName,
      album: track.albumName,
      artUri: track.artworkPath == null ? null : Uri.file(track.artworkPath!),
    );
    this.mediaItem.add(mediaItem);
    await _player.setAudioSource(_toSource(track.locator));
    _needsPositionReset = true;
  }

  Future<void> waitUntilReady({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final current = _player.duration;
    if (current != null && current > Duration.zero) return;
    await _player.durationStream
        .where((duration) => duration != null && duration > Duration.zero)
        .first
        .timeout(timeout);
  }

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  Future<void> setShuffleEnabled(bool enabled) async {
    await _player.setShuffleModeEnabled(enabled);
  }

  Future<void> setRepeatModeInternal(RepeatMode mode) async {
    await _player.setLoopMode(_toLoopMode(mode));
  }

  Future<void> stopFromApp() async {
    _suppressStopCallback = true;
    try {
      await stop();
    } finally {
      _suppressStopCallback = false;
    }
  }

  @override
  Future<void> play() async {
    if (_needsPositionReset) {
      final Duration? engineDuration = _player.duration;
      if (engineDuration != null && engineDuration > Duration.zero) {
        await _player.seek(Duration.zero);
      }
      _needsPositionReset = false;
      await Future.delayed(const Duration(milliseconds: 30));
    }
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) async {
    final Duration? engineDuration = _player.duration;
    if (engineDuration == null || engineDuration <= Duration.zero) {
      return;
    }
    final int clampedMs = position.inMilliseconds
        .clamp(0, engineDuration.inMilliseconds)
        .toInt();
    final Duration clamped = Duration(milliseconds: clampedMs);
    await _player.seek(clamped);
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
    if (!_suppressStopCallback) {
      await _systemActionHandler?.onStop();
    }
  }

  @override
  Future<void> skipToNext() async {
    await _systemActionHandler?.onSkipNext();
  }

  @override
  Future<void> skipToPrevious() async {
    await _systemActionHandler?.onSkipPrevious();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    await setShuffleEnabled(shuffleMode == AudioServiceShuffleMode.all);
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    await setRepeatModeInternal(_toRepeatMode(repeatMode));
  }

  void _listenToPlayer() {
    _player.playbackEventStream.listen(_broadcastState);
    _player.positionStream.listen((position) {
      playbackState.add(
        playbackState.value.copyWith(
          updatePosition: position,
          bufferedPosition: _player.bufferedPosition,
        ),
      );
    });
    _player.durationStream.listen((duration) {
      final current = mediaItem.value;
      if (current == null || duration == null) return;
      mediaItem.add(current.copyWith(duration: duration));
    });
  }

  Future<void> _configureSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    session.becomingNoisyEventStream.listen((_) {
      unawaited(pause());
    });
    session.interruptionEventStream.listen((event) {
      if (event.begin) {
        if (event.type == AudioInterruptionType.duck) {
          _duckedVolume = _player.volume;
          unawaited(
            _player.setVolume((_duckedVolume! * 0.5).clamp(0.0, 1.0)),
          );
        } else {
          _resumeOnFocusGain = _player.playing;
          unawaited(pause());
        }
      } else {
        if (event.type == AudioInterruptionType.duck) {
          if (_duckedVolume != null) {
            unawaited(
              _player.setVolume(_duckedVolume!.clamp(0.0, 1.0)),
            );
          }
          _duckedVolume = null;
        } else if (_resumeOnFocusGain) {
          _resumeOnFocusGain = false;
          unawaited(play());
        }
      }
    });
  }

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    final controls = <MediaControl>[
      MediaControl.skipToPrevious,
      if (playing) MediaControl.pause else MediaControl.play,
      MediaControl.stop,
      MediaControl.skipToNext,
    ];

    playbackState.add(
      playbackState.value.copyWith(
        controls: controls,
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: _toProcessingState(_player.processingState),
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        shuffleMode: _player.shuffleModeEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        repeatMode: _toAudioRepeatMode(_player.loopMode),
      ),
    );
  }

  AudioProcessingState _toProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  AudioServiceRepeatMode _toAudioRepeatMode(LoopMode mode) {
    switch (mode) {
      case LoopMode.off:
        return AudioServiceRepeatMode.none;
      case LoopMode.one:
        return AudioServiceRepeatMode.one;
      case LoopMode.all:
        return AudioServiceRepeatMode.all;
    }
  }

  RepeatMode _toRepeatMode(AudioServiceRepeatMode mode) {
    switch (mode) {
      case AudioServiceRepeatMode.none:
        return RepeatMode.off;
      case AudioServiceRepeatMode.one:
        return RepeatMode.one;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        return RepeatMode.all;
    }
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

  AudioSource _toSource(MediaLocator locator) {
    switch (locator.kind) {
      case MediaLocatorKind.path:
        return AudioSource.uri(Uri.file(locator.path!));
      case MediaLocatorKind.uri:
        return AudioSource.uri(Uri.parse(locator.uri!));
      case MediaLocatorKind.bytes:
        final mimeType = locator.mimeType ?? 'application/octet-stream';
        final uri = Uri.dataFromBytes(locator.bytes!, mimeType: mimeType);
        return AudioSource.uri(uri);
    }
  }
}
