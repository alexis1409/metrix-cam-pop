import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'database_tables.dart';

/// Singleton service for managing SQLite database
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static const int _databaseVersion = 1;
  static const String _databaseName = 'metrix_cam_pop.db';

  /// Get the database instance, initializing if necessary
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Sync metadata table - tracks cache validity
    await db.execute('''
      CREATE TABLE ${DatabaseTables.syncMetadata} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT,
        last_sync_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        user_id TEXT,
        UNIQUE(entity_type, entity_id, user_id)
      )
    ''');

    // Pending operations queue
    await db.execute('''
      CREATE TABLE ${DatabaseTables.pendingOperations} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL UNIQUE,
        operation_type TEXT NOT NULL,
        status TEXT DEFAULT '${DatabaseTables.statusPending}',
        payload TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        max_retries INTEGER DEFAULT ${DatabaseTables.defaultMaxRetries},
        last_error TEXT,
        created_at INTEGER NOT NULL,
        user_id TEXT NOT NULL
      )
    ''');

    // Tiendas pendientes cache
    await db.execute('''
      CREATE TABLE ${DatabaseTables.tiendasPendientesCache} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        campania_id TEXT NOT NULL,
        detalle_index INTEGER NOT NULL,
        raw_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE(user_id, campania_id, detalle_index)
      )
    ''');

    // Claves cache
    await db.execute('''
      CREATE TABLE ${DatabaseTables.clavesCache} (
        id TEXT PRIMARY KEY,
        medio_id TEXT,
        raw_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Local photos
    await db.execute('''
      CREATE TABLE ${DatabaseTables.localPhotos} (
        id TEXT PRIMARY KEY,
        file_path TEXT NOT NULL,
        tienda_id TEXT NOT NULL,
        latitud REAL,
        longitud REAL,
        is_uploaded INTEGER DEFAULT 0,
        pending_operation_id TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    // App settings cache
    await db.execute('''
      CREATE TABLE ${DatabaseTables.appSettings} (
        id INTEGER PRIMARY KEY DEFAULT 1,
        settings_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Create indexes for common queries
    await db.execute('''
      CREATE INDEX idx_pending_ops_status
      ON ${DatabaseTables.pendingOperations}(status, user_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_tiendas_cache_user_campania
      ON ${DatabaseTables.tiendasPendientesCache}(user_id, campania_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_sync_metadata_type
      ON ${DatabaseTables.syncMetadata}(entity_type, user_id)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future migrations here
    // Example:
    // if (oldVersion < 2) {
    //   await db.execute('ALTER TABLE ...');
    // }
  }

  /// Close the database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Delete all data (useful for logout)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete(DatabaseTables.syncMetadata);
    await db.delete(DatabaseTables.pendingOperations);
    await db.delete(DatabaseTables.tiendasPendientesCache);
    await db.delete(DatabaseTables.clavesCache);
    await db.delete(DatabaseTables.localPhotos);
    await db.delete(DatabaseTables.appSettings);
  }

  /// Clear only cached data (keeps pending operations)
  Future<void> clearCache() async {
    final db = await database;
    await db.delete(DatabaseTables.syncMetadata);
    await db.delete(DatabaseTables.tiendasPendientesCache);
    await db.delete(DatabaseTables.clavesCache);
    await db.delete(DatabaseTables.appSettings);
  }
}
