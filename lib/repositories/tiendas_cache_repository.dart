import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_service.dart';
import '../core/database/database_tables.dart';

/// Cached tienda data
class CachedTienda {
  final String userId;
  final String campaniaId;
  final int detalleIndex;
  final Map<String, dynamic> rawJson;
  final DateTime updatedAt;

  CachedTienda({
    required this.userId,
    required this.campaniaId,
    required this.detalleIndex,
    required this.rawJson,
    required this.updatedAt,
  });

  factory CachedTienda.fromMap(Map<String, dynamic> map) {
    return CachedTienda(
      userId: map['user_id'] as String,
      campaniaId: map['campania_id'] as String,
      detalleIndex: map['detalle_index'] as int,
      rawJson: jsonDecode(map['raw_json'] as String) as Map<String, dynamic>,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'campania_id': campaniaId,
      'detalle_index': detalleIndex,
      'raw_json': jsonEncode(rawJson),
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }
}

/// Repository for caching tiendas pendientes data
class TiendasCacheRepository {
  final DatabaseService _dbService;

  TiendasCacheRepository(this._dbService);

  /// Save tiendas pendientes for a user/campaign
  Future<void> saveTiendasPendientes({
    required String userId,
    required String campaniaId,
    required List<Map<String, dynamic>> tiendas,
  }) async {
    final db = await _dbService.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Use batch for efficiency
    final batch = db.batch();

    // First, delete existing entries for this user/campaign
    batch.delete(
      DatabaseTables.tiendasPendientesCache,
      where: 'user_id = ? AND campania_id = ?',
      whereArgs: [userId, campaniaId],
    );

    // Then insert all new entries
    for (var i = 0; i < tiendas.length; i++) {
      batch.insert(
        DatabaseTables.tiendasPendientesCache,
        {
          'user_id': userId,
          'campania_id': campaniaId,
          'detalle_index': i,
          'raw_json': jsonEncode(tiendas[i]),
          'updated_at': now,
        },
      );
    }

    await batch.commit(noResult: true);
  }

  /// Get cached tiendas pendientes for a user/campaign
  Future<List<Map<String, dynamic>>> getTiendasPendientes({
    required String userId,
    required String campaniaId,
  }) async {
    final db = await _dbService.database;
    final result = await db.query(
      DatabaseTables.tiendasPendientesCache,
      where: 'user_id = ? AND campania_id = ?',
      whereArgs: [userId, campaniaId],
      orderBy: 'detalle_index ASC',
    );

    return result.map((row) {
      return jsonDecode(row['raw_json'] as String) as Map<String, dynamic>;
    }).toList();
  }

  /// Get all cached campaigns for a user
  Future<List<String>> getCachedCampaignIds(String userId) async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      'SELECT DISTINCT campania_id FROM ${DatabaseTables.tiendasPendientesCache} '
      'WHERE user_id = ?',
      [userId],
    );
    return result.map((row) => row['campania_id'] as String).toList();
  }

  /// Delete cache for a specific campaign
  Future<void> deleteCacheForCampaign({
    required String userId,
    required String campaniaId,
  }) async {
    final db = await _dbService.database;
    await db.delete(
      DatabaseTables.tiendasPendientesCache,
      where: 'user_id = ? AND campania_id = ?',
      whereArgs: [userId, campaniaId],
    );
  }

  /// Delete all cache for a user
  Future<void> deleteAllCacheForUser(String userId) async {
    final db = await _dbService.database;
    await db.delete(
      DatabaseTables.tiendasPendientesCache,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  /// Update a single tienda in cache (e.g., after local changes)
  Future<void> updateTienda({
    required String userId,
    required String campaniaId,
    required int detalleIndex,
    required Map<String, dynamic> tiendaJson,
  }) async {
    final db = await _dbService.database;
    await db.insert(
      DatabaseTables.tiendasPendientesCache,
      {
        'user_id': userId,
        'campania_id': campaniaId,
        'detalle_index': detalleIndex,
        'raw_json': jsonEncode(tiendaJson),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Check if cache exists for a campaign
  Future<bool> hasCacheForCampaign({
    required String userId,
    required String campaniaId,
  }) async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseTables.tiendasPendientesCache} '
      'WHERE user_id = ? AND campania_id = ?',
      [userId, campaniaId],
    );
    return ((result.first['count'] as int?) ?? 0) > 0;
  }
}
