import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  Position? _currentPosition;

  Position? get currentPosition => _currentPosition;

  Future<bool> checkPermissions() async {
    debugPrint('📍 [LocationService] Checking permissions...');

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    debugPrint('📍 [LocationService] Location service enabled: $serviceEnabled');
    if (!serviceEnabled) {
      debugPrint('❌ [LocationService] Location services are DISABLED');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    debugPrint('📍 [LocationService] Current permission: $permission');

    if (permission == LocationPermission.denied) {
      debugPrint('📍 [LocationService] Permission denied, requesting...');
      permission = await Geolocator.requestPermission();
      debugPrint('📍 [LocationService] Permission after request: $permission');
      if (permission == LocationPermission.denied) {
        debugPrint('❌ [LocationService] Permission DENIED by user');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('❌ [LocationService] Permission DENIED FOREVER');
      return false;
    }

    debugPrint('✅ [LocationService] Permissions OK');
    return true;
  }

  Future<Position?> getCurrentPosition() async {
    debugPrint('📍 [LocationService] Getting current position...');

    final hasPermission = await checkPermissions();
    if (!hasPermission) {
      debugPrint('❌ [LocationService] No permission, returning null');
      return null;
    }

    try {
      debugPrint('📍 [LocationService] Requesting GPS position (timeout: 15s)...');
      _currentPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      debugPrint('✅ [LocationService] Position obtained: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
      debugPrint('📍 [LocationService] Accuracy: ${_currentPosition!.accuracy}m');
      return _currentPosition;
    } catch (e) {
      debugPrint('❌ [LocationService] Error getting position: $e');
      return null;
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }
}
