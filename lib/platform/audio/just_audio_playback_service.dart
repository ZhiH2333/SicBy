import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../../domain/media_locator.dart';
import '../../domain/playback_state.dart';
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
          final uri = Uri.dataFromBytes(
            locator.bytes!,
            mimeType: mimeType,
          );
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
  Future<void> stop() async {
    await _player.stop();
    _emit(const PlaybackState());
  }

  @override
  Future<void> dispose() async {
    await _player.dispose();
    await _stateController.close();
  }

  void _emit(PlaybackState next) {
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }
}
