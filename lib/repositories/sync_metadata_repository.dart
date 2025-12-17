import 'package:sqflite/sqflite.dart';
import '../core/database/database_service.dart';
import '../core/database/database_tables.dart';

/// Repository for managing sync metadata (cache validity tracking)
class SyncMetadataRepository {
  final DatabaseService _dbService;

  SyncMetadataRepository(this._dbService);

  /// Check if cached data for an entity is still valid
  Future<bool> isCacheValid({
    required String entityType,
    String? entityId,
    String? userId,
  }) async {
    final db = await _dbService.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final conditions = ['entity_type = ?', 'expires_at > ?'];
    final args = <dynamic>[entityType, now];

    if (entityId != null) {
      conditions.add('entity_id = ?');
      args.add(entityId);
    } else {
      conditions.add('entity_id IS NULL');
    }

    if (userId != null) {
      conditions.add('user_id = ?');
      args.add(userId);
    }

    final result = await db.query(
      DatabaseTables.syncMetadata,
      where: conditions.join(' AND '),
      whereArgs: args,
      limit: 1,
    );

    return result.isNotEmpty;
  }

  /// Update or insert sync metadata
  Future<void> updateSyncMetadata({
    required String entityType,
    String? entityId,
    String? userId,
    int? cacheDurationMs,
  }) async {
    final db = await _dbService.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final duration = cacheDurationMs ?? DatabaseTables.cacheDurationMs;
    final expiresAt = now + duration;

    await db.insert(
      DatabaseTables.syncMetadata,
      {
        'entity_type': entityType,
        'entity_id': entityId,
        'last_sync_at': now,
        'expires_at': expiresAt,
        'user_id': userId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get the last sync time for an entity
  Future<DateTime?> getLastSyncTime({
    required String entityType,
    String? entityId,
    String? userId,
  }) async {
    final db = await _dbService.database;

    final conditions = ['entity_type = ?'];
    final args = <dynamic>[entityType];

    if (entityId != null) {
      conditions.add('entity_id = ?');
      args.add(entityId);
    } else {
      conditions.add('entity_id IS NULL');
    }

    if (userId != null) {
      conditions.add('user_id = ?');
      args.add(userId);
    }

    final result = await db.query(
      DatabaseTables.syncMetadata,
      columns: ['last_sync_at'],
      where: conditions.join(' AND '),
      whereArgs: args,
      limit: 1,
    );

    if (result.isEmpty) return null;

    final timestamp = result.first['last_sync_at'] as int?;
    return timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp)
        : null;
  }

  /// Invalidate cache for an entity type
  Future<void> invalidateCache({
    required String entityType,
    String? entityId,
    String? userId,
  }) async {
    final db = await _dbService.database;

    final conditions = ['entity_type = ?'];
    final args = <dynamic>[entityType];

    if (entityId != null) {
      conditions.add('entity_id = ?');
      args.add(entityId);
    }

    if (userId != null) {
      conditions.add('user_id = ?');
      args.add(userId);
    }

    await db.delete(
      DatabaseTables.syncMetadata,
      where: conditions.join(' AND '),
      whereArgs: args,
    );
  }

  /// Invalidate all cache for a user
  Future<void> invalidateAllCacheForUser(String userId) async {
    final db = await _dbService.database;
    await db.delete(
      DatabaseTables.syncMetadata,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }
}
