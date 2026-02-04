import 'media_locator.dart';

enum LibrarySourceKind { folder, files }

class LibrarySource {
  final LibrarySourceKind kind;
  final String? folderPath;
  final List<MediaLocator>? files;

  const LibrarySource._({this.kind = LibrarySourceKind.folder, this.folderPath, this.files});

  factory LibrarySource.folder(String path) {
    return LibrarySource._(kind: LibrarySourceKind.folder, folderPath: path);
  }

  factory LibrarySource.files(List<MediaLocator> files) {
    return LibrarySource._(kind: LibrarySourceKind.files, files: files);
  }
}
