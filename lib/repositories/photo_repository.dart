import 'dart:io';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_service.dart';
import '../core/database/database_tables.dart';

/// Local photo model
class LocalPhoto {
  final String id;
  final String filePath;
  final String tiendaId;
  final double? latitud;
  final double? longitud;
  final bool isUploaded;
  final String? pendingOperationId;
  final DateTime createdAt;

  LocalPhoto({
    required this.id,
    required this.filePath,
    required this.tiendaId,
    this.latitud,
    this.longitud,
    this.isUploaded = false,
    this.pendingOperationId,
    required this.createdAt,
  });

  factory LocalPhoto.fromMap(Map<String, dynamic> map) {
    return LocalPhoto(
      id: map['id'] as String,
      filePath: map['file_path'] as String,
      tiendaId: map['tienda_id'] as String,
      latitud: map['latitud'] as double?,
      longitud: map['longitud'] as double?,
      isUploaded: (map['is_uploaded'] as int?) == 1,
      pendingOperationId: map['pending_operation_id'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'file_path': filePath,
      'tienda_id': tiendaId,
      'latitud': latitud,
      'longitud': longitud,
      'is_uploaded': isUploaded ? 1 : 0,
      'pending_operation_id': pendingOperationId,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  LocalPhoto copyWith({
    String? id,
    String? filePath,
    String? tiendaId,
    double? latitud,
    double? longitud,
    bool? isUploaded,
    String? pendingOperationId,
    DateTime? createdAt,
  }) {
    return LocalPhoto(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      tiendaId: tiendaId ?? this.tiendaId,
      latitud: latitud ?? this.latitud,
      longitud: longitud ?? this.longitud,
      isUploaded: isUploaded ?? this.isUploaded,
      pendingOperationId: pendingOperationId ?? this.pendingOperationId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Check if the photo file exists on disk
  Future<bool> fileExists() async {
    return await File(filePath).exists();
  }
}

/// Repository for managing local photos (migrates from SharedPreferences)
class PhotoRepository {
  final DatabaseService _dbService;

  PhotoRepository(this._dbService);

  /// Save a new local photo
  Future<void> savePhoto(LocalPhoto photo) async {
    final db = await _dbService.database;
    await db.insert(
      DatabaseTables.localPhotos,
      photo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get photo by ID
  Future<LocalPhoto?> getPhotoById(String id) async {
    final db = await _dbService.database;
    final result = await db.query(
      DatabaseTables.localPhotos,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return LocalPhoto.fromMap(result.first);
  }

  /// Get all photos for a tienda
  Future<List<LocalPhoto>> getPhotosByTienda(String tiendaId) async {
    final db = await _dbService.database;
    final result = await db.query(
      DatabaseTables.localPhotos,
      where: 'tienda_id = ?',
      whereArgs: [tiendaId],
      orderBy: 'created_at ASC',
    );

    return result.map((row) => LocalPhoto.fromMap(row)).toList();
  }

  /// Get all pending (not uploaded) photos
  Future<List<LocalPhoto>> getPendingPhotos() async {
    final db = await _dbService.database;
    final result = await db.query(
      DatabaseTables.localPhotos,
      where: 'is_uploaded = 0',
      orderBy: 'created_at ASC',
    );

    return result.map((row) => LocalPhoto.fromMap(row)).toList();
  }

  /// Get photos for a pending operation
  Future<List<LocalPhoto>> getPhotosByOperation(String operationId) async {
    final db = await _dbService.database;
    final result = await db.query(
      DatabaseTables.localPhotos,
      where: 'pending_operation_id = ?',
      whereArgs: [operationId],
      orderBy: 'created_at ASC',
    );

    return result.map((row) => LocalPhoto.fromMap(row)).toList();
  }

  /// Mark photo as uploaded
  Future<void> markAsUploaded(String id) async {
    final db = await _dbService.database;
    await db.update(
      DatabaseTables.localPhotos,
      {'is_uploaded': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Link photo to a pending operation
  Future<void> linkToOperation(String photoId, String operationId) async {
    final db = await _dbService.database;
    await db.update(
      DatabaseTables.localPhotos,
      {'pending_operation_id': operationId},
      where: 'id = ?',
      whereArgs: [photoId],
    );
  }

  /// Delete a photo (also deletes file from disk)
  Future<void> deletePhoto(String id) async {
    final photo = await getPhotoById(id);
    if (photo != null) {
      // Delete file from disk
      final file = File(photo.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    final db = await _dbService.database;
    await db.delete(
      DatabaseTables.localPhotos,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete all photos for a tienda
  Future<void> deletePhotosByTienda(String tiendaId) async {
    final photos = await getPhotosByTienda(tiendaId);
    for (final photo in photos) {
      await deletePhoto(photo.id);
    }
  }

  /// Delete uploaded photos (cleanup)
  Future<int> cleanupUploadedPhotos() async {
    final db = await _dbService.database;

    // Get uploaded photos
    final result = await db.query(
      DatabaseTables.localPhotos,
      where: 'is_uploaded = 1',
    );

    // Delete files
    for (final row in result) {
      final filePath = row['file_path'] as String;
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    // Delete from database
    return await db.delete(
      DatabaseTables.localPhotos,
      where: 'is_uploaded = 1',
    );
  }

  /// Get count of pending photos
  Future<int> getPendingCount() async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseTables.localPhotos} WHERE is_uploaded = 0',
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Verify all photos exist on disk, remove orphaned entries
  Future<int> cleanupOrphanedEntries() async {
    final db = await _dbService.database;
    final result = await db.query(DatabaseTables.localPhotos);

    int removed = 0;
    for (final row in result) {
      final id = row['id'] as String;
      final filePath = row['file_path'] as String;
      final file = File(filePath);

      if (!await file.exists()) {
        await db.delete(
          DatabaseTables.localPhotos,
          where: 'id = ?',
          whereArgs: [id],
        );
        removed++;
      }
    }

    return removed;
  }
}
