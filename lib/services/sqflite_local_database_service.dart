import 'dart:async';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/media_locator.dart';
import '../domain/track.dart';
import '../domain/track_availability.dart';
import 'local_database_service.dart';

class SqfliteLocalDatabaseService implements LocalDatabaseService {
  static const _dbName = 'sicby.db';
  static const _tableTracks = 'tracks';
  Database? _database;

  Future<Database> _db() async {
    if (_database != null) return _database!;
    final baseDir = await getApplicationSupportDirectory();
    final dbPath = path.join(baseDir.path, _dbName);
    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE $_tableTracks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            artist_name TEXT NOT NULL,
            album_name TEXT,
            duration_ms INTEGER NOT NULL,
            locator_kind TEXT NOT NULL,
            locator_path TEXT,
            locator_uri TEXT,
            locator_bytes BLOB,
            locator_mime_type TEXT,
            locator_display_name TEXT NOT NULL,
            artwork_path TEXT,
            last_modified INTEGER,
            size_bytes INTEGER,
            availability TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX tracks_locator_path_idx ON $_tableTracks(locator_path)',
        );
      },
    );
    return _database!;
  }

  @override
  Future<void> upsertTracks(List<Track> tracks) async {
    if (tracks.isEmpty) return;
    final db = await _db();
    final batch = db.batch();
    for (final track in tracks) {
      batch.insert(
        _tableTracks,
        _toMap(track),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<Track>> getAllTracks() async {
    final db = await _db();
    final rows = await db.query(_tableTracks);
    return rows.map(_fromMap).toList(growable: false);
  }

  @override
  Future<List<Track>> getTracksByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final db = await _db();
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.query(
      _tableTracks,
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
    return rows.map(_fromMap).toList(growable: false);
  }

  @override
  Future<void> deleteTracksNotIn(Set<String> ids) async {
    final db = await _db();
    if (ids.isEmpty) {
      await db.delete(_tableTracks);
      return;
    }
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.delete(
      _tableTracks,
      where: 'id NOT IN ($placeholders)',
      whereArgs: ids.toList(growable: false),
    );
  }

  @override
  Future<void> clear() async {
    final db = await _db();
    await db.delete(_tableTracks);
  }

  Map<String, Object?> _toMap(Track track) {
    final locator = track.locator;
    return {
      'id': track.id,
      'title': track.title,
      'artist_name': track.artistName,
      'album_name': track.albumName,
      'duration_ms': track.duration.inMilliseconds,
      'locator_kind': locator.kind.name,
      'locator_path': locator.path,
      'locator_uri': locator.uri,
      'locator_bytes': locator.bytes,
      'locator_mime_type': locator.mimeType,
      'locator_display_name': locator.displayName,
      'artwork_path': track.artworkPath,
      'last_modified': track.lastModified?.millisecondsSinceEpoch,
      'size_bytes': track.fileSizeBytes,
      'availability': track.availability.name,
    };
  }

  Track _fromMap(Map<String, Object?> row) {
    final kindName = row['locator_kind'] as String? ?? 'path';
    final kind = MediaLocatorKind.values.firstWhere(
      (value) => value.name == kindName,
      orElse: () => MediaLocatorKind.path,
    );
    final displayName = row['locator_display_name'] as String? ?? '';
    final locator = switch (kind) {
      MediaLocatorKind.uri => MediaLocator.uri(
        uri: row['locator_uri'] as String? ?? '',
        displayName: displayName,
      ),
      MediaLocatorKind.bytes => MediaLocator.bytes(
        bytes: Uint8List.fromList(
          (row['locator_bytes'] as List<int>? ?? const []),
        ),
        displayName: displayName,
        mimeType: row['locator_mime_type'] as String?,
      ),
      MediaLocatorKind.path => MediaLocator.path(
        path: row['locator_path'] as String? ?? '',
        displayName: displayName,
      ),
    };

    final availabilityName = row['availability'] as String? ?? 'local';
    final availability = TrackAvailability.values.firstWhere(
      (value) => value.name == availabilityName,
      orElse: () => TrackAvailability.local,
    );

    return Track(
      id: row['id'] as String,
      title: row['title'] as String? ?? '',
      artistName: row['artist_name'] as String? ?? '',
      duration: Duration(milliseconds: row['duration_ms'] as int? ?? 0),
      locator: locator,
      albumName: row['album_name'] as String?,
      artworkPath: row['artwork_path'] as String?,
      lastModified: row['last_modified'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['last_modified'] as int),
      fileSizeBytes: row['size_bytes'] as int?,
      availability: availability,
    );
  }
}
