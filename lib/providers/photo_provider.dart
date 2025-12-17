import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import '../models/local_photo.dart';
import '../models/tienda_pendiente.dart';
import '../services/location_service.dart';
import '../services/photo_storage_service.dart';

class PhotoProvider extends ChangeNotifier {
  final PhotoStorageService _storageService;
  final LocationService _locationService;
  final ImagePicker _picker = ImagePicker();

  List<LocalPhoto> _photos = [];
  Map<String, List<LocalPhoto>> _groupedPhotos = {};
  bool _isLoading = false;
  String? _errorMessage;

  PhotoProvider(this._storageService, this._locationService);

  List<LocalPhoto> get photos => _photos;
  Map<String, List<LocalPhoto>> get groupedPhotos => _groupedPhotos;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get _isDesktop => Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  Future<void> loadPhotos() async {
    _isLoading = true;
    notifyListeners();

    try {
      _photos = await _storageService.getAllPhotos();
      _groupedPhotos = await _storageService.getPhotosGroupedByTienda();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Error al cargar fotos: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<NearbyStore> findNearbyStores(
    List<TiendaPendiente> tiendas,
    double userLat,
    double userLon,
    double maxDistanceMeters,
  ) {
    final nearbyStores = <NearbyStore>[];

    for (final tienda in tiendas) {
      if (!tienda.tienda.hasCoordinates) continue;

      final distance = _locationService.calculateDistance(
        userLat,
        userLon,
        tienda.tienda.latitud!,
        tienda.tienda.longitud!,
      );

      if (distance <= maxDistanceMeters) {
        nearbyStores.add(NearbyStore(
          id: tienda.tienda.id,
          nombre: tienda.tienda.nombre,
          determinante: tienda.tienda.determinante,
          distanceMeters: distance,
        ));
      }
    }

    // Sort by distance
    nearbyStores.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return nearbyStores;
  }

  /// Pick image - uses camera on mobile, file selector on desktop
  Future<String?> _pickImage() async {
    if (_isDesktop) {
      // On desktop, use file selector to pick an image
      const XTypeGroup imageTypeGroup = XTypeGroup(
        label: 'images',
        extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
      );

      final XFile? file = await openFile(
        acceptedTypeGroups: [imageTypeGroup],
      );

      return file?.path;
    } else {
      // On mobile, use camera
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      return image?.path;
    }
  }

  Future<TakePhotoResult> takePhoto(
    List<TiendaPendiente> availableTiendas, {
    String? userId,
    String? userName,
  }) async {
    try {
      // Get current location
      final position = await _locationService.getCurrentPosition();

      double latitude = 0.0;
      double longitude = 0.0;
      List<NearbyStore> nearbyStores = [];

      if (position != null) {
        latitude = position.latitude;
        longitude = position.longitude;

        // Find nearby stores within 800m
        nearbyStores = findNearbyStores(
          availableTiendas,
          latitude,
          longitude,
          800,
        );
      }

      // Pick the image (camera on mobile, file selector on desktop)
      final imagePath = await _pickImage();

      if (imagePath == null) {
        return TakePhotoResult.cancelled();
      }

      // On desktop without location, or no nearby stores - save to "Desconocido"
      if (position == null || nearbyStores.isEmpty) {
        await _savePhoto(
          File(imagePath),
          'desconocido',
          'Desconocido',
          latitude,
          longitude,
          userId: userId,
          userName: userName,
        );
        return TakePhotoResult.savedToUnknown();
      } else if (nearbyStores.length == 1) {
        // One store nearby - save directly
        final store = nearbyStores.first;
        await _savePhoto(
          File(imagePath),
          store.id,
          store.nombre,
          latitude,
          longitude,
          userId: userId,
          userName: userName,
        );
        return TakePhotoResult.savedToStore(store);
      } else {
        // Multiple stores nearby - need confirmation
        return TakePhotoResult.needsConfirmation(
          imagePath: imagePath,
          nearbyStores: nearbyStores,
          latitude: latitude,
          longitude: longitude,
          userId: userId,
          userName: userName,
        );
      }
    } catch (e) {
      return TakePhotoResult.error('Error: $e');
    }
  }

  Future<void> confirmAndSavePhoto(
    String imagePath,
    NearbyStore selectedStore,
    double latitude,
    double longitude, {
    String? userId,
    String? userName,
  }) async {
    await _savePhoto(
      File(imagePath),
      selectedStore.id,
      selectedStore.nombre,
      latitude,
      longitude,
      userId: userId,
      userName: userName,
    );
  }

  Future<void> _savePhoto(
    File imageFile,
    String tiendaId,
    String tiendaNombre,
    double latitude,
    double longitude, {
    String? userId,
    String? userName,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _storageService.savePhoto(
        imageFile,
        tiendaId,
        tiendaNombre,
        latitude,
        longitude,
        userId: userId,
        userName: userName,
      );
      await loadPhotos();
    } catch (e) {
      _errorMessage = 'Error al guardar foto: $e';
      notifyListeners();
    }
  }

  Future<void> deletePhoto(String photoId) async {
    try {
      await _storageService.deletePhoto(photoId);
      await loadPhotos();
    } catch (e) {
      _errorMessage = 'Error al eliminar: $e';
      notifyListeners();
    }
  }

  Future<void> movePhoto(String photoId, String newTiendaId, String newTiendaNombre) async {
    try {
      await _storageService.movePhotoToTienda(photoId, newTiendaId, newTiendaNombre);
      await loadPhotos();
    } catch (e) {
      _errorMessage = 'Error al mover foto: $e';
      notifyListeners();
    }
  }

  List<LocalPhoto> getPhotosForTienda(String tiendaId) {
    return _groupedPhotos[tiendaId] ?? [];
  }

  int getPhotoCountForTienda(String tiendaId) {
    return _groupedPhotos[tiendaId]?.length ?? 0;
  }
}

enum TakePhotoResultType {
  success,
  needsConfirmation,
  savedToUnknown,
  cancelled,
  error,
}

class TakePhotoResult {
  final TakePhotoResultType type;
  final String? errorMessage;
  final NearbyStore? savedStore;
  final List<NearbyStore>? nearbyStores;
  final String? imagePath;
  final double? latitude;
  final double? longitude;
  final String? userId;
  final String? userName;

  TakePhotoResult._({
    required this.type,
    this.errorMessage,
    this.savedStore,
    this.nearbyStores,
    this.imagePath,
    this.latitude,
    this.longitude,
    this.userId,
    this.userName,
  });

  factory TakePhotoResult.savedToStore(NearbyStore store) => TakePhotoResult._(
    type: TakePhotoResultType.success,
    savedStore: store,
  );

  factory TakePhotoResult.savedToUnknown() => TakePhotoResult._(
    type: TakePhotoResultType.savedToUnknown,
  );

  factory TakePhotoResult.needsConfirmation({
    required String imagePath,
    required List<NearbyStore> nearbyStores,
    required double latitude,
    required double longitude,
    String? userId,
    String? userName,
  }) => TakePhotoResult._(
    type: TakePhotoResultType.needsConfirmation,
    nearbyStores: nearbyStores,
    imagePath: imagePath,
    latitude: latitude,
    longitude: longitude,
    userId: userId,
    userName: userName,
  );

  factory TakePhotoResult.cancelled() => TakePhotoResult._(
    type: TakePhotoResultType.cancelled,
  );

  factory TakePhotoResult.error(String message) => TakePhotoResult._(
    type: TakePhotoResultType.error,
    errorMessage: message,
  );
}
