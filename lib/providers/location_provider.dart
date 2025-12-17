import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService;

  Position? _currentPosition;
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasPermission = false;
  StreamSubscription<Position>? _positionSubscription;

  LocationProvider(this._locationService);

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasPermission => _hasPermission;
  bool get hasLocation => _currentPosition != null;

  Future<void> initLocation() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    _hasPermission = await _locationService.checkPermissions();

    if (!_hasPermission) {
      _errorMessage = 'No hay permisos de ubicación';
      _isLoading = false;
      notifyListeners();
      return;
    }

    await refreshLocation();
  }

  Future<void> refreshLocation() async {
    _isLoading = true;
    notifyListeners();

    _currentPosition = await _locationService.getCurrentPosition();

    if (_currentPosition == null) {
      _errorMessage = 'No se pudo obtener la ubicación';
    } else {
      _errorMessage = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  void startLocationUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = _locationService.getPositionStream().listen(
      (position) {
        _currentPosition = position;
        notifyListeners();
      },
      onError: (error) {
        _errorMessage = 'Error al obtener ubicación: $error';
        notifyListeners();
      },
    );
  }

  void stopLocationUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  double? getDistanceTo(double? lat, double? lon) {
    if (_currentPosition == null || lat == null || lon == null) {
      return null;
    }
    return _locationService.calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      lat,
      lon,
    );
  }

  String formatDistance(double meters) {
    return _locationService.formatDistance(meters);
  }

  @override
  void dispose() {
    stopLocationUpdates();
    super.dispose();
  }
}
