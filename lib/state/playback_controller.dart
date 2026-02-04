import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ui_models.dart';
import '../domain/playback_state.dart';
import '../domain/track.dart';
import '../domain/track_availability.dart';
import '../services/audio_playback_service.dart';
import '../services/cloud_file_service.dart';
import '../services/track_download_service.dart';
import 'service_providers.dart';
import 'settings_controller.dart';
import 'settings_models.dart';

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

  PlaybackController({
    required AudioPlaybackService audioPlaybackService,
    required TrackDownloadService downloadService,
    required CloudFileService cloudFileService,
    required AppSettings settings,
  })  : _audioPlaybackService = audioPlaybackService,
        _downloadService = downloadService,
        _cloudFileService = cloudFileService,
        _settings = settings,
      super(const UiPlaybackState()) {
    _audioPlaybackService.playbackStateStream.listen(_onPlaybackState);
  }

  /// Play a track from the library
  Future<void> play(UiTrack track, {List<UiTrack>? queue}) async {
    if (_isDownloadBlocked()) {
      _setDownloadFailure('Download in progress');
      return;
    }

    if (queue != null) {
      _queue = queue;
      _currentIndex = queue.indexOf(track);
    } else if (state.currentTrack != track) {
      _queue = [track];
      _currentIndex = 0;
    }

    state = state.copyWith(selectedTrack: track, pendingTrack: track);

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
    if (state.downloadStatus == DownloadStatus.downloading) return;

    if (state.isPlaying) {
      await _audioPlaybackService.pause();
      return;
    }
    await _audioPlaybackService.play();
  }

  /// Seek to position (0.0 to 1.0)
  Future<void> seekTo(double percent) async {
    if (state.downloadStatus == DownloadStatus.downloading) return;

    final position = Duration(
      milliseconds: (state.duration.inMilliseconds * percent).round(),
    );
    await _audioPlaybackService.seek(position);
  }

  /// Skip to next track
  Future<void> next() async {
    if (_isDownloadBlocked()) return;
    if (_queue.isEmpty) return;

    _currentIndex = (_currentIndex + 1) % _queue.length;
    final nextTrack = _queue[_currentIndex];
    await play(nextTrack, queue: _queue);
  }

  /// Skip to previous track
  Future<void> previous() async {
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
    await _cancelDownload();
    await _audioPlaybackService.stop();
    state = const UiPlaybackState();
  }

  void _onPlaybackState(PlaybackState playbackState) {
    state = state.copyWith(
      isPlaying: playbackState.isPlaying,
      isBuffering: playbackState.isBuffering,
      position: playbackState.position,
      duration: playbackState.duration,
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
    _settings = settings;
  }

  bool _isDownloadBlocked() {
    return _settings.disableSwitchDuringDownload &&
        state.downloadStatus == DownloadStatus.downloading;
  }

  Future<void> _handleCloudOnlyTrack(UiTrack track) async {
    if (!_settings.autoDownloadOnPlay) {
      _setDownloadFailure('Auto-download is disabled', trackId: track.id);
      return;
    }

    await _startDownload(track);
  }

  Future<void> _startDownload(UiTrack track) async {
    _updateQueueAvailability(track.id, TrackAvailability.downloading);

    await _cancelDownload();

    state = state.copyWith(
      downloadStatus: DownloadStatus.downloading,
      downloadProgress: 0.0,
      downloadingTrackId: track.id,
      downloadFailureReason: null,
      isPlaying: false,
    );

    _downloadSubscription = _downloadService
        .download(_toDomainTrack(track))
        .listen((progress) async {
      if (progress.error != null) {
        _updateQueueAvailability(track.id, TrackAvailability.failed);
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
        if (_settings.resumeAfterDownload) {
          await _startPlayback(
            track.copyWith(availability: TrackAvailability.ready),
          );
        }
      }
    });
  }

  Future<void> _cancelDownload() async {
    await _downloadService.cancel();
    await _downloadSubscription?.cancel();
    _downloadSubscription = null;
  }

  void _setDownloadFailure(String reason, {String? trackId}) {
    state = state.copyWith(
      downloadStatus: DownloadStatus.failed,
      downloadFailureReason: reason,
      downloadProgress: 0.0,
      downloadingTrackId: trackId ?? state.downloadingTrackId,
    );
  }

  void _updateQueueAvailability(String trackId, TrackAvailability availability) {
    _queue = _queue
        .map(
          (track) =>
              track.id == trackId
                  ? track.copyWith(availability: availability)
                  : track,
        )
        .toList(growable: false);
    if (state.currentTrack?.id == trackId) {
      state = state.copyWith(
        currentTrack: state.currentTrack!.copyWith(availability: availability),
      );
    }
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    _downloadService.cancel();
    super.dispose();
  }
}
