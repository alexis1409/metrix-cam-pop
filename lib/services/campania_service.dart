import '../config/api_config.dart';
import '../core/database/database_tables.dart';
import '../models/campania.dart';
import '../models/tienda_pendiente.dart';
import '../repositories/tiendas_cache_repository.dart';
import '../repositories/sync_metadata_repository.dart';
import '../sync/connectivity_service.dart';
import 'api_service.dart';

/// Result wrapper that indicates if data came from cache
class CampaniaResult<T> {
  final T data;
  final bool fromCache;
  final DateTime? cacheTime;

  CampaniaResult({
    required this.data,
    this.fromCache = false,
    this.cacheTime,
  });
}

class CampaniaService {
  final ApiService _apiService;
  final TiendasCacheRepository? _tiendasCacheRepo;
  final SyncMetadataRepository? _syncMetadataRepo;
  final ConnectivityService? _connectivityService;

  CampaniaService(
    this._apiService, {
    TiendasCacheRepository? tiendasCacheRepo,
    SyncMetadataRepository? syncMetadataRepo,
    ConnectivityService? connectivityService,
  })  : _tiendasCacheRepo = tiendasCacheRepo,
        _syncMetadataRepo = syncMetadataRepo,
        _connectivityService = connectivityService;

  /// Check if offline mode is available
  bool get _hasOfflineSupport =>
      _tiendasCacheRepo != null &&
      _syncMetadataRepo != null &&
      _connectivityService != null;

  /// Get tiendas pendientes with offline-first strategy
  Future<CampaniaResult<List<TiendaPendiente>>> getTiendasPendientesOfflineFirst(
    String userId, {
    String? campaniaId,
    bool forceRefresh = false,
  }) async {
    if (!_hasOfflineSupport) {
      // Fallback to online-only if no offline infrastructure
      final tiendas = await getTiendasPendientes(userId);
      return CampaniaResult(data: tiendas, fromCache: false);
    }

    final effectiveCampaniaId = campaniaId ?? 'all';
    final isOnline = _connectivityService!.isConnected;

    // Check cache validity (skip if forceRefresh)
    final cacheValid = forceRefresh
        ? false
        : await _syncMetadataRepo!.isCacheValid(
            entityType: DatabaseTables.entityTiendasPendientes,
            entityId: effectiveCampaniaId,
            userId: userId,
          );

    // Strategy: Try online first if connected or forceRefresh, fallback to cache
    if (isOnline || forceRefresh) {
      try {
        final tiendas = await getTiendasPendientes(userId);

        // Cache the results
        final tiendasJson = tiendas.map((t) => t.toJson()).toList();
        await _tiendasCacheRepo!.saveTiendasPendientes(
          userId: userId,
          campaniaId: effectiveCampaniaId,
          tiendas: tiendasJson,
        );

        // Update cache validity
        await _syncMetadataRepo!.updateSyncMetadata(
          entityType: DatabaseTables.entityTiendasPendientes,
          entityId: effectiveCampaniaId,
          userId: userId,
        );

        return CampaniaResult(data: tiendas, fromCache: false);
      } catch (e) {
        // If online fetch fails, try cache
        if (cacheValid) {
          return await _getFromCache(userId, effectiveCampaniaId);
        }
        rethrow;
      }
    }

    // Offline: use cache if valid
    if (cacheValid) {
      return await _getFromCache(userId, effectiveCampaniaId);
    }

    // No valid cache and offline
    throw ApiException('Sin conexión y sin datos en cache', statusCode: 0);
  }

  Future<CampaniaResult<List<TiendaPendiente>>> _getFromCache(
    String userId,
    String campaniaId,
  ) async {
    final cachedJson = await _tiendasCacheRepo!.getTiendasPendientes(
      userId: userId,
      campaniaId: campaniaId,
    );

    final cacheTime = await _syncMetadataRepo!.getLastSyncTime(
      entityType: DatabaseTables.entityTiendasPendientes,
      entityId: campaniaId,
      userId: userId,
    );

    final tiendas = cachedJson.map((json) => TiendaPendiente.fromJson(json)).toList();

    return CampaniaResult(
      data: tiendas,
      fromCache: true,
      cacheTime: cacheTime,
    );
  }

  /// Original method for backwards compatibility
  Future<List<TiendaPendiente>> getTiendasPendientes(String userId) async {
    final response = await _apiService.get(
      '${ApiConfig.tiendasPendientes}/$userId/tiendas-pendientes',
    );

    // Handle different response formats
    List<dynamic> data = [];

    if (response.containsKey('data') && response['data'] is List) {
      data = response['data'];
    } else if (response.containsKey('tiendas') && response['tiendas'] is List) {
      data = response['tiendas'];
    }

    return data.map((json) => TiendaPendiente.fromJson(json)).toList();
  }

  Future<List<Campania>> getCampaniasByInstalador(String userId) async {
    final response = await _apiService.get(
      '${ApiConfig.campaniasByInstalador}/$userId',
    );

    final List<dynamic> data = response['data'] ?? response['campanias'] ?? [];

    if (response is List) {
      return (response as List).map((json) => Campania.fromJson(json)).toList();
    }

    if (data.isNotEmpty) {
      return data.map((json) => Campania.fromJson(json)).toList();
    }

    if (response.containsKey('_id')) {
      return [Campania.fromJson(response)];
    }

    return [];
  }

  Future<Campania> getCampaniaById(String id) async {
    final response = await _apiService.get('${ApiConfig.campanias}/$id');
    return Campania.fromJson(response);
  }

  Future<void> actualizarEstadoDetalle(
    String campaniaId,
    int detalleIndex,
    String nuevoEstado,
  ) async {
    await _apiService.patch(
      '${ApiConfig.campanias}/$campaniaId/detalle/$detalleIndex/estado',
      {'estado': nuevoEstado},
    );
  }

  Future<void> agregarEvidencias(
    String campaniaId,
    int detalleIndex,
    String fase,
    List<String> evidencias,
  ) async {
    await _apiService.patch(
      '${ApiConfig.campanias}/$campaniaId/detalle/$detalleIndex/evidencias',
      {
        'fase': fase,
        'evidencias': evidencias,
      },
    );
  }

  /// Invalidate cache for a campaign (call after successful upload)
  Future<void> invalidateCache(String userId, {String? campaniaId}) async {
    if (!_hasOfflineSupport) return;

    final effectiveCampaniaId = campaniaId ?? 'all';
    await _syncMetadataRepo!.invalidateCache(
      entityType: DatabaseTables.entityTiendasPendientes,
      entityId: effectiveCampaniaId,
      userId: userId,
    );
  }
}
