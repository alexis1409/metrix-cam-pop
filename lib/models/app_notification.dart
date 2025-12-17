import 'package:flutter/material.dart';

enum NotificationType {
  info,
  success,
  warning,
  error,
  campaign,
  task,
  system,
}

enum NotificationPriority {
  low,
  normal,
  high,
  urgent,
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final NotificationPriority priority;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? actionUrl;
  final String? actionType;
  final Map<String, dynamic>? data;
  final String? imageUrl;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.priority = NotificationPriority.normal,
    this.isRead = false,
    required this.createdAt,
    this.readAt,
    this.actionUrl,
    this.actionType,
    this.data,
    this.imageUrl,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? json['message'] ?? '',
      type: _parseType(json['type']),
      priority: _parsePriority(json['priority']),
      isRead: json['isRead'] ?? json['read'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      readAt: json['readAt'] != null ? DateTime.parse(json['readAt']) : null,
      actionUrl: json['actionUrl'],
      actionType: json['actionType'],
      data: json['data'],
      imageUrl: json['imageUrl'] ?? json['image'],
    );
  }

  factory AppNotification.fromPushNotification(Map<String, dynamic> message) {
    final data = message['data'] as Map<String, dynamic>? ?? {};
    final notification = message['notification'] as Map<String, dynamic>? ?? {};

    return AppNotification(
      id: data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: notification['title'] ?? data['title'] ?? '',
      body: notification['body'] ?? data['body'] ?? '',
      type: _parseType(data['type']),
      priority: _parsePriority(data['priority']),
      isRead: false,
      createdAt: DateTime.now(),
      actionUrl: data['actionUrl'],
      actionType: data['actionType'],
      data: data,
      imageUrl: notification['image'] ?? data['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type.name,
      'priority': priority.name,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'actionUrl': actionUrl,
      'actionType': actionType,
      'data': data,
      'imageUrl': imageUrl,
    };
  }

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    NotificationType? type,
    NotificationPriority? priority,
    bool? isRead,
    DateTime? createdAt,
    DateTime? readAt,
    String? actionUrl,
    String? actionType,
    Map<String, dynamic>? data,
    String? imageUrl,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      actionUrl: actionUrl ?? this.actionUrl,
      actionType: actionType ?? this.actionType,
      data: data ?? this.data,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  static NotificationType _parseType(String? type) {
    switch (type?.toLowerCase()) {
      case 'info':
        return NotificationType.info;
      case 'success':
        return NotificationType.success;
      case 'warning':
        return NotificationType.warning;
      case 'error':
        return NotificationType.error;
      case 'campaign':
        return NotificationType.campaign;
      case 'task':
        return NotificationType.task;
      case 'system':
        return NotificationType.system;
      default:
        return NotificationType.info;
    }
  }

  static NotificationPriority _parsePriority(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'low':
        return NotificationPriority.low;
      case 'normal':
        return NotificationPriority.normal;
      case 'high':
        return NotificationPriority.high;
      case 'urgent':
        return NotificationPriority.urgent;
      default:
        return NotificationPriority.normal;
    }
  }

  // UI Helpers
  IconData get icon {
    switch (type) {
      case NotificationType.info:
        return Icons.info_outline;
      case NotificationType.success:
        return Icons.check_circle_outline;
      case NotificationType.warning:
        return Icons.warning_amber_outlined;
      case NotificationType.error:
        return Icons.error_outline;
      case NotificationType.campaign:
        return Icons.campaign_outlined;
      case NotificationType.task:
        return Icons.task_alt_outlined;
      case NotificationType.system:
        return Icons.settings_outlined;
    }
  }

  Color get color {
    switch (type) {
      case NotificationType.info:
        return Colors.blue;
      case NotificationType.success:
        return Colors.green;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.error:
        return Colors.red;
      case NotificationType.campaign:
        return Colors.purple;
      case NotificationType.task:
        return Colors.teal;
      case NotificationType.system:
        return Colors.grey;
    }
  }

  String get typeLabel {
    switch (type) {
      case NotificationType.info:
        return 'Información';
      case NotificationType.success:
        return 'Éxito';
      case NotificationType.warning:
        return 'Advertencia';
      case NotificationType.error:
        return 'Error';
      case NotificationType.campaign:
        return 'Campaña';
      case NotificationType.task:
        return 'Tarea';
      case NotificationType.system:
        return 'Sistema';
    }
  }

  bool get isUrgent => priority == NotificationPriority.urgent;
  bool get isHighPriority =>
      priority == NotificationPriority.high ||
      priority == NotificationPriority.urgent;

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'Ahora';
    } else if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} h';
    } else if (difference.inDays < 7) {
      return 'Hace ${difference.inDays} días';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }
}

// Extension for grouping notifications by date
extension NotificationListExtensions on List<AppNotification> {
  Map<String, List<AppNotification>> groupByDate() {
    final Map<String, List<AppNotification>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final notification in this) {
      final notificationDate = DateTime(
        notification.createdAt.year,
        notification.createdAt.month,
        notification.createdAt.day,
      );

      String key;
      if (notificationDate == today) {
        key = 'Hoy';
      } else if (notificationDate == yesterday) {
        key = 'Ayer';
      } else if (now.difference(notificationDate).inDays < 7) {
        key = 'Esta semana';
      } else if (now.difference(notificationDate).inDays < 30) {
        key = 'Este mes';
      } else {
        key = 'Anteriores';
      }

      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(notification);
    }

    return grouped;
  }
}
