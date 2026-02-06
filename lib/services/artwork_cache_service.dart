import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

class ArtworkCacheService {
  Future<String?> saveArtworkBytes(String key, Uint8List bytes) async {
    if (bytes.isEmpty) return null;
    final directory = await _artworkDirectory();
    final filename = _filenameFor(key, bytes);
    final file = File('${directory.path}/$filename');
    if (!await file.exists()) {
      await file.writeAsBytes(bytes, flush: true);
    }
    return file.path;
  }

  Future<String?> saveArtworkFile(String key, File source) async {
    if (!await source.exists()) return null;
    final bytes = await source.readAsBytes();
    return saveArtworkBytes(key, bytes);
  }

  Future<Directory> _artworkDirectory() async {
    final base = await getApplicationSupportDirectory();
    final directory = Directory('${base.path}/artwork');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _filenameFor(String key, Uint8List bytes) {
    final digest = sha1.convert(utf8Bytes('$key:${bytes.length}')).toString();
    final extension = _extensionFor(bytes);
    return 'art_$digest.$extension';
  }

  List<int> utf8Bytes(String value) => value.codeUnits;

  String _extensionFor(Uint8List bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'png';
    }
    return 'jpg';
  }

  // Intentionally no resizing in the cache layer to avoid platform codec
  // failures that prevent artwork from being written.
}
