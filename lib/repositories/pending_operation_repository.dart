import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../core/database/database_service.dart';
import '../core/database/database_tables.dart';

/// Model for a pending operation
class PendingOperation {
  final int? id;
  final String uuid;
  final String operationType;
  final String status;
  final Map<String, dynamic> payload;
  final int retryCount;
  final int maxRetries;
  final String? lastError;
  final DateTime createdAt;
  final String userId;

  PendingOperation({
    this.id,
    required this.uuid,
    required this.operationType,
    this.status = DatabaseTables.statusPending,
    required this.payload,
    this.retryCount = 0,
    this.maxRetries = DatabaseTables.defaultMaxRetries,
    this.lastError,
    required this.createdAt,
    required this.userId,
  });

  factory PendingOperation.fromMap(Map<String, dynamic> map) {
    return PendingOperation(
      id: map['id'] as int?,
      uuid: map['uuid'] as String,
      operationType: map['operation_type'] as String,
      status: map['status'] as String? ?? DatabaseTables.statusPending,
      payload: jsonDecode(map['payload'] as String) as Map<String, dynamic>,
      retryCount: map['retry_count'] as int? ?? 0,
      maxRetries: map['max_retries'] as int? ?? DatabaseTables.defaultMaxRetries,
      lastError: map['last_error'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      userId: map['user_id'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uuid': uuid,
      'operation_type': operationType,
      'status': status,
      'payload': jsonEncode(payload),
      'retry_count': retryCount,
      'max_retries': maxRetries,
      'last_error': lastError,
      'created_at': createdAt.millisecondsSinceEpoch,
      'user_id': userId,
    };
  }

  PendingOperation copyWith({
    int? id,
    String? uuid,
    String? operationType,
    String? status,
    Map<String, dynamic>? payload,
    int? retryCount,
    int? maxRetries,
    String? lastError,
    DateTime? createdAt,
    String? userId,
  }) {
    return PendingOperation(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      operationType: operationType ?? this.operationType,
      status: status ?? this.status,
      payload: payload ?? this.payload,
      retryCount: retryCount ?? this.retryCount,
      maxRetries: maxRetries ?? this.maxRetries,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId,
    );
  }

  bool get canRetry => retryCount < maxRetries;
}

/// Repository for managing pending operations queue
class PendingOperationRepository {
  final DatabaseService _dbService;

  PendingOperationRepository(this._dbService);

  /// Add a new pending operation
  Future<int> addOperation(PendingOperation operation) async {
    final db = await _dbService.database;
    return await db.insert(
      DatabaseTables.pendingOperations,
      operation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all pending operations for a user
  Future<List<PendingOperation>> getPendingOperations(String userId) async {
    final db = await _dbService.database;
    final result = await db.query(
      DatabaseTables.pendingOperations,
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, DatabaseTables.statusPending],
      orderBy: 'created_at ASC',
    );
    return result.map((e) => PendingOperation.fromMap(e)).toList();
  }

  /// Get count of pending operations for a user
  Future<int> getPendingCount(String userId) async {
    final db = await _dbService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseTables.pendingOperations} '
      'WHERE user_id = ? AND status = ?',
      [userId, DatabaseTables.statusPending],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Get operation by UUID
  Future<PendingOperation?> getOperationByUuid(String uuid) async {
    final db = await _dbService.database;
    final result = await db.query(
      DatabaseTables.pendingOperations,
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return PendingOperation.fromMap(result.first);
  }

  /// Update operation status
  Future<void> updateStatus(String uuid, String status, {String? error}) async {
    final db = await _dbService.database;
    final updates = <String, dynamic>{'status': status};
    if (error != null) {
      updates['last_error'] = error;
    }
    await db.update(
      DatabaseTables.pendingOperations,
      updates,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  /// Increment retry count
  Future<void> incrementRetry(String uuid, String error) async {
    final db = await _dbService.database;
    await db.rawUpdate(
      'UPDATE ${DatabaseTables.pendingOperations} '
      'SET retry_count = retry_count + 1, last_error = ?, status = ? '
      'WHERE uuid = ?',
      [error, DatabaseTables.statusPending, uuid],
    );
  }

  /// Mark operation as failed (exceeded retries)
  Future<void> markAsFailed(String uuid, String error) async {
    await updateStatus(uuid, DatabaseTables.statusFailed, error: error);
  }

  /// Mark operation as completed and delete it
  Future<void> markAsCompleted(String uuid) async {
    final db = await _dbService.database;
    await db.delete(
      DatabaseTables.pendingOperations,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }

  /// Delete all completed/failed operations for cleanup
  Future<void> cleanupCompleted() async {
    final db = await _dbService.database;
    await db.delete(
      DatabaseTables.pendingOperations,
      where: 'status IN (?, ?)',
      whereArgs: [DatabaseTables.statusCompleted, DatabaseTables.statusFailed],
    );
  }

  /// Get all failed operations for a user
  Future<List<PendingOperation>> getFailedOperations(String userId) async {
    final db = await _dbService.database;
    final result = await db.query(
      DatabaseTables.pendingOperations,
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, DatabaseTables.statusFailed],
      orderBy: 'created_at ASC',
    );
    return result.map((e) => PendingOperation.fromMap(e)).toList();
  }

  /// Reset failed operations to pending (for manual retry)
  Future<void> retryFailedOperations(String userId) async {
    final db = await _dbService.database;
    await db.update(
      DatabaseTables.pendingOperations,
      {
        'status': DatabaseTables.statusPending,
        'retry_count': 0,
      },
      where: 'user_id = ? AND status = ?',
      whereArgs: [userId, DatabaseTables.statusFailed],
    );
  }
}
