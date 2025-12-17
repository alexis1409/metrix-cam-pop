import '../config/api_config.dart';
import 'api_service.dart';

class UserService {
  final ApiService _apiService;

  UserService(this._apiService);

  Future<Map<String, dynamic>> getUser(String userId) async {
    return await _apiService.get('${ApiConfig.users}/$userId');
  }

  Future<Map<String, dynamic>> updateUser(String userId, Map<String, dynamic> data) async {
    return await _apiService.patch('${ApiConfig.users}/$userId', data);
  }

  Future<void> changePassword(String userId, String newPassword) async {
    await _apiService.patch('${ApiConfig.users}/$userId', {
      'password': newPassword,
    });
  }

  /// Get user statistics for profile
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      return await _apiService.get('${ApiConfig.users}/$userId/stats');
    } catch (e) {
      // Return default stats if API fails
      return {
        'fotosSubidas': 0,
        'tiendasVisitadas': 0,
        'campaniasCompletadas': 0,
        'diasActivo': 0,
        'metaMensual': 100,
        'progresoMeta': 0,
      };
    }
  }
}
