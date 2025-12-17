import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/database/database_service.dart';
import 'providers/auth_provider.dart';
import 'providers/campania_provider.dart';
import 'providers/location_provider.dart';
import 'providers/photo_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/retailtainment_provider.dart';
import 'repositories/pending_operation_repository.dart';
import 'repositories/sync_metadata_repository.dart';
import 'repositories/tiendas_cache_repository.dart';
import 'repositories/photo_repository.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/campania_service.dart';
import 'services/location_service.dart';
import 'services/photo_storage_service.dart';
import 'sync/connectivity_service.dart';
import 'sync/sync_service.dart';
import 'sync/sync_queue_processor.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';
import 'screens/notifications/notification_center_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/campanias/tienda_campanias_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/retailtainment/retailtainment_list_screen.dart';
import 'screens/retailtainment/retailtainment_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize database
  final databaseService = DatabaseService();
  await databaseService.database; // Ensure DB is initialized

  runApp(MyApp(databaseService: databaseService));
}

class MyApp extends StatelessWidget {
  final DatabaseService databaseService;

  const MyApp({super.key, required this.databaseService});

  @override
  Widget build(BuildContext context) {
    // Create core services
    final apiService = ApiService();
    final authService = AuthService(apiService);
    final locationService = LocationService();
    final photoStorageService = PhotoStorageService();

    // Create repositories
    final syncMetadataRepo = SyncMetadataRepository(databaseService);
    final pendingOpRepo = PendingOperationRepository(databaseService);
    final tiendasCacheRepo = TiendasCacheRepository(databaseService);
    final photoRepo = PhotoRepository(databaseService);

    // Create sync infrastructure
    final connectivityService = ConnectivityService();
    final queueProcessor = SyncQueueProcessor(
      operationRepo: pendingOpRepo,
      photoRepo: photoRepo,
      apiService: apiService,
    );
    final syncService = SyncService(
      connectivityService: connectivityService,
      queueProcessor: queueProcessor,
      operationRepo: pendingOpRepo,
      metadataRepo: syncMetadataRepo,
      tiendasRepo: tiendasCacheRepo,
    );

    // Create offline-aware campania service
    final campaniaService = CampaniaService(
      apiService,
      tiendasCacheRepo: tiendasCacheRepo,
      syncMetadataRepo: syncMetadataRepo,
      connectivityService: connectivityService,
    );

    // Create notification service
    final notificationService = NotificationService(apiService);

    return MultiProvider(
      providers: [
        // Core services
        Provider<ApiService>.value(value: apiService),
        Provider<DatabaseService>.value(value: databaseService),

        // Repositories
        Provider<PendingOperationRepository>.value(value: pendingOpRepo),
        Provider<TiendasCacheRepository>.value(value: tiendasCacheRepo),
        Provider<PhotoRepository>.value(value: photoRepo),
        Provider<SyncMetadataRepository>.value(value: syncMetadataRepo),

        // Sync services
        Provider<ConnectivityService>.value(value: connectivityService),
        Provider<SyncService>.value(value: syncService),

        // Providers
        ChangeNotifierProvider(
          create: (_) => AuthProvider(authService),
        ),
        ChangeNotifierProvider(
          create: (_) => CampaniaProvider(campaniaService),
        ),
        ChangeNotifierProvider(
          create: (_) => LocationProvider(locationService),
        ),
        ChangeNotifierProvider(
          create: (_) => PhotoProvider(photoStorageService, locationService),
        ),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(apiService)..loadSettings(),
        ),
        ChangeNotifierProvider(
          create: (_) => ConnectivityProvider(connectivityService)..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => SyncProvider(syncService),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(notificationService)..initialize(),
        ),
        ChangeNotifierProvider(
          create: (_) => RetailtainmentProvider(apiService),
        ),
      ],
      child: MaterialApp(
        title: 'Metrix CAM',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const MainScreen(),
          '/tienda-campanias': (context) => const TiendaCampaniasScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/notifications': (context) => const NotificationCenterScreen(),
          '/retailtainment': (context) => const RetailtainmentListScreen(),
          '/retailtainment-home': (context) => const RetailtainmentHomeScreen(),
        },
      ),
    );
  }
}
