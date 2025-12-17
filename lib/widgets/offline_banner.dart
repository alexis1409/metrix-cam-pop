import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/sync_provider.dart';

/// Banner that shows when the app is offline or has pending sync items
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectivityProvider, SyncProvider>(
      builder: (context, connectivity, sync, _) {
        if (!connectivity.isInitialized) {
          return const SizedBox.shrink();
        }

        // Offline banner
        if (connectivity.isOffline) {
          return _buildBanner(
            context,
            icon: Icons.wifi_off,
            message: 'Sin conexión',
            color: Colors.grey.shade700,
          );
        }

        // Syncing banner
        if (sync.isSyncing) {
          return _buildBanner(
            context,
            icon: Icons.sync,
            message: 'Sincronizando...',
            color: Colors.blue,
            showProgress: true,
          );
        }

        // Pending items banner
        if (sync.hasPending) {
          return _buildBanner(
            context,
            icon: Icons.cloud_upload_outlined,
            message: '${sync.pendingCount} pendientes de sincronizar',
            color: Colors.orange,
            onTap: () => sync.syncNow(),
          );
        }

        // Error banner
        if (sync.hasErrors) {
          return _buildBanner(
            context,
            icon: Icons.error_outline,
            message: 'Error en sincronización',
            color: Colors.red,
            onTap: () => sync.syncNow(),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildBanner(
    BuildContext context, {
    required IconData icon,
    required String message,
    required Color color,
    bool showProgress = false,
    VoidCallback? onTap,
  }) {
    final banner = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (showProgress)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else
              Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onTap != null)
              GestureDetector(
                onTap: onTap,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return banner;
  }
}

/// A small sync indicator for app bars
class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectivityProvider, SyncProvider>(
      builder: (context, connectivity, sync, _) {
        if (!connectivity.isInitialized) {
          return const SizedBox.shrink();
        }

        // Offline indicator
        if (connectivity.isOffline) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.wifi_off,
              size: 20,
              color: Colors.grey,
            ),
          );
        }

        // Syncing indicator
        if (sync.isSyncing) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          );
        }

        // Pending badge
        if (sync.hasPending) {
          return GestureDetector(
            onTap: () => sync.syncNow(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Badge(
                label: Text('${sync.pendingCount}'),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  size: 20,
                  color: Colors.orange,
                ),
              ),
            ),
          );
        }

        // All synced - green check
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(
            Icons.cloud_done,
            size: 20,
            color: Colors.green,
          ),
        );
      },
    );
  }
}
