import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service for monitoring network connectivity
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final _connectivityController = StreamController<bool>.broadcast();
  bool _isConnected = true;
  bool _isInitialized = false;

  /// Stream of connectivity changes
  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Current connectivity status
  bool get isConnected => _isConnected;

  /// Initialize the service and start listening
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Check initial connectivity
    final results = await _connectivity.checkConnectivity();
    _updateConnectivity(results);

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(_updateConnectivity);
    _isInitialized = true;
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    final wasConnected = _isConnected;

    // Check if we have any real connection
    _isConnected = results.any((result) =>
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet);

    // Only emit if changed
    if (wasConnected != _isConnected) {
      _connectivityController.add(_isConnected);
    }
  }

  /// Check current connectivity (forces a fresh check)
  Future<bool> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _updateConnectivity(results);
    return _isConnected;
  }

  /// Get detailed connectivity info
  Future<List<ConnectivityResult>> getConnectivityDetails() async {
    return await _connectivity.checkConnectivity();
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _connectivityController.close();
    _isInitialized = false;
  }
}
