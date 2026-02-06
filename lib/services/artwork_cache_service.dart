import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

class ArtworkCacheService {
  Future<String?> saveArtworkBytes(
    String key,
    Uint8List bytes, {
    int maxDimension = 512,
  }) async {
    if (bytes.isEmpty) return null;
    final resized = await _resizeIfNeeded(bytes, maxDimension);
    final directory = await _artworkDirectory();
    final filename = _filenameFor(key, resized);
    final file = File('${directory.path}/$filename');
    if (!await file.exists()) {
      await file.writeAsBytes(resized, flush: true);
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

  Future<Uint8List> _resizeIfNeeded(
    Uint8List bytes,
    int maxDimension,
  ) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final width = image.width;
      final height = image.height;
      final maxSide = max(width, height);
      if (maxSide <= maxDimension) return bytes;
      final scale = maxDimension / maxSide;
      final targetWidth = max(1, (width * scale).round());
      final targetHeight = max(1, (height * scale).round());
      final resizedCodec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final resizedFrame = await resizedCodec.getNextFrame();
      final data = await resizedFrame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return data?.buffer.asUint8List() ?? bytes;
    } catch (_) {
      return bytes;
    }
  }
}
