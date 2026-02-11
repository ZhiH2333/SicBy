import 'dart:async';

import '../domain/track.dart';

class DownloadProgress {
  final double progress;
  final bool isComplete;
  final String? error;

  const DownloadProgress({
    required this.progress,
    required this.isComplete,
    this.error,
  });
}

class TrackDownloadService {
  StreamController<DownloadProgress>? _controller;
  Timer? _timer;
  Track? _currentTrack;
  double _progress = 0.0;

  bool get isDownloading => _currentTrack != null;
  Track? get currentTrack => _currentTrack;

  Stream<DownloadProgress> download(Track track) {
    _cancelTimer();
    _currentTrack = track;
    _progress = 0.0;

    _controller = StreamController<DownloadProgress>.broadcast();
    _emit(progress: 0.0, isComplete: false);

    _timer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      _progress += 0.1;
      if (_progress >= 1.0) {
        _progress = 1.0;
        _emit(progress: _progress, isComplete: true);
        _cancelTimer();
      } else {
        _emit(progress: _progress, isComplete: false);
      }
    });

    return _controller!.stream;
  }

  Future<void> cancel() async {
    _cancelTimer();
  }

  Future<void> clearCache(Track track) async {
    if (_currentTrack?.id == track.id) {
      _cancelTimer();
    }
  }

  Future<void> clearAllCache() async {
    _cancelTimer();
  }

  void _emit({
    required double progress,
    required bool isComplete,
    String? error,
  }) {
    _controller?.add(
      DownloadProgress(
        progress: progress,
        isComplete: isComplete,
        error: error,
      ),
    );
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
    _currentTrack = null;
    _controller?.close();
    _controller = null;
  }
}
