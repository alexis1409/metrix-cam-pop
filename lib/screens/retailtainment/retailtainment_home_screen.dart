import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/retailtainment_provider.dart';
import '../../widgets/offline_banner.dart';
import '../profile/profile_screen.dart';
import 'retailtainment_detail_screen.dart';
import 'retailtainment_tiendas_screen.dart';

class RetailtainmentHomeScreen extends StatefulWidget {
  const RetailtainmentHomeScreen({super.key});

  @override
  State<RetailtainmentHomeScreen> createState() => _RetailtainmentHomeScreenState();
}

class _RetailtainmentHomeScreenState extends State<RetailtainmentHomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeProvider();
  }

  void _initializeProvider() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user != null) {
      final provider = context.read<RetailtainmentProvider>();
      provider.setUser(user);

      // Load assigned stores from API
      if (user.hasRetailtainmentRole) {
        await provider.loadTiendasAsignadas(user.id);
      }

      provider.loadCampanias(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isImpulsador = user?.isImpulsador ?? false;

    final screens = [
      const _RetailtainmentCampaniasTab(),
      const RetailtainmentTiendasScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: screens,
            ),
          ),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: _buildModernNavBar(isImpulsador),
    );
  }

  Widget _buildModernNavBar(bool isImpulsador) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(230),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withAlpha(20),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(
                color: Colors.white.withAlpha(200),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  index: 0,
                  icon: Icons.campaign_outlined,
                  activeIcon: Icons.campaign_rounded,
                  label: 'Campañas',
                ),
                _buildNavItem(
                  index: 1,
                  icon: Icons.store_outlined,
                  activeIcon: Icons.store_rounded,
                  label: isImpulsador ? 'Mi Tienda' : 'Tiendas',
                ),
                _buildNavItem(
                  index: 2,
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Perfil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isActive = _currentIndex == index;
    const primaryColor = Color(0xFF6366F1);

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? primaryColor.withAlpha(15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey(isActive),
                color: isActive ? primaryColor : AppColors.textMuted,
                size: 26,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? primaryColor : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Embedded campaigns tab (reuses RetailtainmentListScreen content but without back button)
class _RetailtainmentCampaniasTab extends StatefulWidget {
  const _RetailtainmentCampaniasTab();

  @override
  State<_RetailtainmentCampaniasTab> createState() => _RetailtainmentCampaniasTabState();
}

class _RetailtainmentCampaniasTabState extends State<_RetailtainmentCampaniasTab> {
  Future<void> _loadCampanias() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user != null) {
      final provider = context.read<RetailtainmentProvider>();
      await provider.loadCampanias(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadCampanias,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(child: _buildHeader()),
            _buildCampaniasList(),
            // Bottom padding for nav bar
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final provider = context.watch<RetailtainmentProvider>();

    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      actions: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppShadows.small,
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
              onPressed: _loadCampanias,
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 60, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Role badge
                  if (provider.hasRetailtainmentRole)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            provider.isImpulsador
                                ? Icons.person_rounded
                                : Icons.supervisor_account_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            provider.roleName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          if (provider.agencia != null && provider.agencia!.nombre.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• ${provider.agencia!.nombre}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withAlpha(200),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  Text(
                    'Retailtainment',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withAlpha(40),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Campañas de demostración y canje',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withAlpha(200),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<RetailtainmentProvider>(
      builder: (context, provider, _) {
        final activasHoy = provider.campaniasActivasHoy.length;
        final total = provider.campanias.length;

        return Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppShadows.small,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$activasHoy activas hoy',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '$total campañas en total',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCampaniasList() {
    return Consumer<RetailtainmentProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (provider.status == RetailtainmentStatus.error) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(provider.errorMessage ?? 'Error desconocido'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadCampanias,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        final campanias = provider.campanias;

        if (campanias.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay campañas asignadas',
                    style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _CampaniaCard(campania: campanias[index]),
              childCount: campanias.length,
            ),
          ),
        );
      },
    );
  }
}

/// Campaign card widget
class _CampaniaCard extends StatelessWidget {
  final dynamic campania;

  const _CampaniaCard({required this.campania});

  @override
  Widget build(BuildContext context) {
    final isActiveToday = campania.esDiaActivoHoy;
    final tipoColor = _getTipoColor(campania.tipoRetailtainment);
    final tipoIcon = _getTipoIcon(campania.tipoRetailtainment);
    final tipoLabel = _getTipoLabel(campania.tipoRetailtainment);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.small,
        border: isActiveToday
            ? Border.all(color: Colors.green.withAlpha(100), width: 2)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openCampaniaDetail(context),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: tipoColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(tipoIcon, color: tipoColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            campania.nombre,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: tipoColor.withAlpha(20),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tipoLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: tipoColor,
                                  ),
                                ),
                              ),
                              if (isActiveToday) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withAlpha(20),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, size: 12, color: Colors.green),
                                      SizedBox(width: 4),
                                      Text(
                                        'Activa hoy',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 6),
                    Text(
                      '${_formatDate(campania.fechaInicio)} - ${_formatDate(campania.fechaFin)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const Spacer(),
                    if (campania.marca != null)
                      Text(
                        campania.marca!.nombre,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openCampaniaDetail(BuildContext context) {
    context.read<RetailtainmentProvider>().selectCampania(campania);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RetailtainmentDetailScreen(campania: campania),
      ),
    );
  }

  Color _getTipoColor(String? tipo) {
    switch (tipo) {
      case 'demostracion':
        return Colors.blue;
      case 'canje_compra':
        return Colors.green;
      case 'canje_dinamica':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getTipoIcon(String? tipo) {
    switch (tipo) {
      case 'demostracion':
        return Icons.present_to_all_rounded;
      case 'canje_compra':
        return Icons.receipt_long_rounded;
      case 'canje_dinamica':
        return Icons.casino_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  String _getTipoLabel(String? tipo) {
    switch (tipo) {
      case 'demostracion':
        return 'Demostración';
      case 'canje_compra':
        return 'Canje por Compra';
      case 'canje_dinamica':
        return 'Canje con Dinámica';
      default:
        return 'Retailtainment';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
