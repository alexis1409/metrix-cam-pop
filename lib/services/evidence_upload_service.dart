import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../core/database/database_tables.dart';
import '../repositories/pending_operation_repository.dart';
import '../repositories/photo_repository.dart';
import '../sync/connectivity_service.dart';
import 'api_service.dart';

class UploadResult {
  final bool success;
  final List<String> urls;
  final String? errorMessage;
  final bool savedOffline;

  UploadResult({
    required this.success,
    this.urls = const [],
    this.errorMessage,
    this.savedOffline = false,
  });

  factory UploadResult.fromJson(Map<String, dynamic> json) {
    return UploadResult(
      success: json['success'] ?? false,
      urls: List<String>.from(json['urls'] ?? []),
    );
  }

  factory UploadResult.error(String message) {
    return UploadResult(
      success: false,
      errorMessage: message,
    );
  }

  factory UploadResult.offline() {
    return UploadResult(
      success: true,
      savedOffline: true,
    );
  }
}

class EvidenceUploadService {
  final ApiService _apiService;
  final PendingOperationRepository? _operationRepo;
  final PhotoRepository? _photoRepo;
  final ConnectivityService? _connectivityService;

  EvidenceUploadService(
    this._apiService, {
    PendingOperationRepository? operationRepo,
    PhotoRepository? photoRepo,
    ConnectivityService? connectivityService,
  })  : _operationRepo = operationRepo,
        _photoRepo = photoRepo,
        _connectivityService = connectivityService;

  /// Check if offline support is available
  bool get _hasOfflineSupport =>
      _operationRepo != null &&
      _photoRepo != null &&
      _connectivityService != null;

  Future<UploadResult> uploadPhotos(List<File> photos) async {
    debugPrint('📤 [EvidenceUploadService] uploadPhotos called with ${photos.length} photos');

    if (photos.isEmpty) {
      debugPrint('❌ [EvidenceUploadService] No photos to upload');
      return UploadResult.error('No hay fotos para subir');
    }

    if (photos.length > 10) {
      debugPrint('❌ [EvidenceUploadService] Too many photos: ${photos.length}');
      return UploadResult.error('Máximo 10 fotos por subida');
    }

    try {
      for (int i = 0; i < photos.length; i++) {
        debugPrint('📤 [EvidenceUploadService] Photo $i: ${photos[i].path} - exists: ${photos[i].existsSync()}');
      }

      debugPrint('📤 [EvidenceUploadService] Calling API uploadMultipleFiles...');
      final response = await _apiService.uploadMultipleFiles(
        '/uploads/multiple',
        photos,
        fieldName: 'files',
      );

      debugPrint('📤 [EvidenceUploadService] Upload response: $response');
      return UploadResult.fromJson(response);
    } catch (e) {
      debugPrint('❌ [EvidenceUploadService] Upload error: $e');
      return UploadResult.error(e.toString());
    }
  }

