import 'package:drift/drift.dart';
import 'package:drift_sqflite/drift_sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class MetadataDb extends DatabaseConnectionUser {
  final _MetadataAttachedDatabase _attached;

  MetadataDb() : this._(_openConnection());

  MetadataDb._(QueryExecutor executor)
    : _attached = _MetadataAttachedDatabase(executor),
      super(executor);

  @override
  GeneratedDatabase get attachedDatabase => _attached;

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

class _MetadataAttachedDatabase extends GeneratedDatabase {
  _MetadataAttachedDatabase(QueryExecutor executor) : super(executor);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];

  @override
  int get schemaVersion => 1;
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
