import 'package:drift/drift.dart';
import 'package:drift_sqflite/drift_sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class MetadataDb extends DatabaseConnectionUser {
  MetadataDb() : super(DatabaseConnection(_openConnection()));

  Future<void> init() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS metadata_cache (
        file_path TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        album TEXT,
        duration_ms INTEGER NOT NULL,
        artwork_path TEXT,
        last_modified INTEGER,
        file_size_bytes INTEGER
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS metadata_cache_path_idx '
      'ON metadata_cache(file_path)',
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    final dbFile = path.join(directory.path, 'metadata_cache.sqlite');
    return SqfliteQueryExecutor.inDatabaseFolder(
      path: dbFile,
      logStatements: false,
    );
  });
}
