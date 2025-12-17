import 'dart:async';
import 'connectivity_service.dart';
import 'sync_queue_processor.dart';
import '../core/database/database_tables.dart';
import '../repositories/pending_operation_repository.dart';
import '../repositories/sync_metadata_repository.dart';
import '../repositories/tiendas_cache_repository.dart';

/// Main orchestrator for offline sync functionality
class SyncService {
  final ConnectivityService _connectivityService;
  final SyncQueueProcessor _queueProcessor;
  final PendingOperationRepository _operationRepo;
  final SyncMetadataRepository _metadataRepo;
  final TiendasCacheRepository _tiendasRepo;

  StreamSubscription<bool>? _connectivitySubscription;
  String? _currentUserId;
  bool _autoSyncEnabled = true;

  final _syncStatusController = StreamController<SyncServiceStatus>.broadcast();

  SyncService({
    required ConnectivityService connectivityService,
    required SyncQueueProcessor queueProcessor,
    required PendingOperationRepository operationRepo,
    required SyncMetadataRepository metadataRepo,
    required TiendasCacheRepository tiendasRepo,
  })  : _connectivityService = connectivityService,
        _queueProcessor = queueProcessor,
        _operationRepo = operationRepo,
        _metadataRepo = metadataRepo,
        _tiendasRepo = tiendasRepo;

  /// Stream of sync service status changes
  Stream<SyncServiceStatus> get statusStream => _syncStatusController.stream;

  /// Initialize the sync service
  Future<void> initialize(String userId) async {
    _currentUserId = userId;

    // Initialize connectivity monitoring
    await _connectivityService.initialize();

    // Listen for connectivity changes
    _connectivitySubscription = _connectivityService.connectivityStream.listen((isConnected) {
      if (isConnected && _autoSyncEnabled && _currentUserId != null) {
        _onConnectivityRestored();
      }
    });
  }

  /// Called when connectivity is restored
  void _onConnectivityRestored() async {
    if (_currentUserId == null) return;

    _syncStatusController.add(SyncServiceStatus(
      status: SyncServiceState.syncing,
      message: 'Conexión restaurada, sincronizando...',
    ));

    // Process pending operations
    final result = await _queueProcessor.processQueue(_currentUserId!);

    if (result.isSuccess) {
      _syncStatusController.add(SyncServiceStatus(
        status: SyncServiceState.idle,
        message: 'Sincronización completada',
        pendingCount: 0,
      ));
    } else {
      final pendingCount = await _operationRepo.getPendingCount(_currentUserId!);
      _syncStatusController.add(SyncServiceStatus(
        status: SyncServiceState.hasErrors,
        message: '${result.failed} operaciones fallaron',
        pendingCount: pendingCount,
      ));
    }
  }

  /// Manually trigger sync
  Future<SyncResult> syncNow() async {
    if (_currentUserId == null) {
      return SyncResult(
        processed: 0,
        succeeded: 0,
        failed: 0,
        error: 'No user logged in',
      );
    }

    if (!_connectivityService.isConnected) {
      return SyncResult(
        processed: 0,
        succeeded: 0,
        failed: 0,
        error: 'Sin conexión a internet',
      );
    }

    _syncStatusController.add(SyncServiceStatus(
      status: SyncServiceState.syncing,
      message: 'Sincronizando...',
    ));

    final result = await _queueProcessor.processQueue(_currentUserId!);
    final pendingCount = await _operationRepo.getPendingCount(_currentUserId!);

    _syncStatusController.add(SyncServiceStatus(
      status: result.hasFailures ? SyncServiceState.hasErrors : SyncServiceState.idle,
      message: result.hasFailures ? '${result.failed} operaciones fallaron' : 'Sincronizado',
      pendingCount: pendingCount,
    ));

    return result;
  }

  /// Check if tiendas cache is valid
  Future<bool> isTiendasCacheValid({
    required String campaniaId,
    required String userId,
  }) async {
    return await _metadataRepo.isCacheValid(
      entityType: DatabaseTables.entityTiendasPendientes,
      entityId: campaniaId,
      userId: userId,
    );
  }

  /// Update tiendas cache validity
  Future<void> markTiendasCacheValid({
    required String campaniaId,
    required String userId,
  }) async {
    await _metadataRepo.updateSyncMetadata(
      entityType: DatabaseTables.entityTiendasPendientes,
      entityId: campaniaId,
      userId: userId,
    );
  }

  /// Invalidate tiendas cache
  Future<void> invalidateTiendasCache({
    required String campaniaId,
    required String userId,
  }) async {
    await _metadataRepo.invalidateCache(
      entityType: DatabaseTables.entityTiendasPendientes,
      entityId: campaniaId,
      userId: userId,
    );
    await _tiendasRepo.deleteCacheForCampaign(
      userId: userId,
      campaniaId: campaniaId,
    );
  }

  /// Get pending operations count
  Future<int> getPendingCount() async {
    if (_currentUserId == null) return 0;
    return await _operationRepo.getPendingCount(_currentUserId!);
  }

  /// Get current sync status
  Future<SyncServiceStatus> getCurrentStatus() async {
    final isConnected = _connectivityService.isConnected;
    final pendingCount = _currentUserId != null
        ? await _operationRepo.getPendingCount(_currentUserId!)
        : 0;

    if (!isConnected) {
      return SyncServiceStatus(
        status: SyncServiceState.offline,
        message: 'Sin conexión',
        pendingCount: pendingCount,
      );
    }

    if (pendingCount > 0) {
      return SyncServiceStatus(
        status: SyncServiceState.hasPending,
        message: '$pendingCount pendientes',
        pendingCount: pendingCount,
      );
    }

    return SyncServiceStatus(
      status: SyncServiceState.idle,
      message: 'Sincronizado',
      pendingCount: 0,
    );
  }

  /// Enable/disable auto sync
  void setAutoSync(bool enabled) {
    _autoSyncEnabled = enabled;
  }

  /// Update current user
  void setUserId(String? userId) {
    _currentUserId = userId;
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _syncStatusController.close();
    _queueProcessor.dispose();
    _connectivityService.dispose();
  }
}

/// Status of the sync service
class SyncServiceStatus {
  final SyncServiceState status;
  final String message;
  final int pendingCount;

  SyncServiceStatus({
    required this.status,
    required this.message,
    this.pendingCount = 0,
  });
}

enum SyncServiceState {
  idle,
  syncing,
  offline,
  hasPending,
  hasErrors,
}
