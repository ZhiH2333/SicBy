import 'dart:io';
import 'dart:isolate';

import '../../domain/library_source.dart';
import '../../domain/media_locator.dart';
import '../../services/background_scan_service.dart';
import '../../services/file_system_service.dart';
import '../../shared/audio_formats.dart';

class IoBackgroundScanService implements BackgroundScanService {
  @override
  Future<List<MediaFile>> listAudioFiles(
    LibrarySource source, {
    bool recursive = true,
    bool includeHidden = false,
  }) async {
    if (source.kind != LibrarySourceKind.folder || source.folderPath == null) {
      return [];
    }

    final request = <String, Object?>{
      'path': source.folderPath!,
      'recursive': recursive,
      'includeHidden': includeHidden,
      'extensions': supportedAudioExtensions.toList(growable: false),
    };

    final results = await Isolate.run(() => _scanFolder(request));
    return results
        .map(
          (item) => MediaFile(
            locator: MediaLocator.path(
              path: item['path'] as String,
              displayName: item['name'] as String,
            ),
            name: item['name'] as String,
            extension: item['extension'] as String,
            sizeBytes: item['size'] as int?,
            lastModified: item['modified'] == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                  item['modified'] as int,
                ),
          ),
        )
        .toList(growable: false);
  }
}

List<Map<String, Object?>> _scanFolder(Map<String, Object?> request) {
  final path = request['path'] as String;
  final recursive = request['recursive'] as bool? ?? true;
  final includeHidden = request['includeHidden'] as bool? ?? false;
  final extensions =
      (request['extensions'] as List?)?.cast<String>() ?? const [];

  final dir = Directory(path);
  if (!dir.existsSync()) return const [];

  final files = <Map<String, Object?>>[];
  List<FileSystemEntity> entities;
  try {
    entities = dir.listSync(recursive: recursive, followLinks: false);
  } catch (_) {
    return const [];
  }

  for (final entity in entities) {
    if (entity is! File) continue;
    final filePath = entity.path;
    if (!includeHidden && _isHiddenPath(filePath)) continue;
    final extension = _extensionFor(filePath);
    if (!extensions.contains(extension)) continue;
    final stat = entity.statSync();
    final name = filePath.split(Platform.pathSeparator).last;

    files.add({
      'path': filePath,
      'name': name,
      'extension': extension,
      'size': stat.size,
      'modified': stat.modified.millisecondsSinceEpoch,
    });
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

BackgroundScanService createPlatformBackgroundScanService() =>
    IoBackgroundScanService();
