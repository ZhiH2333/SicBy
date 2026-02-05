import '../domain/library_source.dart';
import '../domain/media_locator.dart';

class MediaFile {
  final MediaLocator locator;
  final String name;
  final String extension;
  final int? sizeBytes;
  final DateTime? lastModified;

  const MediaFile({
    required this.locator,
    required this.name,
    required this.extension,
    this.sizeBytes,
    this.lastModified,
  });
}

abstract class FileSystemService {
  bool get supportsFolderSelection;
  bool get supportsFileSelection;

  Future<LibrarySource?> pickSource();
  Future<List<MediaFile>> listAudioFiles(
    LibrarySource source, {
    bool recursive = true,
    bool includeHidden = false,
  });
}
