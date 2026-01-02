class ApiConfig {
  // Change this to your backend URL
  // For Android emulator use: 10.0.2.2
  // For iOS simulator use: localhost
  // For real device use: your machine's IP address
  static const String baseUrl = 'http://192.168.0.44:3001';

  // Demostrador RTMT Endpoints
  static const String asignacionesUnified = '/asignaciones-unified';
  static const String demostradorHoy = '/asignaciones-unified/demostrador/hoy';
  static const String demostradorEstado = '/asignaciones-unified/demostrador/estado';

  // Endpoints
  static const String login = '/auth/login';
  static const String users = '/users';
  static const String campanias = '/campanias';
  static const String campaniasByInstalador = '/campanias/instalador';
  static const String tiendasPendientes = '/campanias/instalador'; // + /:userId/tiendas-pendientes
  static const String tiendas = '/tiendas';
  static const String medios = '/medios';
  static const String paises = '/paises';

  // 2FA Endpoints
  static const String twoFactorGenerate = '/auth/2fa/generate';
  static const String twoFactorEnable = '/auth/2fa/enable';
  static const String twoFactorDisable = '/auth/2fa/disable';
  static const String twoFactorStatus = '/auth/2fa/status';

  // Notification Endpoints
  static const String notifications = '/notifications';
  static const String notificationsUnreadCount = '/notifications/unread-count';
  static const String notificationsMarkRead = '/notifications/mark-read';
  static const String notificationsMarkAllRead = '/notifications/mark-all-read';
  static const String notificationsRegisterDevice = '/notifications/register-device';
}
