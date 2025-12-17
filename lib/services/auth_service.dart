import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/auth_response.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _apiService;
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  AuthService(this._apiService);

  /// Login with optional 2FA code
  /// Returns LoginResult which indicates if 2FA is required
  Future<LoginResult> login(
    String email,
    String password, {
    String? twoFactorCode,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      'password': password,
    };

    // Include 2FA code if provided
    if (twoFactorCode != null && twoFactorCode.isNotEmpty) {
      body['twoFactorCode'] = twoFactorCode;
    }

    final response = await _apiService.post(ApiConfig.login, body);
    final result = LoginResult.fromJson(response);

    // If login successful (not requiring 2FA), save auth data
    if (result.success && result.authResponse != null) {
      await _saveAuthData(result.authResponse!);
      _apiService.setToken(result.authResponse!.accessToken);
    }

    return result;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    _apiService.setToken(null);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<User?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);

    if (userData == null) return null;

    try {
      final Map<String, dynamic> userMap = {};
      // Parse stored user data
      final parts = userData.split('|');
      if (parts.length >= 5) {
        userMap['id'] = parts[0];
        userMap['name'] = parts[1];
        userMap['email'] = parts[2];
        userMap['role'] = parts[3];
        userMap['isActive'] = parts[4] == 'true';
      }
      return User.fromJson(userMap);
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveAuthData(AuthResponse authResponse) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, authResponse.accessToken);

    // Save user data as simple string
    final user = authResponse.user;
    final userData =
        '${user.id}|${user.name}|${user.email}|${user.role}|${user.isActive}';
    await prefs.setString(_userKey, userData);
  }

  Future<void> restoreSession() async {
    final token = await getToken();
    if (token != null) {
      _apiService.setToken(token);
    }
  }

  // ==================== 2FA Management ====================

  /// Generate 2FA secret and QR code
  Future<TwoFactorSetupData> generate2FA() async {
    final response = await _apiService.post(ApiConfig.twoFactorGenerate, {});
    return TwoFactorSetupData.fromJson(response);
  }

  /// Enable 2FA with verification token
  Future<void> enable2FA(String token) async {
    await _apiService.post(ApiConfig.twoFactorEnable, {'token': token});
  }

  /// Disable 2FA with verification token
  Future<void> disable2FA(String token) async {
    await _apiService.post(ApiConfig.twoFactorDisable, {'token': token});
  }

  /// Get 2FA status
  Future<bool> get2FAStatus() async {
    final response = await _apiService.get(ApiConfig.twoFactorStatus);
    return response['isEnabled'] == true || response['twoFactorEnabled'] == true;
  }
}

/// Data returned when generating 2FA setup
class TwoFactorSetupData {
  final String secret;
  final String qrCodeUrl;
  final String otpauthUrl;

  TwoFactorSetupData({
    required this.secret,
    required this.qrCodeUrl,
    required this.otpauthUrl,
  });

  factory TwoFactorSetupData.fromJson(Map<String, dynamic> json) {
    return TwoFactorSetupData(
      secret: json['secret'] ?? '',
      qrCodeUrl: json['qrCodeUrl'] ?? json['qrCode'] ?? '',
      otpauthUrl: json['otpauthUrl'] ?? json['otpauth_url'] ?? '',
    );
  }
}
