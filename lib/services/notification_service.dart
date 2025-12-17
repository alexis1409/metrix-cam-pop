import '../config/api_config.dart';
import '../models/app_notification.dart';
import 'api_service.dart';

class NotificationService {
  final ApiService _apiService;

  NotificationService(this._apiService);

  /// Get all notifications with optional filtering
  Future<List<AppNotification>> getNotifications({
    int page = 1,
    int limit = 20,
    String? type,
    bool? unreadOnly,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (type != null) queryParams['type'] = type;
    if (unreadOnly == true) queryParams['unreadOnly'] = 'true';

    final queryString = queryParams.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');

    final response = await _apiService.get(
      '${ApiConfig.notifications}?$queryString',
    );

    final List<dynamic> data = response is List
        ? response
        : (response['data'] ?? response['notifications'] ?? []);

    return data.map((json) => AppNotification.fromJson(json)).toList();
  }

  /// Get unread notifications count
  Future<int> getUnreadCount() async {
    try {
      final response = await _apiService.get(ApiConfig.notificationsUnreadCount);
      return response['count'] ?? response['unreadCount'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    await _apiService.post(
      '${ApiConfig.notificationsMarkRead}/$notificationId',
      {},
    );
  }

  /// Mark multiple notifications as read
  Future<void> markMultipleAsRead(List<String> notificationIds) async {
    await _apiService.post(
      ApiConfig.notificationsMarkRead,
      {'ids': notificationIds},
    );
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    await _apiService.post(ApiConfig.notificationsMarkAllRead, {});
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    await _apiService.delete('${ApiConfig.notifications}/$notificationId');
  }

  /// Delete multiple notifications
  Future<void> deleteMultiple(List<String> notificationIds) async {
    await _apiService.post(
      '${ApiConfig.notifications}/delete-multiple',
      {'ids': notificationIds},
    );
  }

  /// Register device for push notifications
  Future<void> registerDevice({
    required String token,
    required String platform,
    String? deviceId,
  }) async {
    await _apiService.post(
      ApiConfig.notificationsRegisterDevice,
      {
        'token': token,
        'platform': platform,
        if (deviceId != null) 'deviceId': deviceId,
      },
    );
  }

  /// Unregister device from push notifications
  Future<void> unregisterDevice(String token) async {
    await _apiService.delete(
      '${ApiConfig.notificationsRegisterDevice}/$token',
    );
  }
}
