import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui_models.dart';
import '../domain/playback_state.dart';
import '../domain/track.dart';
import '../domain/track_availability.dart';
import '../domain/repeat_mode.dart';
import '../services/audio_playback_service.dart';
import '../services/cloud_file_service.dart';
import '../services/track_download_service.dart';
import 'service_providers.dart';
import 'settings_controller.dart';
import 'settings_models.dart';
import 'playback_session_state.dart';

/// Playback controller provider
final playbackControllerProvider =
    StateNotifierProvider<PlaybackController, UiPlaybackState>((ref) {
      final audioService = ref.read(audioPlaybackServiceProvider);
      final downloadService = ref.read(trackDownloadServiceProvider);
      final cloudFileService = ref.read(cloudFileServiceProvider);
      final settingsState = ref.read(settingsControllerProvider);
      ref.onDispose(audioService.dispose);
      final controller = PlaybackController(
        audioPlaybackService: audioService,
        downloadService: downloadService,
        cloudFileService: cloudFileService,
        settings: settingsState.settings,
      );
      ref.listen(settingsControllerProvider, (previous, next) {
        controller.updateSettings(next.settings);
      });
      return controller;
    });

/// Manages audio playback
class PlaybackController extends StateNotifier<UiPlaybackState> {
  final AudioPlaybackService _audioPlaybackService;
  final TrackDownloadService _downloadService;
  final CloudFileService _cloudFileService;
  AppSettings _settings;
  List<UiTrack> _queue = [];
  int _currentIndex = -1;
  StreamSubscription<DownloadProgress>? _downloadSubscription;
  PlaybackSessionState _sessionState = PlaybackSessionState.initial();

  PlaybackController({
    required AudioPlaybackService audioPlaybackService,
    required TrackDownloadService downloadService,
    required CloudFileService cloudFileService,
    required AppSettings settings,
  }) : _audioPlaybackService = audioPlaybackService,
       _downloadService = downloadService,
       _cloudFileService = cloudFileService,
       _settings = settings,
       super(const UiPlaybackState()) {
    _audioPlaybackService.playbackStateStream.listen(_onPlaybackState);
    Future.microtask(() => _applyDefaults(_settings));
    Future.microtask(() => setVolume(state.volume));
  }

  /// Play a track from the library
  Future<void> play(UiTrack track, {List<UiTrack>? queue}) async {
    _handleIntent(_PlaybackIntent.play);
    if (_isDownloadBlocked()) {
      _setDownloadFailure('Download in progress');
      return;
    }

    if (state.downloadStatus == DownloadStatus.downloading) {
      await _cancelDownload();
    }

    if (queue != null) {
      _queue = queue;
      _currentIndex = queue.indexOf(track);
      _sessionState = _sessionState.copyWith(
        queueIds: queue.map((item) => item.id).toList(growable: false),
      );
    } else if (state.currentTrack != track) {
      _queue = [track];
      _currentIndex = 0;
      _sessionState = _sessionState.copyWith(queueIds: [track.id]);
    }

    state = state.copyWith(
      selectedTrack: track,
      pendingTrack: track,
      queue: _queue,
      queueIndex: _currentIndex,
    );

    final cloudCheck = await preflightCloudCheck(track);
    final isCloudOnly =
        track.availability == TrackAvailability.cloudOnly ||
        cloudCheck.isCloudOnly;

    if (isCloudOnly) {
      _updateQueueAvailability(track.id, TrackAvailability.cloudOnly);
      await _handleCloudOnlyTrack(track, cloudCheck);
      return;
    }

    _transitionTo(PlaybackStatus.ready);
    await _startPlayback(track);
  }

  Future<CloudCheckResult> preflightCloudCheck(UiTrack track) async {
    return _cloudFileService.check(track.locator);
  }

