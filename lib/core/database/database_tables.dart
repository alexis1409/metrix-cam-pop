/// Constants for database table names and column definitions
class DatabaseTables {
  DatabaseTables._();

  // Table names
  static const String syncMetadata = 'sync_metadata';
  static const String pendingOperations = 'pending_operations';
  static const String tiendasPendientesCache = 'tiendas_pendientes_cache';
  static const String clavesCache = 'claves_cache';
  static const String localPhotos = 'local_photos';
  static const String appSettings = 'app_settings';

  // Entity types for sync_metadata
  static const String entityTiendasPendientes = 'tiendas_pendientes';
  static const String entityClaves = 'claves';
  static const String entitySettings = 'settings';

  // Operation types for pending_operations
  static const String operationUploadEvidence = 'upload_evidence';

  // Operation statuses
  static const String statusPending = 'pending';
  static const String statusProcessing = 'processing';
  static const String statusCompleted = 'completed';
  static const String statusFailed = 'failed';

  // Cache duration in milliseconds (24 hours)
  static const int cacheDurationMs = 24 * 60 * 60 * 1000;

  // Max retries for pending operations
  static const int defaultMaxRetries = 3;
}
