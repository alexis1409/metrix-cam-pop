import 'dart:async';
import 'package:flutter/foundation.dart';
import '../sync/sync_service.dart';
import '../sync/sync_queue_processor.dart';

/// Provider for sync state in the UI
class SyncProvider extends ChangeNotifier {
  final SyncService _syncService;

  StreamSubscription<SyncServiceStatus>? _statusSubscription;
  SyncServiceStatus? _currentStatus;
  bool _isInitialized = false;

  SyncProvider(this._syncService);

  SyncServiceStatus? get status => _currentStatus;
  bool get isInitialized => _isInitialized;

  /// Convenience getters
  bool get isSyncing => _currentStatus?.status == SyncServiceState.syncing;
  bool get isOffline => _currentStatus?.status == SyncServiceState.offline;
  bool get hasPending => (_currentStatus?.pendingCount ?? 0) > 0;
  bool get hasErrors => _currentStatus?.status == SyncServiceState.hasErrors;
  int get pendingCount => _currentStatus?.pendingCount ?? 0;
  String get statusMessage => _currentStatus?.message ?? '';

  /// Initialize the provider
  Future<void> initialize(String userId) async {
    if (_isInitialized) return;

    await _syncService.initialize(userId);

    // Get initial status
    _currentStatus = await _syncService.getCurrentStatus();

    // Listen for status changes
    _statusSubscription = _syncService.statusStream.listen((status) {
      _currentStatus = status;
      notifyListeners();
    });

    _isInitialized = true;
    notifyListeners();
  }

  /// Update user ID (e.g., after login)
  void setUserId(String? userId) {
    _syncService.setUserId(userId);
  }

  /// Manually trigger sync
  Future<SyncResult> syncNow() async {
    final result = await _syncService.syncNow();
    _currentStatus = await _syncService.getCurrentStatus();
    notifyListeners();
    return result;
  }

  /// Refresh pending count
  Future<void> refreshPendingCount() async {
    _currentStatus = await _syncService.getCurrentStatus();
    notifyListeners();
  }

  /// Check if cache is valid for a campaign
  Future<bool> isCacheValid({
    required String campaniaId,
    required String userId,
  }) async {
    return await _syncService.isTiendasCacheValid(
      campaniaId: campaniaId,
      userId: userId,
    );
  }

  /// Mark cache as valid after fetching from API
  Future<void> markCacheValid({
    required String campaniaId,
    required String userId,
  }) async {
    await _syncService.markTiendasCacheValid(
      campaniaId: campaniaId,
      userId: userId,
    );
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _syncService.dispose();
    super.dispose();
  }
}
