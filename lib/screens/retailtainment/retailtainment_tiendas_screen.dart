import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/campania.dart';
import '../../providers/auth_provider.dart';
import '../../providers/retailtainment_provider.dart';

class RetailtainmentTiendasScreen extends StatefulWidget {
  const RetailtainmentTiendasScreen({super.key});

  @override
  State<RetailtainmentTiendasScreen> createState() => _RetailtainmentTiendasScreenState();
}

class _RetailtainmentTiendasScreenState extends State<RetailtainmentTiendasScreen> {
  Future<void> _loadData() async {
    final user = context.read<AuthProvider>().user;
    if (user != null && user.hasRetailtainmentRole) {
      final provider = context.read<RetailtainmentProvider>();
      await provider.loadTiendasAsignadas(user.id);
      await provider.loadCampanias(user.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final provider = context.watch<RetailtainmentProvider>();
    final isImpulsador = user?.isImpulsador ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(context, isImpulsador, provider),
            if (isImpulsador)
              SliverToBoxAdapter(child: _buildSingleStore(context, provider))
            else
              _buildStoresList(context, provider),
            // Bottom padding for nav bar
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isImpulsador, RetailtainmentProvider provider) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isImpulsador
                  ? [const Color(0xFF10B981), const Color(0xFF059669)]
                  : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    isImpulsador ? 'Mi Tienda' : 'Mis Tiendas',
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
                    isImpulsador
                        ? 'Tienda asignada para actividades'
                        : '${provider.tiendasAsignadas.length} tiendas asignadas',
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

  Widget _buildSingleStore(BuildContext context, RetailtainmentProvider provider) {
    final tienda = provider.tiendasAsignadas.isNotEmpty
        ? provider.tiendasAsignadas.first
        : null;

    if (tienda == null) {
      return Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppShadows.small,
        ),
        child: Column(
          children: [
            Icon(Icons.store_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No tienes tienda asignada',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Contacta a tu supervisor para asignación',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        children: [
          // Store header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.store_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tienda.nombre,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '#${tienda.determinante}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withAlpha(200),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Store details
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildDetailRow(Icons.location_city_rounded, 'Ciudad', tienda.ciudad),
                const SizedBox(height: 16),
                if (tienda.direccion.isNotEmpty)
                  _buildDetailRow(Icons.location_on_rounded, 'Dirección', tienda.direccion),
                const SizedBox(height: 20),

                // Active campaigns for this store
                _buildActiveCampaignsSection(context, tienda),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.textMuted, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveCampaignsSection(BuildContext context, Tienda tienda) {
    final provider = context.watch<RetailtainmentProvider>();
    final activeCampanias = provider.campaniasActivasHoy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.campaign_rounded, color: Color(0xFF6366F1), size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'Campañas activas hoy',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (activeCampanias.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.textMuted, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No hay campañas activas para hoy',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          ...activeCampanias.map((c) => _buildMiniCampaniaCard(c)),
      ],
    );
  }

  Widget _buildMiniCampaniaCard(dynamic campania) {
    final tipoColor = _getTipoColor(campania.tipoRetailtainment);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tipoColor.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tipoColor.withAlpha(30)),
      ),
      child: Row(
        children: [
          Icon(_getTipoIcon(campania.tipoRetailtainment), color: tipoColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              campania.nombre,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tipoColor,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Activa',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoresList(BuildContext context, RetailtainmentProvider provider) {
    final tiendas = provider.tiendasAsignadas;

    if (tiendas.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.store_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'No tienes tiendas asignadas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildStoreCard(tiendas[index]),
          childCount: tiendas.length,
        ),
      ),
    );
  }

  Widget _buildStoreCard(Tienda tienda) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.small,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.store_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tienda.nombre,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '#${tienda.determinante} • ${tienda.ciudad}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ),
        ],
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
}
