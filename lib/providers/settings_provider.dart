import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../services/api_service.dart';

class SettingsProvider extends ChangeNotifier {
  final ApiService _apiService;

  AppSettings _settings = AppSettings.defaults();
  bool _isLoading = false;
  String? _errorMessage;

  // Local app settings
  String _photoQuality = 'Alta';
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _offlineModePreferred = false;

  SettingsProvider(this._apiService);

  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Local settings getters
  String get photoQuality => _photoQuality;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get darkModeEnabled => _darkModeEnabled;
  bool get offlineModePreferred => _offlineModePreferred;

  Future<void> loadSettings() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Load local settings from SharedPreferences
    await _loadLocalSettings();

    try {
      final response = await _apiService.get('/settings');
      _settings = AppSettings.fromJson(response);
    } on ApiException catch (e) {
      _errorMessage = e.message;
      // Keep defaults if API fails
    } catch (e) {
      _errorMessage = 'Error al cargar configuración: $e';
      // Keep defaults if API fails
    }

    _isLoading = false;
    notifyListeners();
  }

  // Local settings persistence
  Future<void> _loadLocalSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _photoQuality = prefs.getString('photoQuality') ?? 'Alta';
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _darkModeEnabled = prefs.getBool('darkModeEnabled') ?? false;
      _offlineModePreferred = prefs.getBool('offlineModePreferred') ?? false;
    } catch (e) {
      // Keep defaults if loading fails
    }
  }

  Future<void> _saveLocalSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      }
    } catch (e) {
      // Ignore save errors
    }
  }

  // Local settings setters
  Future<void> setPhotoQuality(String quality) async {
    _photoQuality = quality;
    await _saveLocalSetting('photoQuality', quality);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    _notificationsEnabled = enabled;
    await _saveLocalSetting('notificationsEnabled', enabled);
    notifyListeners();
  }

  Future<void> setDarkModeEnabled(bool enabled) async {
    _darkModeEnabled = enabled;
    await _saveLocalSetting('darkModeEnabled', enabled);
    notifyListeners();
  }

  Future<void> setOfflineModePreferred(bool preferred) async {
    _offlineModePreferred = preferred;
    await _saveLocalSetting('offlineModePreferred', preferred);
    notifyListeners();
  }

  StatusColor getDetalleColor(String estado) {
    return _settings.getDetalleColor(estado);
  }

  StatusColor getCampaniaColor(String estado) {
    return _settings.getCampaniaColor(estado);
  }

  // Anti-fraude settings
  AntiFraudeConfig get antiFraude => _settings.antiFraude;
  WatermarkConfig get watermarkConfig => _settings.antiFraude.watermark;
  int get distanciaMaximaMetros => _settings.antiFraude.distanciaMaximaMetros;
  bool get permitirGaleriaDispositivo => _settings.antiFraude.permitirGaleriaDispositivo;
  bool get validarUbicacionAlSubir => _settings.antiFraude.validarUbicacionAlSubir;
}