  Future<void> _startPlayback(UiTrack track) async {
    state = state.copyWith(pendingTrack: track);
    try {
      final domainTrack = _toDomainTrack(track);
      await _audioPlaybackService.load(domainTrack);
      await _audioPlaybackService.play();
      _sessionState = _sessionState.copyWith(
        currentTrackId: track.id,
        source: _sourceFor(track),
        availability: track.availability,
      );
      state = state.copyWith(
        currentTrack: track,
        pendingTrack: null,
        downloadStatus: DownloadStatus.idle,
        downloadProgress: 0.0,
        downloadingTrackId: null,
        downloadFailureReason: null,
        downloadSizeMiB: null,
      );
      _transitionTo(PlaybackStatus.playing);
    } catch (e) {
      state = state.copyWith(isPlaying: false);
      _transitionTo(PlaybackStatus.idle);
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    _handleIntent(_PlaybackIntent.togglePlayPause);
    if (state.downloadStatus == DownloadStatus.downloading) return;

    if (state.isPlaying) {
      await _audioPlaybackService.pause();
      return;
    }
    await _audioPlaybackService.play();
  }

  /// Seek to position (0.0 to 1.0)
  Future<void> seekTo(double percent) async {
    _handleIntent(_PlaybackIntent.seek);
    if (state.downloadStatus == DownloadStatus.downloading) return;

    final position = Duration(
      milliseconds: (state.duration.inMilliseconds * percent).round(),
    );
    await _audioPlaybackService.seek(position);
  }

  Future<void> setVolume(double value) async {
    final next = value.clamp(0.0, 1.0);
    state = state.copyWith(volume: next);
    await _audioPlaybackService.setVolume(next);
  }

  /// Skip to next track
  Future<void> next() async {
    _handleIntent(_PlaybackIntent.next);
    if (_isDownloadBlocked()) return;
    if (_queue.isEmpty) return;

    _currentIndex = (_currentIndex + 1) % _queue.length;
    final nextTrack = _queue[_currentIndex];
    await play(nextTrack, queue: _queue);
  }

  /// Skip to previous track
  Future<void> previous() async {
    _handleIntent(_PlaybackIntent.previous);
    if (_isDownloadBlocked()) return;
    if (_queue.isEmpty) return;

    // If more than 3 seconds in, restart current track
    if (state.position.inSeconds > 3) {
      await _audioPlaybackService.seek(Duration.zero);
      return;
    }

    _currentIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
    final prevTrack = _queue[_currentIndex];
    await play(prevTrack, queue: _queue);
  }

  /// Stop playback
  Future<void> stop() async {
    _handleIntent(_PlaybackIntent.stop);
    await _cancelDownload();
    await _audioPlaybackService.stop();
    _sessionState = PlaybackSessionState.initial();
    state = const UiPlaybackState();
  }

  Future<void> toggleShuffle() async {
    await _audioPlaybackService.setShuffleMode(!state.shuffleEnabled);
  }

  Future<void> cycleRepeatMode() async {
    final nextMode = switch (state.repeatMode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    await _audioPlaybackService.setRepeatMode(nextMode);
  }

  void addToQueue(UiTrack track) {
    _queue = List<UiTrack>.from(_queue)..add(track);
    _syncQueueState();
  }

  void removeFromQueue(UiTrack track) {
    _queue = List<UiTrack>.from(_queue)
      ..removeWhere((item) => item.id == track.id);
    _syncQueueState();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final track = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, track);

    // Update index if current track moved
    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex -= 1;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex += 1;
    }

    _syncQueueState();
  }

  void _syncQueueState() {
    final currentId = state.currentTrack?.id;
    final index = currentId == null
        ? -1
        : _queue.indexWhere((track) => track.id == currentId);
    _currentIndex = index;
    state = state.copyWith(queue: List.from(_queue), queueIndex: _currentIndex);
  }

  void _onPlaybackState(PlaybackState playbackState) {
    _sessionState = _sessionState.copyWith(
      position: playbackState.position,
      duration: playbackState.duration,
      isPlaying: playbackState.isPlaying,
    );
    state = state.copyWith(
      isPlaying: playbackState.isPlaying,
      isBuffering: playbackState.isBuffering,
      position: playbackState.position,
      duration: playbackState.duration,
      shuffleEnabled: playbackState.shuffleEnabled,
      repeatMode: playbackState.repeatMode,
    );

    if (playbackState.isPlaying) {
      _transitionTo(PlaybackStatus.playing);
    } else if (state.playbackStatus == PlaybackStatus.playing) {
      _transitionTo(PlaybackStatus.paused);
    }
  }

  Track _toDomainTrack(UiTrack track) {
    return Track(
      id: track.id,
      title: track.title,
      artistName: track.artistName,
      duration: track.duration,
      locator: track.locator,
      albumName: track.albumName,
      availability: track.availability,
    );
  }

  void updateSettings(AppSettings settings) {
    final previous = _settings;
    _settings = settings;
    if (previous.shuffleDefault != settings.shuffleDefault ||
        previous.repeatModeDefault != settings.repeatModeDefault) {
      _applyDefaults(settings);
    }
  }

  Future<void> _applyDefaults(AppSettings settings) async {
    await _audioPlaybackService.setShuffleMode(settings.shuffleDefault);
    await _audioPlaybackService.setRepeatMode(
      _repeatModeFromSetting(settings.repeatModeDefault),
    );
    state = state.copyWith(
      shuffleEnabled: settings.shuffleDefault,
      repeatMode: _repeatModeFromSetting(settings.repeatModeDefault),
    );
  }

  RepeatMode _repeatModeFromSetting(String value) {
    switch (value) {
      case 'all':
        return RepeatMode.all;
      case 'one':
        return RepeatMode.one;
      case 'off':
      default:
        return RepeatMode.off;
    }
  }

  void _handleIntent(_PlaybackIntent intent) {
    // Intents are recorded for sequencing; state updates follow engine callbacks.
  }

  bool _transitionTo(PlaybackStatus next) {
    final current = state.playbackStatus;
    final allowed = _allowedTransitions[current] ?? const {};
    if (!allowed.contains(next)) {
      return false;
    }
    state = state.copyWith(playbackStatus: next);
    return true;
  }

