import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../../domain/library_source.dart';
import '../../domain/media_locator.dart';
import '../../services/file_system_service.dart';
import '../../shared/audio_formats.dart';

class IoFileSystemService implements FileSystemService {
  @override
  bool get supportsFolderSelection => true;

  @override
  bool get supportsFileSelection => false;

  @override
  Future<LibrarySource?> pickSource() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null || path.isEmpty) {
      return null;
    }
    return LibrarySource.folder(path);
  }

  @override
  Future<List<MediaFile>> listAudioFiles(
    LibrarySource source, {
    bool recursive = true,
    bool includeHidden = false,
  }) async {
    if (source.kind != LibrarySourceKind.folder || source.folderPath == null) {
      return [];
    }

    final dir = Directory(source.folderPath!);
    if (!await dir.exists()) {
      return [];
    }

    final files = <MediaFile>[];
    await for (final entity in dir.list(
      recursive: recursive,
      followLinks: false,
    )) {
      if (entity is! File) continue;
      final path = entity.path;
      if (!includeHidden && _isHiddenPath(path)) continue;
      final extension = _extensionFor(path);
      if (!supportedAudioExtensions.contains(extension)) continue;

      final stat = await entity.stat();
      final name = path.split(Platform.pathSeparator).last;

      files.add(
        MediaFile(
          locator: MediaLocator.path(path: path, displayName: name),
          name: name,
          extension: extension,
          sizeBytes: stat.size,
          lastModified: stat.modified,
        ),
      );
    }

    return files;
  }

  bool _isHiddenPath(String path) {
    final separator = Platform.pathSeparator;
    return path.split(separator).any((segment) => segment.startsWith('.'));
  }

  String _extensionFor(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == path.length - 1) return '';
    return path.substring(dotIndex + 1).toLowerCase();
  }
}

FileSystemService createPlatformFileSystemService() => IoFileSystemService();
