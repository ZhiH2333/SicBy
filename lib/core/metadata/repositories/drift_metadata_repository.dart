import 'package:drift/drift.dart';

import '../db/metadata_db.dart';
import '../models/audio_metadata.dart';
import 'metadata_repository.dart';

class DriftMetadataRepository implements MetadataRepository {
  final MetadataDb _db;
  bool _initialized = false;

  DriftMetadataRepository(this._db);

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await _db.init();
    _initialized = true;
  }

  @override
  Future<AudioMetadata?> getByPath(String path) async {
    await _ensureInit();
    final result = await _db.customSelect(
      'SELECT * FROM metadata_cache WHERE file_path = ?',
      variables: [Variable.withString(path)],
    ).getSingleOrNull();
    return result == null ? null : _toModel(result);
  }

  @override
  Future<List<AudioMetadata>> getByPaths(List<String> paths) async {
    if (paths.isEmpty) return const [];
    await _ensureInit();
    final placeholders = List.filled(paths.length, '?').join(',');
    final variables = paths.map(Variable.withString).toList(growable: false);
    final rows = await _db.customSelect(
      'SELECT * FROM metadata_cache WHERE file_path IN ($placeholders)',
      variables: variables,
    ).get();
    return rows.map(_toModel).toList(growable: false);
  }

  @override
  Future<void> upsert(AudioMetadata metadata) async {
    await _ensureInit();
    await _db.customStatement(
      '''
      INSERT OR REPLACE INTO metadata_cache (
        file_path, title, artist, album, duration_ms, artwork_path,
        last_modified, file_size_bytes
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        metadata.path,
        metadata.title,
        metadata.artist,
        metadata.album,
        metadata.duration.inMilliseconds,
        metadata.artworkPath,
        metadata.lastModified?.millisecondsSinceEpoch,
        metadata.fileSizeBytes,
      ],
    );
  }

  @override
  Future<void> deleteByPaths(List<String> paths) async {
    if (paths.isEmpty) return;
    await _ensureInit();
    final placeholders = List.filled(paths.length, '?').join(',');
    await _db.customStatement(
      'DELETE FROM metadata_cache WHERE file_path IN ($placeholders)',
      paths,
    );
  }

  AudioMetadata _toModel(QueryRow row) {
    return AudioMetadata(
      path: row.read<String>('file_path'),
      title: row.read<String>('title'),
      artist: row.read<String>('artist'),
      album: row.read<String?>('album'),
      duration: Duration(milliseconds: row.read<int>('duration_ms')),
      artworkPath: row.read<String?>('artwork_path'),
      lastModified: row.read<int?>('last_modified') == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
            row.read<int>('last_modified'),
          ),
      fileSizeBytes: row.read<int?>('file_size_bytes'),
    );
  }
}
