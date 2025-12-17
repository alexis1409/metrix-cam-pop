import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_notification.dart';
import '../../providers/notification_provider.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().refresh();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<NotificationProvider>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.notifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              _buildFilters(provider),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: provider.refresh,
                  child: provider.filteredNotifications.isEmpty
                      ? _buildEmptyState(provider)
                      : _buildNotificationList(provider),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Notificaciones',
        style: TextStyle(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        Consumer<NotificationProvider>(
          builder: (context, provider, _) {
            if (provider.hasUnread) {
              return TextButton(
                onPressed: () => _showMarkAllReadDialog(provider),
                child: const Text('Marcar todas'),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.black87),
          onSelected: (value) => _handleMenuAction(value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'mark_all_read',
              child: Row(
                children: [
                  Icon(Icons.done_all, size: 20),
                  SizedBox(width: 12),
                  Text('Marcar todas como leídas'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'clear_filters',
              child: Row(
                children: [
                  Icon(Icons.filter_alt_off, size: 20),
                  SizedBox(width: 12),
                  Text('Limpiar filtros'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilters(NotificationProvider provider) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Filter chips row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'Todas',
                  isSelected: provider.filterType == null,
                  onSelected: () => provider.setFilterType(null),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'No leídas',
                  isSelected: provider.showUnreadOnly,
                  onSelected: () => provider.toggleUnreadOnly(),
                  count: provider.unreadCount,
                ),
                const SizedBox(width: 8),
                ...NotificationType.values.map((type) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildFilterChip(
                      label: _getTypeLabel(type),
                      isSelected: provider.filterType == type,
                      onSelected: () => provider.setFilterType(type),
                      color: _getTypeColor(type),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    int? count,
    Color? color,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count != null && count > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count > 99 ? '99+' : count.toString(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Theme.of(context).primaryColor : Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: color ?? Theme.of(context).primaryColor.withAlpha(50),
      checkmarkColor: color ?? Theme.of(context).primaryColor,
      backgroundColor: Colors.grey[100],
      side: BorderSide(
        color: isSelected ? (color ?? Theme.of(context).primaryColor) : Colors.transparent,
      ),
    );
  }

  Widget _buildNotificationList(NotificationProvider provider) {
    final grouped = provider.groupedNotifications;
    final dateGroups = ['Hoy', 'Ayer', 'Esta semana', 'Este mes', 'Anteriores'];

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: dateGroups.length + 1, // +1 for loading indicator
      itemBuilder: (context, index) {
        if (index == dateGroups.length) {
          return provider.hasMore && provider.isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              : const SizedBox.shrink();
        }

        final dateGroup = dateGroups[index];
        final notifications = grouped[dateGroup];

        if (notifications == null || notifications.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                dateGroup,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ),
            ...notifications.map((notification) {
              return _buildNotificationCard(notification, provider);
            }),
          ],
        );
      },
    );
  }

  Widget _buildNotificationCard(
    AppNotification notification,
    NotificationProvider provider,
  ) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmDialog();
      },
      onDismissed: (direction) {
        provider.deleteNotification(notification.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Notificación eliminada'),
            action: SnackBarAction(
              label: 'Deshacer',
              onPressed: () {
                // TODO: Implement undo
              },
            ),
          ),
        );
      },
      child: InkWell(
        onTap: () => _handleNotificationTap(notification, provider),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: notification.isRead ? Colors.white : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: notification.isUrgent
                ? Border.all(color: Colors.red, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: notification.color.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    notification.icon,
                    color: notification.color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontWeight: notification.isRead
                                    ? FontWeight.w500
                                    : FontWeight.bold,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            notification.timeAgo,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: notification.color.withAlpha(30),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              notification.typeLabel,
                              style: TextStyle(
                                fontSize: 11,
                                color: notification.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (notification.isUrgent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withAlpha(30),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.priority_high,
                                    size: 12,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    'Urgente',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(NotificationProvider provider) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                provider.showUnreadOnly || provider.filterType != null
                    ? Icons.filter_alt_outlined
                    : Icons.notifications_none_outlined,
                size: 80,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                provider.showUnreadOnly || provider.filterType != null
                    ? 'No hay notificaciones con estos filtros'
                    : 'No tienes notificaciones',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                provider.showUnreadOnly || provider.filterType != null
                    ? 'Prueba quitando algunos filtros'
                    : 'Las notificaciones aparecerán aquí',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                ),
              ),
              if (provider.showUnreadOnly || provider.filterType != null) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => provider.clearFilters(),
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('Limpiar filtros'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _handleNotificationTap(
    AppNotification notification,
    NotificationProvider provider,
  ) {
    // Mark as read
    if (!notification.isRead) {
      provider.markAsRead(notification.id);
    }

    // Handle action based on notification type/action
    if (notification.actionType != null) {
      // TODO: Handle different action types
      // e.g., navigate to campaign, task, etc.
    }

    // Show notification detail
    _showNotificationDetail(notification);
  }

  void _showNotificationDetail(AppNotification notification) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Icon and type
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: notification.color.withAlpha(30),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    notification.icon,
                    color: notification.color,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.typeLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: notification.color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        notification.timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Title
            Text(
              notification.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            // Body
            Text(
              notification.body,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // Actions
            if (notification.actionUrl != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // TODO: Handle action navigation
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Ver detalles'),
                ),
              ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text('Eliminar notificación'),
            content: const Text('¿Estás seguro de eliminar esta notificación?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showMarkAllReadDialog(NotificationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text('Marcar todas como leídas'),
        content: const Text(
          '¿Deseas marcar todas las notificaciones como leídas?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              provider.markAllAsRead();
            },
            child: const Text('Marcar todas'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action) {
    final provider = context.read<NotificationProvider>();
    switch (action) {
      case 'mark_all_read':
        _showMarkAllReadDialog(provider);
        break;
      case 'clear_filters':
        provider.clearFilters();
        break;
    }
  }

  String _getTypeLabel(NotificationType type) {
    switch (type) {
      case NotificationType.info:
        return 'Info';
      case NotificationType.success:
        return 'Éxito';
      case NotificationType.warning:
        return 'Alerta';
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

  Color _getTypeColor(NotificationType type) {
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
}
