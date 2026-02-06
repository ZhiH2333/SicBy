import '../domain/library_source.dart';
import 'file_system_service.dart';

abstract class BackgroundScanService {
  Future<List<MediaFile>> listAudioFiles(
    LibrarySource source, {
    bool recursive = true,
    bool includeHidden = false,
  });
}
