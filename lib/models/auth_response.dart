import 'user.dart';

/// Result of a login attempt
class LoginResult {
  final bool success;
  final bool requiresTwoFactor;
  final AuthResponse? authResponse;
  final String? errorMessage;

  LoginResult._({
    required this.success,
    this.requiresTwoFactor = false,
    this.authResponse,
    this.errorMessage,
  });

  /// Successful login
  factory LoginResult.success(AuthResponse response) {
    return LoginResult._(success: true, authResponse: response);
  }

  /// 2FA required - need to show code input
  factory LoginResult.requires2FA() {
    return LoginResult._(success: false, requiresTwoFactor: true);
  }

  /// Login failed with error
  factory LoginResult.error(String message) {
    return LoginResult._(success: false, errorMessage: message);
  }

  /// Parse API response and determine result type
  static LoginResult fromJson(Map<String, dynamic> json) {
    // Check if 2FA is required
    if (json['requiresTwoFactor'] == true) {
      return LoginResult.requires2FA();
    }

    // Normal successful login
    return LoginResult.success(AuthResponse.fromJson(json));
  }
}

class AuthResponse {
  final String accessToken;
  final User user;

  AuthResponse({
    required this.accessToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] ?? '',
      user: User.fromJson(json['user'] ?? {}),
    );
  }
}
