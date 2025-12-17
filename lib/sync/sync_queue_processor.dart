import 'dart:async';
import 'dart:io';
import '../core/database/database_tables.dart';
import '../repositories/pending_operation_repository.dart';
import '../repositories/photo_repository.dart';
import '../services/api_service.dart';

/// Result of processing an operation
class ProcessingResult {
  final bool success;
  final String? error;

  ProcessingResult({required this.success, this.error});
}

/// Processes pending operations queue
class SyncQueueProcessor {
  final PendingOperationRepository _operationRepo;
  final PhotoRepository _photoRepo;
  final ApiService _apiService;

  bool _isProcessing = false;
  final _processingController = StreamController<SyncProgress>.broadcast();

  SyncQueueProcessor({
    required PendingOperationRepository operationRepo,
    required PhotoRepository photoRepo,
    required ApiService apiService,
  })  : _operationRepo = operationRepo,
        _photoRepo = photoRepo,
        _apiService = apiService;

  /// Stream of processing progress
  Stream<SyncProgress> get progressStream => _processingController.stream;

  /// Whether currently processing
  bool get isProcessing => _isProcessing;

  /// Process all pending operations for a user
  Future<SyncResult> processQueue(String userId) async {
    if (_isProcessing) {
      return SyncResult(
        processed: 0,
        succeeded: 0,
        failed: 0,
        error: 'Already processing',
      );
    }

    _isProcessing = true;
    int processed = 0;
    int succeeded = 0;
    int failed = 0;

    try {
      final operations = await _operationRepo.getPendingOperations(userId);
      final total = operations.length;

      _processingController.add(SyncProgress(
        current: 0,
        total: total,
        status: SyncStatus.starting,
      ));

      for (final operation in operations) {
        processed++;

        _processingController.add(SyncProgress(
          current: processed,
          total: total,
          status: SyncStatus.processing,
          currentOperation: operation.uuid,
        ));

        final result = await _processOperation(operation);

        if (result.success) {
          await _operationRepo.markAsCompleted(operation.uuid);
          succeeded++;
        } else {
          if (operation.canRetry) {
            await _operationRepo.incrementRetry(operation.uuid, result.error ?? 'Unknown error');
          } else {
            await _operationRepo.markAsFailed(operation.uuid, result.error ?? 'Max retries exceeded');
          }
          failed++;
        }
      }

      _processingController.add(SyncProgress(
        current: total,
        total: total,
        status: SyncStatus.completed,
      ));
    } catch (e) {
      _processingController.add(SyncProgress(
        current: processed,
        total: processed,
        status: SyncStatus.error,
        error: e.toString(),
      ));
    } finally {
      _isProcessing = false;
    }

    return SyncResult(
      processed: processed,
      succeeded: succeeded,
      failed: failed,
    );
  }

  Future<ProcessingResult> _processOperation(PendingOperation operation) async {
    try {
      switch (operation.operationType) {
        case DatabaseTables.operationUploadEvidence:
          return await _processUploadEvidence(operation);
        default:
          return ProcessingResult(
            success: false,
            error: 'Unknown operation type: ${operation.operationType}',
          );
      }
    } catch (e) {
      return ProcessingResult(success: false, error: e.toString());
    }
  }

  Future<ProcessingResult> _processUploadEvidence(PendingOperation operation) async {
    final payload = operation.payload;
    final campaniaId = payload['campaniaId'] as String?;
    final tiendaId = payload['tiendaId'] as String?;
    final claveId = payload['claveId'] as String?;

    if (campaniaId == null || tiendaId == null || claveId == null) {
      return ProcessingResult(
        success: false,
        error: 'Missing required fields in payload',
      );
    }

    // Get photos for this operation
    final photos = await _photoRepo.getPhotosByOperation(operation.uuid);

    if (photos.isEmpty) {
      return ProcessingResult(
        success: false,
        error: 'No photos found for operation',
      );
    }

    // Verify all photo files exist
    for (final photo in photos) {
      if (!await photo.fileExists()) {
        return ProcessingResult(
          success: false,
          error: 'Photo file not found: ${photo.filePath}',
        );
      }
    }

    // Build multipart files list
    final files = <File>[];
    for (final photo in photos) {
      files.add(File(photo.filePath));
    }

    // Upload to API
    try {
      await _apiService.uploadMultipleFiles(
        '/campanias/$campaniaId/tiendas/$tiendaId/evidencias',
        files,
        fieldName: 'fotos',
      );

      // Mark photos as uploaded
      for (final photo in photos) {
        await _photoRepo.markAsUploaded(photo.id);
      }

      // Cleanup uploaded photos to free storage
      await _photoRepo.cleanupUploadedPhotos();

      return ProcessingResult(success: true);
    } on ApiException catch (e) {
      return ProcessingResult(success: false, error: e.message);
    }
  }

  void dispose() {
    _processingController.close();
  }
}

/// Progress of sync operation
class SyncProgress {
  final int current;
  final int total;
  final SyncStatus status;
  final String? currentOperation;
  final String? error;

  SyncProgress({
    required this.current,
    required this.total,
    required this.status,
    this.currentOperation,
    this.error,
  });

  double get percentage => total > 0 ? current / total : 0;
}

enum SyncStatus {
  starting,
  processing,
  completed,
  error,
}

/// Result of sync processing
class SyncResult {
  final int processed;
  final int succeeded;
  final int failed;
  final String? error;

  SyncResult({
    required this.processed,
    required this.succeeded,
    required this.failed,
    this.error,
  });

  bool get hasFailures => failed > 0;
  bool get isSuccess => error == null && failed == 0;
}
