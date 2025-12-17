import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/photo_storage_service.dart';
import '../settings/two_factor_setup_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isSaving = false;
  String? _errorMessage;
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
    _loadUserData();
    _load2FAStatus();
    _loadStats();
    _loadStorageInfo();
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
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        final stats = await _userService.getUserStats(user.id);
        if (mounted) {
          setState(() {
            _stats = stats;
            _isLoadingStats = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
          // Mock stats for demo
          _stats = {
            'tiendasHoy': 0,
            'tiendasSemana': 0,
            'tiendasMes': 0,
            'fotosHoy': 0,
            'fotosMes': 0,
            'campaniasCumplidas': 0,
            'porcentajeCumplimiento': 0,
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

  void _loadUserData() {
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phone ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.user;
      if (user == null) return;

      await _userService.updateUser(user.id, {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      });

      await authProvider.refreshUser();

      if (mounted) {
        _showSuccessSnackBar('Perfil actualizado');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error al guardar: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                    _buildPersonalInfoSection(),
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
                    const SizedBox(height: 32),
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
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
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
              children: [
                Row(
                  children: [
                    Expanded(child: _buildStatCard('Hoy', '${_stats['tiendasHoy'] ?? 0}', 'tiendas', AppColors.primaryStart)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard('Semana', '${_stats['tiendasSemana'] ?? 0}', 'tiendas', AppColors.secondaryStart)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildStatCard('Mes', '${_stats['tiendasMes'] ?? 0}', 'tiendas', AppColors.success)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildStatCard('Fotos', '${_stats['fotosHoy'] ?? 0}', 'hoy', Colors.orange)),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildProgressCard(
                        'Cumplimiento',
                        (_stats['porcentajeCumplimiento'] ?? 0).toDouble(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(30)),
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
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(String title, double percentage) {
    final color = percentage >= 80 ? AppColors.success : (percentage >= 50 ? Colors.orange : AppColors.error);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
              backgroundColor: color.withAlpha(30),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    return _buildSection(
      title: 'Información Personal',
      icon: Icons.person_outline_rounded,
      iconColor: AppColors.secondaryStart,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildTextField(
              controller: _nameController,
              label: 'Nombre completo',
              icon: Icons.badge_outlined,
              validator: (v) => v?.isEmpty == true ? 'Ingresa tu nombre' : null,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _phoneController,
              label: 'Teléfono',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryStart,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Guardar cambios', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryStart, width: 2),
        ),
        filled: true,
        fillColor: AppColors.surface,
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
          const Divider(height: 1),
          _buildInfoTile(Icons.admin_panel_settings_outlined, 'Rol', user.role),
          const Divider(height: 1),
          _buildInfoTile(Icons.location_city_outlined, 'Zona', 'Por asignar'),
          const Divider(height: 1),
          _buildInfoTile(Icons.supervisor_account_outlined, 'Supervisor', 'Por asignar'),
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
            icon: Icons.lock_outline_rounded,
            title: 'Cambiar contraseña',
            subtitle: 'Actualiza tu contraseña de acceso',
            onTap: _showChangePasswordDialog,
          ),
          const Divider(height: 1),
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
              _buildDropdownTile(
                icon: Icons.photo_camera_outlined,
                title: 'Calidad de fotos',
                value: settings.photoQuality,
                items: const ['Alta', 'Media', 'Baja'],
                onChanged: (v) => settings.setPhotoQuality(v!),
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                icon: Icons.notifications_outlined,
                title: 'Notificaciones push',
                value: settings.notificationsEnabled,
                onChanged: (v) => settings.setNotificationsEnabled(v),
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                icon: Icons.dark_mode_outlined,
                title: 'Modo oscuro',
                value: settings.darkModeEnabled,
                onChanged: (v) => settings.setDarkModeEnabled(v),
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                icon: Icons.wifi_off_outlined,
                title: 'Modo offline preferido',
                value: settings.offlineModePreferred,
                onChanged: (v) => settings.setOfflineModePreferred(v),
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
          const Divider(height: 1),
          _buildInfoTile(
            Icons.cloud_upload_outlined,
            'Fotos pendientes de sync',
            '$_pendingPhotos fotos',
            valueColor: _pendingPhotos > 0 ? Colors.orange : AppColors.success,
          ),
          const Divider(height: 1),
          _buildActionTile(
            icon: Icons.cleaning_services_outlined,
            title: 'Limpiar caché',
            subtitle: 'Eliminar archivos temporales',
            onTap: _showClearCacheDialog,
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
            icon: Icons.play_circle_outline,
            title: 'Tutorial de uso',
            subtitle: 'Aprende a usar la aplicación',
            onTap: _showTutorial,
          ),
          const Divider(height: 1),
          _buildActionTile(
            icon: Icons.quiz_outlined,
            title: 'Preguntas frecuentes',
            subtitle: 'Resuelve tus dudas',
            onTap: _showFAQ,
          ),
          const Divider(height: 1),
          _buildActionTile(
            icon: Icons.chat_outlined,
            title: 'Contactar soporte',
            subtitle: 'WhatsApp o Email',
            onTap: _showContactOptions,
          ),
          const Divider(height: 1),
          _buildActionTile(
            icon: Icons.bug_report_outlined,
            title: 'Reportar problema',
            subtitle: 'Envía un reporte de errores',
            onTap: _showReportProblem,
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
          _buildInfoTile(Icons.apps, 'Versión', '1.0.0 (Build 1)'),
          const Divider(height: 1),
          _buildActionTile(
            icon: Icons.description_outlined,
            title: 'Términos y condiciones',
            onTap: () => _openUrl('https://metrix.com/terms'),
          ),
          const Divider(height: 1),
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.small,
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
                    color: iconColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
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
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 22),
          const SizedBox(width: 14),
          Text(title, style: const TextStyle(color: AppColors.textSecondary)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: iconColor ?? AppColors.textMuted, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              trailing ?? const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 22),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500))),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primaryStart,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile({
    required IconData icon,
    required String title,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 22),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w500))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: value,
              items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
              onChanged: onChanged,
              underline: const SizedBox(),
              isDense: true,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // Dialog methods
  void _showChangePasswordDialog() {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryStart.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_outline, color: AppColors.primaryStart),
              ),
              const SizedBox(width: 12),
              const Text('Cambiar contraseña'),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: newPasswordController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'Nueva contraseña',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Ingresa la nueva contraseña';
                    if (value.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirmar contraseña',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                  validator: (value) {
                    if (value != newPasswordController.text) return 'Las contraseñas no coinciden';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isLoading = true);
                      try {
                        final user = context.read<AuthProvider>().user;
                        if (user != null) {
                          await _userService.changePassword(user.id, newPasswordController.text);
                        }
                        if (context.mounted) {
                          Navigator.pop(context);
                          _showSuccessSnackBar('Contraseña actualizada');
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryStart,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar'),
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.logout, color: AppColors.error),
            ),
            const SizedBox(width: 12),
            const Text('Cerrar sesión'),
          ],
        ),
        content: const Text('¿Estás seguro que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
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
      ),
    );

    if (confirm == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Limpiar caché'),
        content: const Text('¿Eliminar archivos temporales? Las fotos pendientes de sincronización NO se eliminarán.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Clear cache logic here
              _showSuccessSnackBar('Caché limpiada');
              _loadStorageInfo();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryStart),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }

  void _showTutorial() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Tutorial de uso', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            const Expanded(
              child: Center(child: Text('Tutorial en desarrollo...', style: TextStyle(color: AppColors.textSecondary))),
            ),
          ],
        ),
      ),
    );
  }

  void _showFAQ() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            const Text('Preguntas Frecuentes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _buildFAQItem('¿Cómo tomo una foto?', 'Presiona el botón de cámara en la pantalla principal y apunta hacia el material POP.'),
                  _buildFAQItem('¿Qué pasa si no tengo internet?', 'Las fotos se guardan localmente y se sincronizan automáticamente cuando tengas conexión.'),
                  _buildFAQItem('¿Cómo sé qué tiendas me faltan?', 'En la pantalla principal verás todas las tiendas pendientes con sus campañas asignadas.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return ExpansionTile(
      title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600)),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(answer, style: const TextStyle(color: AppColors.textSecondary)),
        ),
      ],
    );
  }

  void _showContactOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Text('Contactar Soporte', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.green.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.chat, color: Colors.green),
              ),
              title: const Text('WhatsApp'),
              subtitle: const Text('+52 55 1234 5678'),
              onTap: () => _openUrl('https://wa.me/5255123456'),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.withAlpha(20), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.email, color: Colors.blue),
              ),
              title: const Text('Email'),
              subtitle: const Text('soporte@metrix.com'),
              onTap: () => _openUrl('mailto:soporte@metrix.com'),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  void _showReportProblem() {
    final descController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              const Text('Reportar Problema', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Describe el problema que encontraste...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showSuccessSnackBar('Reporte enviado. ¡Gracias!');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryStart,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Enviar reporte', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
