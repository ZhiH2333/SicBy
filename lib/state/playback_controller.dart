import 'dart:async';
import 'dart:math';

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
import 'local_library_provider.dart';

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
      ref.listen(localLibraryProvider, (previous, next) {
        controller.syncQueueMetadata(next.tracks);
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
  final Random _random = Random();
  final List<int> _shuffleBag = [];
  final List<int> _shuffleHistory = [];
  bool _wasPlaying = false;
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
    _audioPlaybackService.setSystemActionHandler(
      _PlaybackSystemActionHandler(this),
    );
    Future.microtask(() => _applyDefaults(_settings));
    Future.microtask(() => setVolume(state.volume));
  }

  /// Play a track from the library
  Future<void> play(UiTrack track, {List<UiTrack>? queue}) async {
    // ignore: avoid_print
    print('🎵 play() called with track=${track.title}');
    _handleIntent(_PlaybackIntent.play);
    if (_isDownloadBlocked()) {
      _setDownloadFailure('Download in progress');
      return;
    }

    if (state.downloadStatus == DownloadStatus.downloading) {
      await _cancelDownload();
    }

    var queueChanged = false;
    if (queue != null) {
      final queueCopy = List<UiTrack>.from(queue);
      var index = queueCopy.indexWhere((item) => item.id == track.id);
      if (index == -1) {
        queueCopy.insert(0, track);
        index = 0;
      }
      queueChanged = !_isSameQueue(queueCopy);
      _queue = queueCopy;
      _currentIndex = index;
      // ignore: avoid_print
      print('  Queue provided: ${_queue.length} tracks, currentIndex=$_currentIndex');
      _sessionState = _sessionState.copyWith(
        queueIds: _queue.map((item) => item.id).toList(growable: false),
      );
    } else if (state.currentTrack != track) {
      _queue = [track];
      _currentIndex = 0;
      queueChanged = true;
      // ignore: avoid_print
      print('  Single track mode');
      _sessionState = _sessionState.copyWith(queueIds: [track.id]);
    }

    if (state.shuffleEnabled && queueChanged) {
      _resetShuffle(true);
    }

    state = state.copyWith(
      selectedTrack: track,
      pendingTrack: track,
      queue: _queue,
      queueIndex: _currentIndex,
      position: Duration.zero,
      duration: Duration.zero,
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
    // ignore: avoid_print
    print('🎵 _startPlayback() starting for track=${track.title}');
    state = state.copyWith(pendingTrack: track);
    try {
      final domainTrack = _toDomainTrack(track);
      await _audioPlaybackService.load(domainTrack);
      state = state.copyWith(position: Duration.zero);
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
      // ignore: avoid_print
      print('🎵 _startPlayback() completed, currentTrack now=${state.currentTrack?.title}');
      _transitionTo(PlaybackStatus.playing);
    } catch (e) {
      // ignore: avoid_print
      print('🎵 _startPlayback() error: $e');
      state = state.copyWith(isPlaying: false);
      _transitionTo(PlaybackStatus.idle);
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    _logPauseState('>>> BEFORE togglePlayPause');
    _handleIntent(_PlaybackIntent.togglePlayPause);
    if (state.downloadStatus == DownloadStatus.downloading) return;

    if (state.isPlaying) {
      // ignore: avoid_print
      print('🎵 togglePlayPause: isPlaying=true, calling pause()');
      await _audioPlaybackService.pause();
      _logPauseState('<<< AFTER pause() call');
      return;
    }
    // ignore: avoid_print
    print('🎵 togglePlayPause: isPlaying=false, calling play()');
    await _audioPlaybackService.play();
    _logPauseState('<<< AFTER play() call');
  }

  void _logPauseState(String label) {
    // Debug-only logging for pause desync diagnosis.
    // Avoids heavy string work in production builds.
    assert(() {
      // ignore: avoid_print
      print('🎵 $label');
      // ignore: avoid_print
      print('  Current track: ${state.currentTrack?.title}');
      // ignore: avoid_print
      print('  Queue index: ${state.queueIndex}');
      // ignore: avoid_print
      print('  Is playing: ${state.isPlaying}');
      return true;
    }());
  }

  /// Seek to position (0.0 to 1.0)
  Future<void> seekTo(double percent) async {
    _handleIntent(_PlaybackIntent.seek);
    if (state.downloadStatus == DownloadStatus.downloading) return;

    final effectiveDuration =
        state.duration > Duration.zero
            ? state.duration
            : state.currentTrack?.duration ?? Duration.zero;
    if (effectiveDuration == Duration.zero) return;
    final position = Duration(
      milliseconds: (effectiveDuration.inMilliseconds * percent).round(),
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
    // ignore: avoid_print
    print('🎵 next() called');
    // ignore: avoid_print
    print('  Before: currentTrack=${state.currentTrack?.title}, queueIndex=${state.queueIndex}');
    _handleIntent(_PlaybackIntent.next);
    if (_isDownloadBlocked()) return;
    if (_queue.isEmpty) return;

    final nextIndex = _nextIndex();
    if (nextIndex == null) return;
    if (state.shuffleEnabled) {
      _shuffleHistory.add(_currentIndex);
    }
    _currentIndex = nextIndex;
    final nextTrack = _queue[_currentIndex];
    // ignore: avoid_print
    print('  After: nextTrack=${nextTrack.title}, newQueueIndex=$_currentIndex');
    await _playFromQueue(nextTrack);
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

    final prevIndex = _previousIndex();
    if (prevIndex == null) return;
    _currentIndex = prevIndex;
    final prevTrack = _queue[_currentIndex];
    await _playFromQueue(prevTrack);
  }

  /// Stop playback
  Future<void> stop() async {
    _handleIntent(_PlaybackIntent.stop);
    await _cancelDownload();
    await _audioPlaybackService.stop();
    _sessionState = PlaybackSessionState.initial();
    state = const UiPlaybackState();
  }

  Future<void> handleSystemStop() async {
    _handleIntent(_PlaybackIntent.stop);
    await _cancelDownload();
    _sessionState = PlaybackSessionState.initial();
    state = const UiPlaybackState();
  }

  Future<void> toggleShuffle() async {
    final enabled = !state.shuffleEnabled;
    await _audioPlaybackService.setShuffleMode(enabled);
    state = state.copyWith(shuffleEnabled: enabled);
    _resetShuffle(enabled);
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
    if (state.shuffleEnabled) {
      _resetShuffle(true);
    }
  }

  void _onPlaybackState(PlaybackState playbackState) {
    final wasPlaying = _wasPlaying;
    _wasPlaying = playbackState.isPlaying;
    final effectiveDuration =
        playbackState.duration > Duration.zero
            ? playbackState.duration
            : state.currentTrack?.duration ?? playbackState.duration;
    var currentTrack = state.currentTrack;
    var queueIndex = state.queueIndex;
    var selectedTrack = state.selectedTrack;
    var pendingTrack = state.pendingTrack;
    final incomingId = playbackState.trackId;
    if (incomingId != null && incomingId.isNotEmpty) {
      if (currentTrack?.id != incomingId) {
        final index = _queue.indexWhere((track) => track.id == incomingId);
        if (index != -1) {
          final synced = _queue[index];
          currentTrack = synced;
          queueIndex = index;
          if (selectedTrack?.id == incomingId) {
            selectedTrack = synced;
          }
          if (pendingTrack?.id == incomingId) {
            pendingTrack = synced;
          }
          _currentIndex = index;
        }
      }
    }
    
    // Debug logging for metadata desync diagnosis
    assert(() {
      // ignore: avoid_print
      print('🎵 _onPlaybackState callback:');
      // ignore: avoid_print
      print('  Current track: ${state.currentTrack?.title}');
      // ignore: avoid_print
      print('  Queue index: ${state.queueIndex}');
      // ignore: avoid_print
      print('  wasPlaying: $wasPlaying → isPlaying: ${playbackState.isPlaying}');
      // ignore: avoid_print
      print('  Duration: ${playbackState.duration}');
      // ignore: avoid_print
      print('  Position: ${playbackState.position}');
      return true;
    }());
    
    _sessionState = _sessionState.copyWith(
      currentTrackId: currentTrack?.id ?? _sessionState.currentTrackId,
      position: playbackState.position,
      duration: effectiveDuration,
      isPlaying: playbackState.isPlaying,
    );
    state = state.copyWith(
      currentTrack: currentTrack,
      queueIndex: queueIndex,
      selectedTrack: selectedTrack,
      pendingTrack: pendingTrack,
      isPlaying: playbackState.isPlaying,
      isBuffering: playbackState.isBuffering,
      position: playbackState.position,
      duration: effectiveDuration,
      shuffleEnabled: playbackState.shuffleEnabled,
      repeatMode: playbackState.repeatMode,
    );

    final reachedEnd =
        playbackState.isCompleted ||
        (wasPlaying &&
            !playbackState.isPlaying &&
            playbackState.duration > Duration.zero &&
            playbackState.position >=
                playbackState.duration - const Duration(milliseconds: 600));
    
    // Debug: log track completion check
    assert(() {
      // ignore: avoid_print
      print('🎵 Track completion check:');
      // ignore: avoid_print
      print('  wasPlaying=$wasPlaying, !isPlaying=${!playbackState.isPlaying}');
      // ignore: avoid_print
      print('  duration=${playbackState.duration}, position=${playbackState.position}');
      // ignore: avoid_print
      print('  reachedEnd=$reachedEnd');
      return true;
    }());
    
    if (reachedEnd) {
      // ignore: avoid_print
      print('🎵 Track completion detected, calling _handleTrackCompletion()');
      _handleTrackCompletion();
    }

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

  void syncQueueMetadata(List<UiTrack> tracks) {
    if (_queue.isEmpty) return;
    final byId = {for (final track in tracks) track.id: track};
    final updatedQueue = _queue
        .map((track) => byId[track.id] ?? track)
        .toList(growable: false);
    final updatedCurrent = state.currentTrack == null
        ? null
        : byId[state.currentTrack!.id] ?? state.currentTrack;
    final updatedSelected = state.selectedTrack == null
        ? null
        : byId[state.selectedTrack!.id] ?? state.selectedTrack;
    final updatedPending = state.pendingTrack == null
        ? null
        : byId[state.pendingTrack!.id] ?? state.pendingTrack;
    _queue = updatedQueue;
    final index = updatedCurrent == null
        ? -1
        : updatedQueue.indexWhere((track) => track.id == updatedCurrent.id);
    _currentIndex = index;
    state = state.copyWith(
      queue: updatedQueue,
      queueIndex: index,
      currentTrack: updatedCurrent,
      selectedTrack: updatedSelected,
      pendingTrack: updatedPending,
    );
  }

  int? _nextIndex() {
    if (_queue.isEmpty) return null;
    if (state.shuffleEnabled) {
      if (_shuffleBag.isEmpty) {
        if (state.repeatMode == RepeatMode.off) return null;
        _resetShuffle(true);
      }
      if (_shuffleBag.isEmpty) return null;
      return _shuffleBag.removeAt(0);
    }

    final nextIndex = _currentIndex + 1;
    if (nextIndex >= _queue.length) {
      return state.repeatMode == RepeatMode.all ? 0 : null;
    }
    return nextIndex;
  }

  int? _previousIndex() {
    if (_queue.isEmpty) return null;
    if (state.shuffleEnabled && _shuffleHistory.isNotEmpty) {
      return _shuffleHistory.removeLast();
    }
    final prevIndex = _currentIndex - 1;
    if (prevIndex < 0) {
      return state.repeatMode == RepeatMode.all ? _queue.length - 1 : null;
    }
    return prevIndex;
  }

  void _resetShuffle(bool enabled) {
    _shuffleBag.clear();
    _shuffleHistory.clear();
    if (!enabled || _queue.length <= 1) return;
    final indices = List<int>.generate(_queue.length, (i) => i)
      ..remove(_currentIndex);
    indices.shuffle(_random);
    _shuffleBag.addAll(indices);
  }

  Future<void> _handleTrackCompletion() async {
    if (_queue.isEmpty) return;
    
    // ignore: avoid_print
    print('🎵 _handleTrackCompletion() called');
    // ignore: avoid_print
    print('  Before: currentTrack=${state.currentTrack?.title}, queueIndex=${state.queueIndex}');
    // ignore: avoid_print
    print('  repeatMode=${state.repeatMode}');

    if (state.repeatMode == RepeatMode.one) {
      // ignore: avoid_print
      print('  RepeatMode.one detected, restarting current track');
      await _audioPlaybackService.seek(Duration.zero);
      await _audioPlaybackService.play();
      return;
    }

    final nextIndex = _nextIndex();
    if (nextIndex == null) {
      // ignore: avoid_print
      print('  No next track, stopping playback');
      await _audioPlaybackService.stop();
      return;
    }
    if (state.shuffleEnabled) {
      _shuffleHistory.add(_currentIndex);
    }
    _currentIndex = nextIndex;
    final nextTrack = _queue[_currentIndex];
    // ignore: avoid_print
    print('  After: nextTrack=${nextTrack.title}, newQueueIndex=$_currentIndex');
    await _playFromQueue(nextTrack);
  }

  Future<void> _playFromQueue(UiTrack track) async {
    _handleIntent(_PlaybackIntent.play);
    if (_isDownloadBlocked()) {
      _setDownloadFailure('Download in progress');
      return;
    }

    if (state.downloadStatus == DownloadStatus.downloading) {
      await _cancelDownload();
    }

    state = state.copyWith(
      selectedTrack: track,
      pendingTrack: track,
      queue: _queue,
      queueIndex: _currentIndex,
      position: Duration.zero,
      duration: Duration.zero,
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

  bool _isSameQueue(List<UiTrack> newQueue) {
    if (_queue.length != newQueue.length) return false;
    for (var i = 0; i < _queue.length; i++) {
      if (_queue[i].id != newQueue[i].id) return false;
    }
    return true;
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

class _PlaybackSystemActionHandler implements SystemActionHandler {
  final PlaybackController _controller;

  _PlaybackSystemActionHandler(this._controller);

  @override
  Future<void> onSkipNext() {
    return _controller.next();
  }

  @override
  Future<void> onSkipPrevious() {
    return _controller.previous();
  }

  @override
  Future<void> onStop() {
    return _controller.handleSystemStop();
  }
}
