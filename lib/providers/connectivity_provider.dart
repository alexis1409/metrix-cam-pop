import 'dart:async';
import 'package:flutter/foundation.dart';
import '../sync/connectivity_service.dart';

/// Provider for connectivity state in the UI
class ConnectivityProvider extends ChangeNotifier {
  final ConnectivityService _connectivityService;
  StreamSubscription<bool>? _subscription;

  bool _isConnected = true;
  bool _isInitialized = false;

  ConnectivityProvider(this._connectivityService);

  bool get isConnected => _isConnected;
  bool get isOffline => !_isConnected;
  bool get isInitialized => _isInitialized;

  /// Initialize and start listening to connectivity changes
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _connectivityService.initialize();
    _isConnected = _connectivityService.isConnected;

    _subscription = _connectivityService.connectivityStream.listen((isConnected) {
      if (_isConnected != isConnected) {
        _isConnected = isConnected;
        notifyListeners();
      }
    });

    _isInitialized = true;
    notifyListeners();
  }

  /// Force a connectivity check
  Future<bool> checkConnectivity() async {
    _isConnected = await _connectivityService.checkConnectivity();
    notifyListeners();
    return _isConnected;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
