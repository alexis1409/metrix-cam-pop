import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_service.dart';
import '../core/database/database_tables.dart';

/// Cached clave data
class CachedClave {
  final String id;
  final String? medioId;
  final Map<String, dynamic> rawJson;
  final DateTime updatedAt;

  CachedClave({
    required this.id,
    this.medioId,
    required this.rawJson,
    required this.updatedAt,
  });

  factory CachedClave.fromMap(Map<String, dynamic> map) {
    return CachedClave(
      id: map['id'] as String,
      medioId: map['medio_id'] as String?,
      rawJson: jsonDecode(map['raw_json'] as String) as Map<String, dynamic>,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'medio_id': medioId,
      'raw_json': jsonEncode(rawJson),
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }
}

/// Repository for caching claves data (replaces ClavesCacheService)
class ClavesRepository {
  final DatabaseService _dbService;

  ClavesRepository(this._dbService);

  /// Save multiple claves to cache
  Future<void> saveClaves(List<Map<String, dynamic>> claves) async {
    final db = await _dbService.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final batch = db.batch();

    for (final clave in claves) {
      final id = clave['id']?.toString() ?? clave['_id']?.toString();
      if (id == null) continue;

      batch.insert(
        DatabaseTables.clavesCache,
        {
          'id': id,
          'medio_id': clave['medioId']?.toString(),
          'raw_json': jsonEncode(clave),
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Save a single clave
  Future<void> saveClave(Map<String, dynamic> clave) async {
    final db = await _dbService.database;
    final id = clave['id']?.toString() ?? clave['_id']?.toString();
    if (id == null) return;

    await db.insert(
      DatabaseTables.clavesCache,
      {
        'id': id,
        'medio_id': clave['medioId']?.toString(),
        'raw_json': jsonEncode(clave),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get a clave by ID
  Future<Map<String, dynamic>?> getClaveById(String id) async {
    final db = await _dbService.database;
    final result = await db.query(
      DatabaseTables.clavesCache,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return jsonDecode(result.first['raw_json'] as String) as Map<String, dynamic>;
  }

  /// Get all claves for a medio
  Future<List<Map<String, dynamic>>> getClavesByMedio(String medioId) async {
    final db = await _dbService.database;
    final result = await db.query(
      DatabaseTables.clavesCache,
      where: 'medio_id = ?',
      whereArgs: [medioId],
      orderBy: 'id ASC',
    );

    return result.map((row) {
      return jsonDecode(row['raw_json'] as String) as Map<String, dynamic>;
    }).toList();
  }

  /// Get all cached claves
  Future<List<Map<String, dynamic>>> getAllClaves() async {
    final db = await _dbService.database;
    final result = await db.query(
      DatabaseTables.clavesCache,
      orderBy: 'id ASC',
    );

    return result.map((row) {
      return jsonDecode(row['raw_json'] as String) as Map<String, dynamic>;
    }).toList();
  }

  /// Check if clave exists in cache
  Future<bool> hasClaveById(String id) async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseTables.clavesCache} WHERE id = ?',
      [id],
    );
    return ((result.first['count'] as int?) ?? 0) > 0;
  }

  /// Delete a specific clave
  Future<void> deleteClave(String id) async {
    final db = await _dbService.database;
    await db.delete(
      DatabaseTables.clavesCache,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Clear all claves cache
  Future<void> clearAll() async {
    final db = await _dbService.database;
    await db.delete(DatabaseTables.clavesCache);
  }

  /// Get cache stats
  Future<Map<String, int>> getCacheStats() async {
    final db = await _dbService.database;
    final countResult = await db.rawQuery(
      'SELECT COUNT(*) as total FROM ${DatabaseTables.clavesCache}',
    );
    final medioCountResult = await db.rawQuery(
      'SELECT COUNT(DISTINCT medio_id) as medios FROM ${DatabaseTables.clavesCache} '
      'WHERE medio_id IS NOT NULL',
    );

    return {
      'totalClaves': (countResult.first['total'] as int?) ?? 0,
      'totalMedios': (medioCountResult.first['medios'] as int?) ?? 0,
    };
  }
}
