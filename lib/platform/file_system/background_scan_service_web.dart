import '../../domain/library_source.dart';
import '../../services/background_scan_service.dart';
import '../../services/file_system_service.dart';
import 'file_system_service_web.dart';

class WebBackgroundScanService implements BackgroundScanService {
  final FileSystemService _fileSystemService = WebFileSystemService();

  @override
  Future<List<MediaFile>> listAudioFiles(
    LibrarySource source, {
    bool recursive = true,
    bool includeHidden = false,
  }) {
    return _fileSystemService.listAudioFiles(
      source,
      recursive: recursive,
      includeHidden: includeHidden,
    );
  }
}

BackgroundScanService createPlatformBackgroundScanService() =>
    WebBackgroundScanService();
