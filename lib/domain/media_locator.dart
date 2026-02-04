import 'dart:typed_data';

enum MediaLocatorKind { path, uri, bytes }

class MediaLocator {
  final MediaLocatorKind kind;
  final String? path;
  final String? uri;
  final Uint8List? bytes;
  final String? mimeType;
  final String displayName;

  const MediaLocator._({
    required this.kind,
    required this.displayName,
    this.path,
    this.uri,
    this.bytes,
    this.mimeType,
  });

  factory MediaLocator.path({required String path, required String displayName}) {
    return MediaLocator._(
      kind: MediaLocatorKind.path,
      path: path,
      displayName: displayName,
    );
  }

  factory MediaLocator.uri({required String uri, required String displayName}) {
    return MediaLocator._(
      kind: MediaLocatorKind.uri,
      uri: uri,
      displayName: displayName,
    );
  }

  factory MediaLocator.bytes({
    required Uint8List bytes,
    required String displayName,
    String? mimeType,
  }) {
    return MediaLocator._(
      kind: MediaLocatorKind.bytes,
      bytes: bytes,
      displayName: displayName,
      mimeType: mimeType,
    );
  }
}