  static const Map<PlaybackStatus, Set<PlaybackStatus>> _allowedTransitions = {
    PlaybackStatus.idle: {PlaybackStatus.ready, PlaybackStatus.pendingDownload},
    PlaybackStatus.ready: {
      PlaybackStatus.playing,
      PlaybackStatus.pendingDownload,
      PlaybackStatus.idle,
    },
    PlaybackStatus.playing: {
      PlaybackStatus.ready,
      PlaybackStatus.pendingDownload,
      PlaybackStatus.paused,
      PlaybackStatus.idle,
    },
    PlaybackStatus.paused: {
      PlaybackStatus.ready,
      PlaybackStatus.pendingDownload,
      PlaybackStatus.playing,
      PlaybackStatus.idle,
    },
    PlaybackStatus.pendingDownload: {PlaybackStatus.ready, PlaybackStatus.idle},
  };

  bool _isDownloadBlocked() {
    return _settings.disableSwitchDuringDownload &&
        state.downloadStatus == DownloadStatus.downloading;
  }

  Future<void> _handleCloudOnlyTrack(
    UiTrack track,
    CloudCheckResult cloudCheck,
  ) async {
    if (!_settings.autoDownloadOnPlay) {
      _setDownloadFailure('Auto-download is disabled', trackId: track.id);
      _transitionTo(PlaybackStatus.idle);
      return;
    }

    await _startDownload(track, cloudCheck.sizeMiB);
  }

  Future<void> _startDownload(UiTrack track, double sizeMiB) async {
    _updateQueueAvailability(track.id, TrackAvailability.downloading);

    await _cancelDownload();

    _transitionTo(PlaybackStatus.pendingDownload);
    state = state.copyWith(
      pendingTrack: track,
      downloadStatus: DownloadStatus.downloading,
      downloadProgress: 0.0,
      downloadingTrackId: track.id,
      downloadFailureReason: null,
      downloadSizeMiB: sizeMiB,
      isPlaying: false,
    );

    _downloadSubscription = _downloadService
        .download(_toDomainTrack(track))
        .listen((progress) async {
          if (progress.error != null) {
            _updateQueueAvailability(track.id, TrackAvailability.failed);
            await _downloadService.clearCache(_toDomainTrack(track));
            _setDownloadFailure(progress.error!, trackId: track.id);
            return;
          }

          state = state.copyWith(
            downloadProgress: progress.progress,
            downloadStatus: progress.isComplete
                ? DownloadStatus.completed
                : DownloadStatus.downloading,
          );

          if (progress.isComplete) {
            _updateQueueAvailability(track.id, TrackAvailability.ready);
            _transitionTo(PlaybackStatus.ready);
            if (_settings.resumeAfterDownload) {
              await _startPlayback(
                track.copyWith(availability: TrackAvailability.ready),
              );
            }
          }
        });
  }

  Future<void> _cancelDownload() async {
    final track = _downloadService.currentTrack;
    await _downloadService.cancel();
    if (track != null) {
      await _downloadService.clearCache(track);
    }
    await _downloadSubscription?.cancel();
    _downloadSubscription = null;
    state = state.copyWith(
      downloadStatus: DownloadStatus.idle,
      downloadProgress: 0.0,
      downloadingTrackId: null,
      downloadFailureReason: null,
      downloadSizeMiB: null,
    );
  }

  void _setDownloadFailure(String reason, {String? trackId}) {
    state = state.copyWith(
      downloadStatus: DownloadStatus.failed,
      downloadFailureReason: reason,
      downloadProgress: 0.0,
      downloadingTrackId: trackId ?? state.downloadingTrackId,
      pendingTrack: null,
    );
    _transitionTo(PlaybackStatus.idle);
  }

  void _updateQueueAvailability(
    String trackId,
    TrackAvailability availability,
  ) {
    _queue = _queue
        .map(
          (track) => track.id == trackId
              ? track.copyWith(availability: availability)
              : track,
        )
        .toList(growable: false);
    if (state.currentTrack?.id == trackId) {
      state = state.copyWith(
        currentTrack: state.currentTrack!.copyWith(availability: availability),
      );
    }
    if (state.selectedTrack?.id == trackId) {
      state = state.copyWith(
        selectedTrack: state.selectedTrack!.copyWith(
          availability: availability,
        ),
      );
    }
    if (state.pendingTrack?.id == trackId) {
      state = state.copyWith(
        pendingTrack: state.pendingTrack!.copyWith(availability: availability),
      );
    }
  }

  PlaybackSource _sourceFor(UiTrack track) {
    return track.availability == TrackAvailability.local ||
            track.availability == TrackAvailability.ready
        ? PlaybackSource.local
        : PlaybackSource.cloud;
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    _downloadService.cancel();
    super.dispose();
  }
}

enum _PlaybackIntent { play, togglePlayPause, seek, next, previous, stop }
