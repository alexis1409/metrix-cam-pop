import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/local_photo.dart';

class PhotoStorageService {
  static const String _photosKey = 'local_photos';

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<Directory> _getOrCreateFolder(String folderName) async {
    final path = await _localPath;
    final folder = Directory('$path/photos/$folderName');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder;
  }

  Future<String> savePhoto(
    File imageFile,
    String tiendaId,
    String tiendaNombre,
    double? latitud,
    double? longitud, {
    String? userId,
    String? userName,
  }) async {
    final folderName = tiendaId == 'desconocido' ? 'Desconocido' : tiendaId;
    final folder = await _getOrCreateFolder(folderName);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = imageFile.path.split('.').last;
    final fileName = 'photo_$timestamp.$extension';
    final newPath = '${folder.path}/$fileName';

    await imageFile.copy(newPath);

    final photo = LocalPhoto(
      id: 'photo_$timestamp',
      filePath: newPath,
      fileName: fileName,
      tiendaId: tiendaId,
      tiendaNombre: tiendaNombre,
      latitud: latitud,
      longitud: longitud,
      userId: userId,
      userName: userName,
      createdAt: DateTime.now(),
    );

    await _addPhotoToStorage(photo);

    return photo.id;
  }

  Future<void> _addPhotoToStorage(LocalPhoto photo) async {
    final prefs = await SharedPreferences.getInstance();
    final photosJson = prefs.getStringList(_photosKey) ?? [];
    photosJson.add(jsonEncode(photo.toJson()));
    await prefs.setStringList(_photosKey, photosJson);
  }

  Future<List<LocalPhoto>> getAllPhotos() async {
    final prefs = await SharedPreferences.getInstance();
    final photosJson = prefs.getStringList(_photosKey) ?? [];
    return photosJson
        .map((json) => LocalPhoto.fromJson(jsonDecode(json)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<LocalPhoto>> getPhotosByTienda(String tiendaId) async {
    final photos = await getAllPhotos();
    return photos.where((p) => p.tiendaId == tiendaId).toList();
  }

  Future<List<LocalPhoto>> getUnknownPhotos() async {
    return getPhotosByTienda('desconocido');
  }

  Future<Map<String, List<LocalPhoto>>> getPhotosGroupedByTienda() async {
    final photos = await getAllPhotos();
    final grouped = <String, List<LocalPhoto>>{};

    for (final photo in photos) {
      final key = photo.tiendaId;
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(photo);
    }

    return grouped;
  }

  Future<void> deletePhoto(String photoId) async {
    final prefs = await SharedPreferences.getInstance();
    final photosJson = prefs.getStringList(_photosKey) ?? [];

    final photos = photosJson
        .map((json) => LocalPhoto.fromJson(jsonDecode(json)))
        .toList();

    final photoToDelete = photos.firstWhere(
      (p) => p.id == photoId,
      orElse: () => throw Exception('Photo not found'),
    );

    // Delete the file
    final file = File(photoToDelete.filePath);
    if (await file.exists()) {
      await file.delete();
    }

    // Remove from storage
    photos.removeWhere((p) => p.id == photoId);
    await prefs.setStringList(
      _photosKey,
      photos.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  Future<void> movePhotoToTienda(
    String photoId,
    String newTiendaId,
    String newTiendaNombre,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final photosJson = prefs.getStringList(_photosKey) ?? [];

    final photos = photosJson
        .map((json) => LocalPhoto.fromJson(jsonDecode(json)))
        .toList();

    final index = photos.indexWhere((p) => p.id == photoId);
    if (index == -1) return;

    final oldPhoto = photos[index];

    // Create new folder and move file
    final folderName = newTiendaId == 'desconocido' ? 'Desconocido' : newTiendaId;
    final folder = await _getOrCreateFolder(folderName);
    final newPath = '${folder.path}/${oldPhoto.fileName}';

    final file = File(oldPhoto.filePath);
    if (await file.exists()) {
      await file.copy(newPath);
      await file.delete();
    }

    // Update record
    final newPhoto = LocalPhoto(
      id: oldPhoto.id,
      filePath: newPath,
      fileName: oldPhoto.fileName,
      tiendaId: newTiendaId,
      tiendaNombre: newTiendaNombre,
      latitud: oldPhoto.latitud,
      longitud: oldPhoto.longitud,
      userId: oldPhoto.userId,
      userName: oldPhoto.userName,
      createdAt: oldPhoto.createdAt,
    );

    photos[index] = newPhoto;
    await prefs.setStringList(
      _photosKey,
      photos.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  Future<List<String>> getTiendasWithPhotos() async {
    final grouped = await getPhotosGroupedByTienda();
    return grouped.keys.toList();
  }

  Future<int> getPhotoCountForTienda(String tiendaId) async {
    final photos = await getPhotosByTienda(tiendaId);
    return photos.length;
  }

  /// Get total storage used by photos in MB
  Future<double> getStorageUsed() async {
    try {
      final photos = await getAllPhotos();
      int totalBytes = 0;

      for (final photo in photos) {
        final file = File(photo.filePath);
        if (await file.exists()) {
          totalBytes += await file.length();
        }
      }

      // Convert to MB
      return totalBytes / (1024 * 1024);
    } catch (e) {
      return 0.0;
    }
  }

  /// Get count of photos pending upload
  Future<int> getPendingPhotosCount() async {
    final photos = await getAllPhotos();
    // All local photos are considered pending until synced
    return photos.length;
  }

  /// Clear all cached photos (use with caution)
  Future<void> clearCache() async {
    try {
      final photos = await getAllPhotos();

      // Delete all photo files
      for (final photo in photos) {
        final file = File(photo.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_photosKey);

      // Try to delete photos folder
      final path = await _localPath;
      final photosFolder = Directory('$path/photos');
      if (await photosFolder.exists()) {
        await photosFolder.delete(recursive: true);
      }
    } catch (e) {
      // Ignore errors during cleanup
    }
  }
}
