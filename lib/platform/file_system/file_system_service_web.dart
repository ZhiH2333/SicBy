import 'package:file_picker/file_picker.dart';

import '../../domain/library_source.dart';
import '../../domain/media_locator.dart';
import '../../services/file_system_service.dart';
import '../../shared/audio_formats.dart';

class WebFileSystemService implements FileSystemService {
  @override
  bool get supportsFolderSelection => false;

  @override
  bool get supportsFileSelection => true;

  @override
  Future<LibrarySource?> pickSource() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: supportedAudioExtensions.toList(),
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final locators = <MediaLocator>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;

      locators.add(
        MediaLocator.bytes(
          bytes: bytes,
          displayName: file.name,
          mimeType: file.mimeType,
        ),
      );
    }

    if (locators.isEmpty) return null;
    return LibrarySource.files(locators);
  }

  @override
  Future<List<MediaFile>> listAudioFiles(LibrarySource source) async {
    if (source.kind != LibrarySourceKind.files || source.files == null) {
      return [];
    }

    return source.files!.map((locator) {
      final name = locator.displayName;
      final extension = _extensionFor(name);
      return MediaFile(
        locator: locator,
        name: name,
        extension: extension,
      );
    }).toList(growable: false);
  }

  String _extensionFor(String name) {
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == name.length - 1) return '';
    return name.substring(dotIndex + 1).toLowerCase();
  }
}

FileSystemService createPlatformFileSystemService() => WebFileSystemService();
