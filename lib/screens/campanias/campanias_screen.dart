import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/tienda_pendiente.dart';
import '../../providers/auth_provider.dart';
import '../../providers/campania_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/notification_provider.dart';

class CampaniasScreen extends StatefulWidget {
  const CampaniasScreen({super.key});

  @override
  State<CampaniasScreen> createState() => _CampaniasScreenState();
}

class _CampaniasScreenState extends State<CampaniasScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      _loadData();
    });
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!mounted) return;

    context.read<LocationProvider>().initLocation();

    final user = context.read<AuthProvider>().user;
    if (user != null) {
      await context.read<CampaniaProvider>().loadTiendasPendientes(
        user.id,
        forceRefresh: forceRefresh,
      );
    }
  }

  Future<void> _forceRefresh() async {
    await _loadData(forceRefresh: true);
  }

  String _formatCacheTime(DateTime? cacheTime) {
    if (cacheTime == null) return '';
    final now = DateTime.now();
    final diff = now.difference(cacheTime);
    if (diff.inMinutes < 1) return 'hace un momento';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    return 'hace ${diff.inDays} días';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Groups TiendaPendiente items by tienda.id and returns a map
  Map<String, List<TiendaPendiente>> _groupTiendasById(List<TiendaPendiente> tiendas) {
    final Map<String, List<TiendaPendiente>> grouped = {};
    for (final t in tiendas) {
      final key = t.tienda.id;
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(t);
    }
    return grouped;
  }

  List<MapEntry<String, List<TiendaPendiente>>> _filterTiendas(List<TiendaPendiente> tiendas) {
    final grouped = _groupTiendasById(tiendas);

    if (_searchQuery.isEmpty) {
      return grouped.entries.toList();
    }

    final query = _searchQuery.toLowerCase();
    return grouped.entries.where((entry) {
      final t = entry.value.first.tienda;
      return t.nombre.toLowerCase().contains(query) ||
             t.determinante.toLowerCase().contains(query) ||
             t.ciudad.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(child: _buildStoreList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  final nombre = auth.user?.name ?? 'Usuario';
                  return Text(
                    'Hola, $nombre',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              const Text(
                'Mis Tiendas',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Only show Retailtainment button for users who can access it
              if (context.watch<AuthProvider>().user?.canSeeRetailtainment ?? false) ...[
                _buildRetailtainmentButton(),
                const SizedBox(width: 8),
              ],
              _buildHeaderButton(
                icon: Icons.refresh_rounded,
                onTap: _forceRefresh,
              ),
              const SizedBox(width: 8),
              _buildNotificationButton(),
              const SizedBox(width: 8),
              _buildHeaderButton(
                icon: Icons.person_outline_rounded,
                onTap: () => Navigator.pushNamed(context, '/profile'),
                isGradient: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isGradient = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: isGradient ? AppColors.primaryGradient : null,
          color: isGradient ? null : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.small,
        ),
        child: Icon(
          icon,
          color: isGradient ? Colors.white : AppColors.textSecondary,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildRetailtainmentButton() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/retailtainment'),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withAlpha(60),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.storefront_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildNotificationButton() {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, _) {
        final unreadCount = notificationProvider.unreadCount;

        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/notifications'),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppShadows.small,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Center(
                  child: Icon(
                    Icons.notifications_outlined,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 16),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppShadows.small,
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Buscar tienda o determinante...',
            hintStyle: const TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 16, right: 12),
              child: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 22),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 50),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                    ),
                  )
                : null,
            filled: true,
            fillColor: Colors.transparent,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildStoreList() {
    return Consumer<CampaniaProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppShadows.medium,
                  ),
                  child: const CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(AppColors.primaryStart),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Cargando tiendas...',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        if (provider.status == CampaniaStatus.error) {
          return _buildErrorState(provider.errorMessage);
        }

        final groupedTiendas = _filterTiendas(provider.tiendasPendientes);

        if (provider.tiendasPendientes.isEmpty) {
          return _buildEmptyState();
        }

        if (groupedTiendas.isEmpty) {
          return _buildNoResultsState();
        }

        return RefreshIndicator(
          onRefresh: _forceRefresh,
          color: AppColors.primaryStart,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 120),
            itemCount: groupedTiendas.length + (provider.isUsingCachedData ? 1 : 0),
            itemBuilder: (context, index) {
              // Show cache indicator as first item
              if (provider.isUsingCachedData && index == 0) {
                return _buildCacheIndicator(provider.cacheTime);
              }

              final adjustedIndex = provider.isUsingCachedData ? index - 1 : index;
              final entry = groupedTiendas[adjustedIndex];
              final campanias = entry.value;
              final firstTienda = campanias.first;
              return _ModernTiendaCard(
                tienda: firstTienda,
                campaniaCount: campanias.length,
                index: adjustedIndex,
                onTap: () {
                  provider.selectTienda(firstTienda);
                  Navigator.pushNamed(
                    context,
                    '/tienda-campanias',
                    arguments: campanias, // Pass all campaigns for this store
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildErrorState(String? message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Error de conexión',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'No se pudieron cargar las tiendas',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _loadData,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppShadows.colored(AppColors.primaryStart),
                ),
                child: const Text(
                  'Reintentar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.success.withAlpha(20),
                    AppColors.success.withAlpha(10),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 48,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Todo al día',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No tienes tiendas pendientes por visitar',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 48,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sin resultados',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No se encontraron tiendas para "$_searchQuery"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheIndicator(DateTime? cacheTime) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withAlpha(40)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.history_rounded,
            size: 18,
            color: Colors.orange.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Datos guardados ${_formatCacheTime(cacheTime)}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.orange.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          GestureDetector(
            onTap: _forceRefresh,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade600,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Actualizar',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernTiendaCard extends StatelessWidget {
  final TiendaPendiente tienda;
  final int campaniaCount;
  final int index;
  final VoidCallback onTap;

  const _ModernTiendaCard({
    required this.tienda,
    required this.campaniaCount,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.small,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                _buildStoreIcon(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDeterminante(),
                      const SizedBox(height: 6),
                      _buildNombre(),
                      const SizedBox(height: 6),
                      _buildDireccion(),
                    ],
                  ),
                ),
                _buildArrow(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoreIcon() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: AppColors.secondaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondaryStart.withAlpha(40),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.store_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
        if (campaniaCount > 1)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                '$campaniaCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDeterminante() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryStart.withAlpha(12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '#${tienda.tienda.determinante}',
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.primaryStart,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildNombre() {
    return Text(
      tienda.tienda.nombre,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildDireccion() {
    return Row(
      children: [
        const Icon(
          Icons.location_on_outlined,
          size: 14,
          color: AppColors.textMuted,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '${tienda.tienda.direccion}, ${tienda.tienda.ciudad}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildArrow() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.arrow_forward_ios_rounded,
        color: AppColors.textMuted,
        size: 16,
      ),
    );
  }
}
