import 'dart:io';
import 'dart:isolate';

import '../models/audio_metadata.dart';
import 'metadata_extractor.dart';

class MetadataBatchScanner {
  final MetadataExtractor _extractor;

  MetadataBatchScanner(this._extractor);

  Future<List<AudioMetadata>> scan(List<String> paths) async {
    if (paths.isEmpty) return const [];
    final existing = await Isolate.run(() => _filterExisting(paths));
    final results = <AudioMetadata>[];
    for (final path in existing) {
      final metadata = await _extractor.read(path);
      if (metadata != null) {
        results.add(metadata);
      }
    }
    return results;
  }
}

List<String> _filterExisting(List<String> paths) {
  final out = <String>[];
  for (final path in paths) {
    final file = File(path);
    if (file.existsSync()) {
      out.add(path);
    }
  }
  return out;
}
