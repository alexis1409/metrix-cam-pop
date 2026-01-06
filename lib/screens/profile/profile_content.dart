import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../models/asignacion_rtmt.dart';
import '../../providers/auth_provider.dart';
import '../../providers/demostrador_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/photo_storage_service.dart';
import '../settings/two_factor_setup_screen.dart';

/// Profile content widget - to be used inside a tab/indexed stack
class ProfileContent extends StatefulWidget {
  const ProfileContent({super.key});

  @override
  State<ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<ProfileContent> {
  bool _is2FAEnabled = false;
  bool _is2FALoading = true;

  // Stats
  Map<String, dynamic> _stats = {};
  bool _isLoadingStats = true;

  // Storage
  String _storageUsed = 'Calculando...';
  int _pendingPhotos = 0;

  late UserService _userService;
  late AuthService _authService;

  @override
  void initState() {
    super.initState();
    final apiService = context.read<ApiService>();
    _userService = UserService(apiService);
    _authService = AuthService(apiService);
    _load2FAStatus();
    _loadStorageInfo();
    // Cargar stats después del primer frame para evitar errores de setState durante build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStats();
    });
  }

  Future<void> _load2FAStatus() async {
    try {
      final status = await _authService.get2FAStatus();
      if (mounted) {
        setState(() {
          _is2FAEnabled = status;
          _is2FALoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _is2FALoading = false);
      }
    }
  }

  Future<void> _loadStats() async {
    try {
      final apiService = context.read<ApiService>();

      // Obtener estadísticas del nuevo endpoint
      final statsResponse = await apiService.get('/asignaciones/demostrador/estadisticas');
      debugPrint('📊 [Stats] Response: $statsResponse');

      final campanias = statsResponse['campanias'] ?? {};
      final asignacionesMes = statsResponse['asignacionesMes'] ?? {};

      if (mounted) {
        setState(() {
          _stats = {
            'campaniasProximas': campanias['proximas'] ?? 0,
            'campaniasActivas': campanias['activas'] ?? 0,
            'campaniasTerminadas': campanias['terminadas'] ?? 0,
            'asignacionesCompletas': asignacionesMes['completas'] ?? 0,
            'asignacionesIncompletas': asignacionesMes['incompletas'] ?? 0,
          };
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [Stats] Error loading stats: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
          _stats = {
            'campaniasProximas': 0,
            'campaniasActivas': 0,
            'campaniasTerminadas': 0,
            'asignacionesCompletas': 0,
            'asignacionesIncompletas': 0,
          };
        });
      }
    }
  }

  Future<void> _loadStorageInfo() async {
    try {
      final photoStorage = PhotoStorageService();
      final sizeMB = await photoStorage.getStorageUsed();
      final pending = await photoStorage.getPendingPhotosCount();

      if (mounted) {
        setState(() {
          _storageUsed = _formatMB(sizeMB);
          _pendingPhotos = pending;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _storageUsed = 'No disponible';
          _pendingPhotos = 0;
        });
      }
    }
  }

  String _formatMB(double mb) {
    if (mb < 0.001) return '0 KB';
    if (mb < 1) return '${(mb * 1024).toStringAsFixed(0)} KB';
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final user = authProvider.user;
          if (user == null) {
            return const Center(child: Text('No hay usuario'));
          }

          return CustomScrollView(
            slivers: [
              _buildAppBar(user.name, user.email),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildStatsSection(),
                    const SizedBox(height: 16),
                    _buildPersonalInfoSection(user),
                    const SizedBox(height: 16),
                    _buildWorkInfoSection(user),
                    const SizedBox(height: 16),
                    _buildSecuritySection(),
                    const SizedBox(height: 16),
                    _buildAppSettingsSection(),
                    const SizedBox(height: 16),
                    _buildStorageSection(),
                    const SizedBox(height: 16),
                    _buildSupportSection(),
                    const SizedBox(height: 16),
                    _buildAboutSection(),
                    const SizedBox(height: 24),
                    _buildLogoutButton(),
                    const SizedBox(height: 120), // Extra padding for bottom nav
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAppBar(String name, String email) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppColors.primaryStart,
      automaticallyImplyLeading: false, // No back button
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withAlpha(50), width: 3),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return _buildSection(
      title: 'Mis Estadísticas',
      icon: Icons.bar_chart_rounded,
      iconColor: AppColors.primaryStart,
      child: _isLoadingStats
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subtítulo Campañas
                _buildSubtitle('Campañas'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildStatCard('Próximas', '${_stats['campaniasProximas'] ?? 0}', 'campañas', Colors.orange)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard('Activas', '${_stats['campaniasActivas'] ?? 0}', 'campañas', Colors.blue)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard('Terminadas', '${_stats['campaniasTerminadas'] ?? 0}', 'campañas', AppColors.success)),
                  ],
                ),
                const SizedBox(height: 16),
                // Subtítulo Asignaciones del Mes
                _buildSubtitle('Asignaciones del Mes'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildStatCard('Completas', '${_stats['asignacionesCompletas'] ?? 0}', 'asignaciones', AppColors.success)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard('Incompletas', '${_stats['asignacionesIncompletas'] ?? 0}', 'asignaciones', Colors.red)),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildSubtitle(String text) {
    return Builder(
      builder: (context) => Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.primaryStart,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, Color color) {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(context.isDarkMode ? 30 : 15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(context.isDarkMode ? 50 : 30)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: color.withAlpha(180),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: context.textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(String title, double percentage) {
    final color = percentage >= 80 ? AppColors.success : (percentage >= 50 ? Colors.orange : AppColors.error);
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.isDarkMode ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: context.textPrimaryColor)),
                Text(
                  '${percentage.toInt()}%',
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: color.withAlpha(context.isDarkMode ? 50 : 30),
                valueColor: AlwaysStoppedAnimation(color),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoSection(dynamic user) {
    return _buildSection(
      title: 'Información Personal',
      icon: Icons.person_outline_rounded,
      iconColor: AppColors.secondaryStart,
      child: Column(
        children: [
          _buildInfoTile(Icons.badge_outlined, 'Nombre', user.name ?? 'Sin nombre'),
          Divider(height: 1, color: context.borderColor),
          _buildInfoTile(
            Icons.phone_outlined,
            'Teléfono',
            user.phone != null && user.phone.isNotEmpty ? user.phone : 'No registrado',
          ),
          Divider(height: 1, color: context.borderColor),
          _buildInfoTile(Icons.email_outlined, 'Email', user.email ?? 'Sin email'),
        ],
      ),
    );
  }

  Widget _buildWorkInfoSection(dynamic user) {
    return _buildSection(
      title: 'Información de Trabajo',
      icon: Icons.work_outline_rounded,
      iconColor: Colors.teal,
      child: Column(
        children: [
          _buildInfoTile(Icons.badge_outlined, 'ID Empleado', user.id.substring(0, 8).toUpperCase()),
          Divider(height: 1, color: context.borderColor),
          _buildInfoTile(Icons.admin_panel_settings_outlined, 'Rol', 'Impulsador'),
          Divider(height: 1, color: context.borderColor),
          _buildInfoTile(Icons.location_city_outlined, 'Zona', 'Por asignar'),
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    return _buildSection(
      title: 'Seguridad',
      icon: Icons.shield_outlined,
      iconColor: AppColors.error,
      child: Column(
        children: [
          _buildActionTile(
            icon: Icons.security_rounded,
            iconColor: _is2FAEnabled ? AppColors.success : null,
            title: 'Autenticación de dos factores',
            subtitle: _is2FALoading ? 'Cargando...' : (_is2FAEnabled ? 'Activada' : 'Desactivada'),
            trailing: _is2FALoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(
                    _is2FAEnabled ? Icons.check_circle : Icons.chevron_right,
                    color: _is2FAEnabled ? AppColors.success : AppColors.textMuted,
                  ),
            onTap: _is2FALoading ? null : _navigateTo2FASetup,
          ),
        ],
      ),
    );
  }

  Widget _buildAppSettingsSection() {
    return _buildSection(
      title: 'Configuración de la App',
      icon: Icons.settings_outlined,
      iconColor: Colors.purple,
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return Column(
            children: [
              _buildSwitchTile(
                icon: Icons.notifications_outlined,
                title: 'Notificaciones push',
                value: settings.notificationsEnabled,
                onChanged: (v) => settings.setNotificationsEnabled(v),
              ),
              Divider(height: 1, color: context.borderColor),
              _buildSwitchTile(
                icon: Icons.dark_mode_outlined,
                title: 'Modo oscuro',
                value: settings.darkModeEnabled,
                onChanged: (v) => settings.setDarkModeEnabled(v),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStorageSection() {
    return _buildSection(
      title: 'Almacenamiento',
      icon: Icons.storage_outlined,
      iconColor: Colors.indigo,
      child: Column(
        children: [
          _buildInfoTile(Icons.folder_outlined, 'Espacio usado', _storageUsed),
          Divider(height: 1, color: context.borderColor),
          _buildInfoTile(
            Icons.cloud_upload_outlined,
            'Fotos pendientes',
            '$_pendingPhotos fotos',
            valueColor: _pendingPhotos > 0 ? Colors.orange : AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildSupportSection() {
    return _buildSection(
      title: 'Ayuda y Soporte',
      icon: Icons.help_outline_rounded,
      iconColor: Colors.blue,
      child: Column(
        children: [
          _buildActionTile(
            icon: Icons.chat_outlined,
            title: 'Contactar soporte',
            subtitle: 'WhatsApp o Email',
            onTap: _showContactOptions,
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return _buildSection(
      title: 'Acerca de',
      icon: Icons.info_outline_rounded,
      iconColor: AppColors.textSecondary,
      child: Column(
        children: [
          _buildInfoTile(Icons.apps, 'Versión', '1.1.0 (Build 2)'),
          Divider(height: 1, color: context.borderColor),
          _buildActionTile(
            icon: Icons.description_outlined,
            title: 'Términos y condiciones',
            onTap: () => _openUrl('https://metrix.com/terms'),
          ),
          Divider(height: 1, color: context.borderColor),
          _buildActionTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Política de privacidad',
            onTap: () => _openUrl('https://metrix.com/privacy'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withAlpha(50)),
      ),
      child: Material(
        color: AppColors.error.withAlpha(10),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _showLogoutDialog,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: AppColors.error),
                const SizedBox(width: 12),
                Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Builder(
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: context.isDarkMode ? [] : AppShadows.small,
          border: context.isDarkMode ? Border.all(color: context.borderColor) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withAlpha(context.isDarkMode ? 40 : 20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value, {Color? valueColor}) {
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: context.textMutedColor, size: 22),
            const SizedBox(width: 14),
            Text(title, style: TextStyle(color: context.textSecondaryColor)),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor ?? context.textPrimaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return Builder(
      builder: (context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: iconColor ?? context.textMutedColor, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: context.textPrimaryColor)),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 12, color: context.textSecondaryColor),
                        ),
                    ],
                  ),
                ),
                trailing ?? Icon(Icons.chevron_right, color: context.textMutedColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Builder(
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: context.textMutedColor, size: 22),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: context.textPrimaryColor))),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primaryStart,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateTo2FASetup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TwoFactorSetupScreen(isEnabled: _is2FAEnabled, authService: _authService),
      ),
    );
    _load2FAStatus();
  }

  Future<void> _showLogoutDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = ctx.isDarkMode;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(isDark ? 40 : 20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout, color: AppColors.error),
              ),
              const SizedBox(width: 12),
              Text('Cerrar sesión', style: TextStyle(color: ctx.textPrimaryColor)),
            ],
          ),
          content: Text('¿Estás seguro que deseas cerrar sesión?', style: TextStyle(color: ctx.textSecondaryColor)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar', style: TextStyle(color: ctx.textSecondaryColor)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Salir'),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  void _showContactOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = ctx.isDarkMode;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: ctx.borderColor, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text('Contactar Soporte', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: ctx.textPrimaryColor)),
              const SizedBox(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.green.withAlpha(isDark ? 40 : 20), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.chat, color: Colors.green),
                ),
                title: Text('WhatsApp', style: TextStyle(color: ctx.textPrimaryColor)),
                subtitle: Text('+52 55 1234 5678', style: TextStyle(color: ctx.textSecondaryColor)),
                onTap: () => _openUrl('https://wa.me/5255123456'),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue.withAlpha(isDark ? 40 : 20), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.email, color: Colors.blue),
                ),
                title: Text('Email', style: TextStyle(color: ctx.textPrimaryColor)),
                subtitle: Text('soporte@metrix.com', style: TextStyle(color: ctx.textSecondaryColor)),
                onTap: () => _openUrl('mailto:soporte@metrix.com'),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