  Future<bool> updateDetalleEstado({
    required String campaniaId,
    required int detalleIndex,
    required String nuevoEstado,
    List<String>? evidencias,
    String? claveId,
    String? notas,
  }) async {
    try {
      final body = <String, dynamic>{
        'nuevoEstado': nuevoEstado,
      };

      if (evidencias != null && evidencias.isNotEmpty) {
        body['evidencias'] = evidencias;
      }

      if (claveId != null && claveId.isNotEmpty) {
        body['claveId'] = claveId;
      }

      if (notas != null && notas.isNotEmpty) {
        body['notas'] = notas;
      }

      await _apiService.patch(
        '/campanias/$campaniaId/detalle/$detalleIndex/estado',
        body,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Upload evidencias with offline support
  Future<UploadResult> uploadEvidenciasOfflineFirst({
    required List<File> photos,
    required String campaniaId,
    required int detalleIndex,
    required String tiendaId,
    required String fase,
    required String userId,
    String? claveId,
    String? notas,
    double? latitud,
    double? longitud,
  }) async {
    if (!_hasOfflineSupport) {
      // Fallback to online-only mode
      final success = await uploadEvidenciasAndUpdateEstado(
        photos: photos,
        campaniaId: campaniaId,
        detalleIndex: detalleIndex,
        fase: fase,
        claveId: claveId,
        notas: notas,
      );
      return success ? UploadResult(success: true) : UploadResult.error('Error al subir');
    }

    final isOnline = _connectivityService!.isConnected;

    if (isOnline) {
      // Try online upload
      try {
        final result = await uploadEvidenciasAndUpdateEstado(
          photos: photos,
          campaniaId: campaniaId,
          detalleIndex: detalleIndex,
          fase: fase,
          claveId: claveId,
          notas: notas,
        );

        if (result) {
          return UploadResult(success: true);
        }
      } catch (e) {
        // Fall through to offline queue
      }
    }

    // Save to offline queue
    return await _saveToOfflineQueue(
      photos: photos,
      campaniaId: campaniaId,
      detalleIndex: detalleIndex,
      tiendaId: tiendaId,
      fase: fase,
      userId: userId,
      claveId: claveId,
      notas: notas,
      latitud: latitud,
      longitud: longitud,
    );
  }

  Future<UploadResult> _saveToOfflineQueue({
    required List<File> photos,
    required String campaniaId,
    required int detalleIndex,
    required String tiendaId,
    required String fase,
    required String userId,
    String? claveId,
    String? notas,
    double? latitud,
    double? longitud,
  }) async {
    try {
      final operationUuid = _generateUuid();
      final photoIds = <String>[];

      // Save photos to local storage
      for (final photo in photos) {
        final photoId = _generateUuid();
        final localPath = await _copyPhotoToLocalStorage(photo, photoId);

        final localPhoto = LocalPhoto(
          id: photoId,
          filePath: localPath,
          tiendaId: tiendaId,
          latitud: latitud,
          longitud: longitud,
          pendingOperationId: operationUuid,
          createdAt: DateTime.now(),
        );

        await _photoRepo!.savePhoto(localPhoto);
        photoIds.add(photoId);
      }

      // Create pending operation
      final operation = PendingOperation(
        uuid: operationUuid,
        operationType: DatabaseTables.operationUploadEvidence,
        payload: {
          'campaniaId': campaniaId,
          'detalleIndex': detalleIndex,
          'tiendaId': tiendaId,
          'fase': fase,
          'claveId': claveId,
          'notas': notas,
          'latitud': latitud,
          'longitud': longitud,
          'photoIds': photoIds,
        },
        createdAt: DateTime.now(),
        userId: userId,
      );

      await _operationRepo!.addOperation(operation);

      return UploadResult.offline();
    } catch (e) {
      return UploadResult.error('Error guardando offline: $e');
    }
  }

  Future<String> _copyPhotoToLocalStorage(File photo, String photoId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${appDir.path}/pending_photos');

    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final extension = photo.path.split('.').last;
    final newPath = '${photosDir.path}/$photoId.$extension';
    await photo.copy(newPath);

    return newPath;
  }

  String _generateUuid() {
    final now = DateTime.now();
    return '${now.millisecondsSinceEpoch}_${now.microsecond}';
  }

  Future<bool> uploadEvidenciasAndUpdateEstado({
    required List<File> photos,
    required String campaniaId,
    required int detalleIndex,
    required String fase,
    String? claveId,
    String? notas,
  }) async {
    debugPrint('📤 [EvidenceUploadService] uploadEvidenciasAndUpdateEstado started');
    debugPrint('📤 [EvidenceUploadService] fase: $fase, claveId: $claveId');

    // Step 1: Upload photos
    final uploadResult = await uploadPhotos(photos);

    debugPrint('📤 [EvidenceUploadService] Upload result - success: ${uploadResult.success}, urls: ${uploadResult.urls}');

    if (!uploadResult.success) {
      debugPrint('❌ [EvidenceUploadService] Upload failed: ${uploadResult.errorMessage}');
      return false;
    }

    // Step 2: Update estado with evidencias
    debugPrint('📤 [EvidenceUploadService] Updating detalle estado...');
    final updateSuccess = await updateDetalleEstado(
      campaniaId: campaniaId,
      detalleIndex: detalleIndex,
      nuevoEstado: fase,
      evidencias: uploadResult.urls,
      claveId: claveId,
      notas: notas,
    );

    debugPrint('📤 [EvidenceUploadService] Update result: $updateSuccess');
    return updateSuccess;
  }

  /// Get count of pending uploads
  Future<int> getPendingUploadsCount(String userId) async {
    if (!_hasOfflineSupport) return 0;
    return await _operationRepo!.getPendingCount(userId);
  }
}
