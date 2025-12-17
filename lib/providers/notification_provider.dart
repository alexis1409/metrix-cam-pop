import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService;

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _errorMessage;
  NotificationType? _filterType;
  bool _showUnreadOnly = false;
  Timer? _refreshTimer;

  // Getters
  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  NotificationType? get filterType => _filterType;
  bool get showUnreadOnly => _showUnreadOnly;
  bool get hasNotifications => _notifications.isNotEmpty;
  bool get hasUnread => _unreadCount > 0;

  // Filtered notifications
  List<AppNotification> get filteredNotifications {
    var filtered = _notifications;

    if (_filterType != null) {
      filtered = filtered.where((n) => n.type == _filterType).toList();
    }

    if (_showUnreadOnly) {
      filtered = filtered.where((n) => !n.isRead).toList();
    }

    return filtered;
  }

  // Grouped notifications by date
  Map<String, List<AppNotification>> get groupedNotifications {
    return filteredNotifications.groupByDate();
  }

  NotificationProvider(this._notificationService);

  /// Initialize and start auto-refresh
  Future<void> initialize() async {
    await refresh();
    _startAutoRefresh();
  }

  /// Start auto-refresh timer (every 30 seconds)
  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      refreshUnreadCount();
    });
  }

  /// Stop auto-refresh timer
  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Refresh notifications and unread count
  Future<void> refresh() async {
    _currentPage = 1;
    _hasMore = true;
    _notifications = [];
    await Future.wait([
      loadNotifications(),
      refreshUnreadCount(),
    ]);
  }

  /// Load notifications with pagination
  Future<void> loadNotifications() async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newNotifications = await _notificationService.getNotifications(
        page: _currentPage,
        limit: 20,
        type: _filterType?.name,
        unreadOnly: _showUnreadOnly ? true : null,
      );

      if (_currentPage == 1) {
        _notifications = newNotifications;
      } else {
        _notifications.addAll(newNotifications);
      }

      _hasMore = newNotifications.length >= 20;
      _currentPage++;
    } catch (e) {
      _errorMessage = 'Error al cargar notificaciones';
      debugPrint('Error loading notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load more notifications (pagination)
  Future<void> loadMore() async {
    if (!_hasMore || _isLoading) return;
    await loadNotifications();
  }

  /// Refresh only unread count
  Future<void> refreshUnreadCount() async {
    try {
      _unreadCount = await _notificationService.getUnreadCount();
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing unread count: $e');
    }
  }

  /// Mark a notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _notificationService.markAsRead(notificationId);

      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1 && !_notifications[index].isRead) {
        _notifications[index] = _notifications[index].copyWith(
          isRead: true,
          readAt: DateTime.now(),
        );
        _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();

      _notifications = _notifications
          .map((n) => n.copyWith(isRead: true, readAt: DateTime.now()))
          .toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al marcar todas como leídas';
      notifyListeners();
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    final notification = _notifications.firstWhere(
      (n) => n.id == notificationId,
      orElse: () => throw Exception('Notification not found'),
    );

    try {
      await _notificationService.deleteNotification(notificationId);

      _notifications.removeWhere((n) => n.id == notificationId);
      if (!notification.isRead) {
        _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount);
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al eliminar notificación';
      notifyListeners();
    }
  }

  /// Delete multiple notifications
  Future<void> deleteMultiple(List<String> notificationIds) async {
    try {
      await _notificationService.deleteMultiple(notificationIds);

      final deletedUnread = _notifications
          .where((n) => notificationIds.contains(n.id) && !n.isRead)
          .length;

      _notifications.removeWhere((n) => notificationIds.contains(n.id));
      _unreadCount = (_unreadCount - deletedUnread).clamp(0, _unreadCount);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al eliminar notificaciones';
      notifyListeners();
    }
  }

  /// Set filter by type
  void setFilterType(NotificationType? type) {
    _filterType = type;
    notifyListeners();
  }

  /// Toggle unread only filter
  void toggleUnreadOnly() {
    _showUnreadOnly = !_showUnreadOnly;
    notifyListeners();
  }

  /// Clear all filters
  void clearFilters() {
    _filterType = null;
    _showUnreadOnly = false;
    notifyListeners();
  }

  /// Add notification from push
  void addFromPush(AppNotification notification) {
    _notifications.insert(0, notification);
    _unreadCount++;
    notifyListeners();
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }
}
