import 'package:flutter/foundation.dart';
import '../models/auth_response.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../services/push_notification_service.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  requiresTwoFactor,
  error,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final ApiService _apiService;

  AuthStatus _status = AuthStatus.initial;
  User? _user;
  String? _errorMessage;

  // 2FA state
  String? _pendingEmail;
  String? _pendingPassword;

  AuthProvider(this._authService, this._apiService);

  AuthStatus get status => _status;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;
  bool get requiresTwoFactor => _status == AuthStatus.requiresTwoFactor;

  Future<void> checkAuthStatus() async {
    debugPrint('>>> AuthProvider: checkAuthStatus started');
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      debugPrint('>>> AuthProvider: calling isLoggedIn...');
      final isLoggedIn = await _authService.isLoggedIn();
      debugPrint('>>> AuthProvider: isLoggedIn = $isLoggedIn');
      if (isLoggedIn) {
        debugPrint('>>> AuthProvider: restoring session...');
        await _authService.restoreSession();
        debugPrint('>>> AuthProvider: getting saved user...');
        final savedUser = await _authService.getSavedUser();
        debugPrint('>>> AuthProvider: user loaded: ${savedUser?.name}');

        // Validate that user has allowed role (impulsador or supervisor_retailtainment)
        if (savedUser != null && !savedUser.hasRetailtainmentRole) {
          debugPrint('>>> AuthProvider: user does not have retailtainment role, logging out');
          await _authService.logout();
          _status = AuthStatus.unauthenticated;
        } else {
          _user = savedUser;
          _status = AuthStatus.authenticated;
        }
      } else {
        debugPrint('>>> AuthProvider: not logged in, status = unauthenticated');
        _status = AuthStatus.unauthenticated;
      }
    } catch (e) {
      debugPrint('>>> AuthProvider ERROR: $e');
      _status = AuthStatus.unauthenticated;
    }

    debugPrint('>>> AuthProvider: checkAuthStatus finished, status = $_status');
    notifyListeners();
  }

  /// Login - returns true if authenticated, false if 2FA required or error
  Future<LoginResult> login(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.login(email, password);

      if (result.requiresTwoFactor) {
        // Store credentials for 2FA step
        _pendingEmail = email;
        _pendingPassword = password;
        _status = AuthStatus.requiresTwoFactor;
        notifyListeners();
        return result;
      }

      if (result.success && result.authResponse != null) {
        final user = result.authResponse!.user;

        // Debug: Log user role information
        debugPrint('>>> AuthProvider LOGIN: user.role = ${user.role}');
        debugPrint('>>> AuthProvider LOGIN: user.rolRetailtainment = ${user.rolRetailtainment}');
        debugPrint('>>> AuthProvider LOGIN: user.hasRetailtainmentRole = ${user.hasRetailtainmentRole}');

        // Validate that user has allowed role (impulsador or supervisor_retailtainment)
        if (!user.hasRetailtainmentRole) {
          debugPrint('>>> AuthProvider LOGIN: BLOCKING user - no retailtainment role');
          // Logout and show error
          await _authService.logout();
          _errorMessage = 'Acceso no autorizado. Esta aplicación es exclusiva para personal de campo (Impulsador o Supervisor).';
          _status = AuthStatus.error;
          notifyListeners();
          return LoginResult.error(_errorMessage!);
        }

        debugPrint('>>> AuthProvider LOGIN: ALLOWING user - has retailtainment role');
        _user = user;
        _status = AuthStatus.authenticated;
        _clearPendingCredentials();

        // Register FCM token with backend
        _registerFcmToken();

        notifyListeners();
        return result;
      }

      _errorMessage = result.errorMessage ?? 'Error al iniciar sesión';
      _status = AuthStatus.error;
      notifyListeners();
      return result;
    } on ApiException catch (e) {
      debugPrint('>>> AuthProvider LOGIN ApiException: ${e.message}, statusCode: ${e.statusCode}');
      _errorMessage = _getFriendlyLoginError(e);
      _status = AuthStatus.error;
      notifyListeners();
      return LoginResult.error(_errorMessage!);
    } catch (e) {
      debugPrint('>>> AuthProvider LOGIN Exception: $e');
      _errorMessage = _getFriendlyConnectionError(e);
      _status = AuthStatus.error;
      notifyListeners();
      return LoginResult.error(_errorMessage!);
    }
  }

  /// Complete login with 2FA code
  Future<bool> verifyTwoFactorCode(String code) async {
    if (_pendingEmail == null || _pendingPassword == null) {
      _errorMessage = 'Sesión expirada. Intenta de nuevo';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.login(
        _pendingEmail!,
        _pendingPassword!,
        twoFactorCode: code,
      );

      if (result.success && result.authResponse != null) {
        final user = result.authResponse!.user;

        // Validate that user has allowed role (impulsador or supervisor_retailtainment)
        if (!user.hasRetailtainmentRole) {
          // Logout and show error
          await _authService.logout();
          _errorMessage = 'Acceso no autorizado. Esta aplicación es exclusiva para personal de campo (Impulsador o Supervisor).';
          _status = AuthStatus.error;
          _clearPendingCredentials();
          notifyListeners();
          return false;
        }

        _user = user;
        _status = AuthStatus.authenticated;
        _clearPendingCredentials();

        // Register FCM token with backend
        _registerFcmToken();

        notifyListeners();
        return true;
      }

      _errorMessage = result.errorMessage ?? 'Código incorrecto';
      _status = AuthStatus.requiresTwoFactor;
      notifyListeners();
      return false;
    } on ApiException catch (e) {
      _errorMessage = _get2FAError(e);
      _status = AuthStatus.requiresTwoFactor;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = _getFriendlyConnectionError(e);
      _status = AuthStatus.requiresTwoFactor;
      notifyListeners();
      return false;
    }
  }

  /// Cancel 2FA and go back to login
  void cancelTwoFactor() {
    _clearPendingCredentials();
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  void _clearPendingCredentials() {
    _pendingEmail = null;
    _pendingPassword = null;
  }

  String _get2FAError(ApiException e) {
    final statusCode = e.statusCode;
    final message = e.message.toLowerCase();

    if (statusCode == 401 || message.contains('invalid') || message.contains('incorrect')) {
      return 'Código incorrecto. Verifica e intenta de nuevo';
    }

    if (message.contains('expired')) {
      return 'Código expirado. Usa un nuevo código';
    }

    return 'Error al verificar código';
  }

  String _getFriendlyLoginError(ApiException e) {
    final message = e.message.toLowerCase();
    final statusCode = e.statusCode;

    // Check for role-related errors first (from backend)
    if (message.contains('rol') ||
        message.contains('role') ||
        message.contains('permiso') ||
        message.contains('permission') ||
        message.contains('acceso') ||
        message.contains('access denied') ||
        message.contains('no autorizado') ||
        message.contains('not authorized')) {
      return 'Acceso denegado. Tu rol no tiene permiso para usar esta aplicación.';
    }

    // Check for specific status codes
    if (statusCode == 403) {
      return 'Acceso denegado. Tu rol no tiene permiso para usar esta aplicación.';
    }

    if (statusCode == 401) {
      return 'Usuario o contraseña incorrectos';
    }

    if (statusCode == 404) {
      return 'Usuario no encontrado';
    }

    if (statusCode == 429) {
      return 'Demasiados intentos. Espera unos minutos';
    }

    if (statusCode != null && statusCode >= 500) {
      return 'El servidor no está disponible. Intenta más tarde';
    }

    // Check for common error messages
    if (message.contains('invalid') ||
        message.contains('incorrect') ||
        message.contains('wrong')) {
      return 'Usuario o contraseña incorrectos';
    }

    if (message.contains('not found') || message.contains('no existe')) {
      return 'Usuario no encontrado';
    }

    if (message.contains('disabled') || message.contains('blocked') || message.contains('inactive')) {
      return 'Tu cuenta está desactivada. Contacta al administrador';
    }

    // Return original message if it's already user-friendly
    if (e.message.length < 100 && !message.contains('exception')) {
      return e.message;
    }

    return 'Error al iniciar sesión. Verifica tus datos';
  }

  String _getFriendlyConnectionError(dynamic e) {
    final errorStr = e.toString().toLowerCase();

    if (errorStr.contains('socketexception') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('network is unreachable') ||
        errorStr.contains('no internet') ||
        errorStr.contains('failed host lookup')) {
      return 'Sin conexión a internet. Verifica tu red';
    }

    if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
      return 'El servidor tardó demasiado. Intenta de nuevo';
    }

    if (errorStr.contains('handshake') || errorStr.contains('certificate')) {
      return 'Error de seguridad de conexión';
    }

    return 'Error de conexión. Verifica tu internet';
  }

  Future<void> logout() async {
    // Remove FCM token from backend before logout
    try {
      await PushNotificationService().removeTokenFromBackend(_apiService);
    } catch (e) {
      debugPrint('Error removing FCM token: $e');
    }

    await _authService.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Register FCM token with backend (called after successful login)
  Future<void> _registerFcmToken() async {
    try {
      final pushService = PushNotificationService();
      if (pushService.isInitialized) {
        await pushService.registerTokenWithBackend(_apiService);
      }
    } catch (e) {
      debugPrint('Error registering FCM token: $e');
    }
  }

  void clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (_user == null) return;

    try {
      final userService = UserService(ApiService());
      final userData = await userService.getUser(_user!.id);
      _user = User.fromJson(userData);
      notifyListeners();
    } catch (e) {
      // Silently fail
    }
  }

  void updateUser(User newUser) {
    _user = newUser;
    notifyListeners();
  }
}
