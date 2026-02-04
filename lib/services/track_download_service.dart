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

abstract class TrackDownloadService {
  bool get isDownloading;
  Track? get currentTrack;

  Stream<DownloadProgress> download(Track track);
  Future<void> cancel();
}
