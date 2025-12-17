import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/campania.dart';
import '../../providers/auth_provider.dart';
import '../../providers/retailtainment_provider.dart';
import 'retailtainment_detail_screen.dart';

class RetailtainmentListScreen extends StatefulWidget {
  const RetailtainmentListScreen({super.key});

  @override
  State<RetailtainmentListScreen> createState() => _RetailtainmentListScreenState();
}

class _RetailtainmentListScreenState extends State<RetailtainmentListScreen> {
  @override
  void initState() {
    super.initState();
    _loadCampanias();
  }

  void _loadCampanias() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.user;
    if (user != null) {
      final provider = context.read<RetailtainmentProvider>();
      provider.setUser(user); // Set user for role-based filtering

      // Load assigned stores from API for impulsador/supervisor
      if (user.hasRetailtainmentRole) {
        await provider.loadTiendasAsignadas(user.id);
      }

      provider.loadCampanias(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildHeader()),
          _buildCampaniasList(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppShadows.small,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
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
              padding: const EdgeInsets.fromLTRB(60, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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

        return Column(
          children: [
            // Role badge for Impulsador/Supervisor
            if (provider.hasRetailtainmentRole)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: provider.isImpulsador
                        ? [const Color(0xFF10B981), const Color(0xFF059669)]
                        : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppShadows.small,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        provider.isImpulsador ? Icons.person_rounded : Icons.supervisor_account_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.roleName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          if (provider.agencia != null)
                            Text(
                              provider.agencia!.nombre.isNotEmpty
                                  ? provider.agencia!.nombre
                                  : 'Agencia asignada',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withAlpha(200),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        provider.isImpulsador
                            ? '1 tienda'
                            : '${provider.tiendasAsignadas.length} tiendas',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Stats card
            Container(
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
            ),
          ],
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
                    'No hay campañas de retailtainment',
                    style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildCampaniaCard(campanias[index]),
              childCount: campanias.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCampaniaCard(Campania campania) {
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
          onTap: () => _openCampaniaDetail(campania),
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
                if (campania.diasActivos.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      const Text(
                        'Días activos: ',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      ...campania.diasActivos.map((dia) => _buildDiaChip(dia)),
                    ],
                  ),
                ],
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

  Widget _buildDiaChip(int dia) {
    const dias = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
    final hoy = DateTime.now().weekday % 7;
    final isToday = dia == hoy;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isToday ? Colors.green.withAlpha(30) : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
        border: isToday ? Border.all(color: Colors.green, width: 1) : null,
      ),
      child: Text(
        dias[dia],
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isToday ? Colors.green : AppColors.textSecondary,
        ),
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

  void _openCampaniaDetail(Campania campania) {
    context.read<RetailtainmentProvider>().selectCampania(campania);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RetailtainmentDetailScreen(campania: campania),
      ),
    );
  }
}
