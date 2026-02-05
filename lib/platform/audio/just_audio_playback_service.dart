import 'dart:async';

import 'package:just_audio/just_audio.dart';

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

  JustAudioPlaybackService() {
    _player.playingStream.listen((playing) {
      _emit(_state.copyWith(isPlaying: playing));
    });

    _player.positionStream.listen((position) {
      _emit(_state.copyWith(position: position));
    });

    _player.durationStream.listen((duration) {
      if (duration != null) {
        _emit(_state.copyWith(duration: duration));
      }
    });

    _player.processingStateStream.listen((processingState) {
      final buffering =
          processingState == ProcessingState.buffering ||
          processingState == ProcessingState.loading;
      _emit(_state.copyWith(isBuffering: buffering));
    });

    _player.shuffleModeEnabledStream.listen((enabled) {
      _emit(_state.copyWith(shuffleEnabled: enabled));
    });

    _player.loopModeStream.listen((loopMode) {
      _emit(_state.copyWith(repeatMode: _toRepeatMode(loopMode)));
    });
  }

  @override
  Stream<PlaybackState> get playbackStateStream => _stateController.stream;

  @override
  Future<void> load(Track track) async {
    _emit(_state.copyWith(trackId: track.id));
    final locator = track.locator;
    switch (locator.kind) {
      case MediaLocatorKind.path:
        if (locator.path != null) {
          await _player.setFilePath(locator.path!);
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
    await _player.setVolume(volume.clamp(0.0, 1.0));
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _emit(const PlaybackState());
  }

  @override
  Future<void> dispose() async {
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
}
