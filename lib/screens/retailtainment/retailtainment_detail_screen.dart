import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/campania.dart';
import '../../providers/retailtainment_provider.dart';
import 'registro_demostracion_screen.dart';
import 'registro_canje_compra_screen.dart';
import 'registro_dinamica_screen.dart';

class RetailtainmentDetailScreen extends StatelessWidget {
  final Campania campania;

  const RetailtainmentDetailScreen({
    super.key,
    required this.campania,
  });

  @override
  Widget build(BuildContext context) {
    final isActiveToday = campania.esDiaActivoHoy;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(child: _buildCampaignInfo(context)),
          if (!isActiveToday)
            SliverToBoxAdapter(child: _buildInactiveDayWarning()),
          SliverToBoxAdapter(child: _buildDiasActivos()),
          if (campania.tipoRetailtainment == 'canje_compra')
            SliverToBoxAdapter(child: _buildRangosInfo(context)),
          if (campania.tipoRetailtainment == 'canje_dinamica')
            SliverToBoxAdapter(child: _buildDinamicasInfo()),
          if (campania.upcs.isNotEmpty)
            SliverToBoxAdapter(child: _buildUpcsInfo()),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: isActiveToday ? _buildFab(context) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final tipoColor = _getTipoColor();

    return SliverAppBar(
      expandedHeight: 140,
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
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [tipoColor, tipoColor.withAlpha(180)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(60, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _getTipoLabel(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    campania.nombre,
                    style: TextStyle(
                      fontSize: 24,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCampaignInfo(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getTipoColor().withAlpha(20),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_getTipoIcon(), color: _getTipoColor(), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (campania.marca != null)
                      Text(
                        campania.marca!.nombre,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    Text(
                      '#${campania.codigo}',
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
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 18, color: Colors.grey.shade600),
                const SizedBox(width: 10),
                Text(
                  '${_formatDate(campania.fechaInicio)} - ${_formatDate(campania.fechaFin)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          if (campania.notas != null && campania.notas!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              campania.notas!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInactiveDayWarning() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Campaña no activa hoy',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'No puedes registrar actividades en este día',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiasActivos() {
    const diasLabels = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
    final diasActivos = campania.diasActivos.isEmpty
        ? List.generate(7, (i) => i) // All days if empty
        : campania.diasActivos;
    final hoy = DateTime.now().weekday % 7;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.date_range_rounded, color: AppColors.textMuted, size: 20),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Días activos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Días en que se puede registrar actividad',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(7, (index) {
              final isActive = diasActivos.contains(index);
              final isToday = index == hoy;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? (isToday ? Colors.green.withAlpha(20) : _getTipoColor().withAlpha(15))
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                  border: isToday
                      ? Border.all(color: Colors.green, width: 2)
                      : (isActive ? Border.all(color: _getTipoColor().withAlpha(50)) : null),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isToday)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.today, size: 14, color: Colors.green),
                      ),
                    Text(
                      diasLabels[index],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        color: isActive
                            ? (isToday ? Colors.green : _getTipoColor())
                            : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildRangosInfo(BuildContext context) {
    final config = campania.configCanje.isNotEmpty ? campania.configCanje.first : null;
    if (config == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.card_giftcard_rounded, color: Colors.green, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rangos de premios',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      config.paisNombre.isNotEmpty ? config.paisNombre : 'Configuración',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  config.simboloMoneda,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...config.rangos.map((rango) => _buildRangoCard(rango, config.simboloMoneda)),
        ],
      ),
    );
  }

  Widget _buildRangoCard(RangoPremio rango, String simbolo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rango.getRangoLabel(simbolo),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ...rango.premios.map((premio) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.redeem, size: 16, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  '${premio.cantidad}x ${premio.nombre}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildDinamicasInfo() {
    if (campania.configDinamica.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.casino_rounded, color: Colors.purple, size: 20),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dinámicas disponibles',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Juegos y actividades para el cliente',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...campania.configDinamica.asMap().entries.map((entry) =>
              _buildDinamicaCard(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildDinamicaCard(int index, ConfigDinamica dinamica) {
    final color = _getDinamicaColor(dinamica.tipoRecompensa);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getDinamicaIcon(dinamica.tipoRecompensa), size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dinamica.nombre,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (dinamica.descripcion.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              dinamica.descripcion,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stars_rounded, size: 14, color: Colors.amber),
                const SizedBox(width: 6),
                Text(
                  'Premio: ${dinamica.recompensa}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcsInfo() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.textMuted, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Productos participantes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${campania.upcs.length} UPCs registrados',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...campania.upcs.take(5).map((upc) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        upc.descripcion,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        upc.codigo,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
          if (campania.upcs.length > 5)
            Center(
              child: Text(
                '+${campania.upcs.length - 5} más',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: FloatingActionButton.extended(
          onPressed: () => _startRegistro(context),
          backgroundColor: _getTipoColor(),
          elevation: 4,
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            _getFabLabel(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  void _startRegistro(BuildContext context) {
    // First select a store
    final provider = context.read<RetailtainmentProvider>();
    final tiendas = provider.tiendasDisponibles;

    if (tiendas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.hasRetailtainmentRole
                ? 'No tienes tiendas asignadas para esta campaña'
                : 'No hay tiendas disponibles para esta campaña',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // For impulsador with only one store, skip the selection modal
    if (provider.isImpulsador && tiendas.length == 1) {
      _navigateToRegistro(context, tiendas.first);
      return;
    }

    _showTiendaSelector(context, tiendas, provider);
  }

  void _showTiendaSelector(BuildContext context, List<Tienda> tiendas, RetailtainmentProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selecciona tienda',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${tiendas.length} tiendas ${provider.hasRetailtainmentRole ? 'asignadas' : 'disponibles'}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Role badge
                      if (provider.hasRetailtainmentRole)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: provider.isImpulsador
                                  ? [const Color(0xFF10B981), const Color(0xFF059669)]
                                  : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                provider.isImpulsador ? Icons.person_rounded : Icons.supervisor_account_rounded,
                                color: Colors.white,
                                size: 16,
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
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: tiendas.length,
                itemBuilder: (ctx, index) {
                  final tienda = tiendas[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _getTipoColor().withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.store_rounded, color: _getTipoColor()),
                      ),
                      title: Text(
                        tienda.nombre,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('#${tienda.determinante} - ${tienda.ciudad}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.pop(ctx);
                        _navigateToRegistro(context, tienda);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToRegistro(BuildContext context, Tienda tienda) {
    context.read<RetailtainmentProvider>().selectTienda(tienda);

    Widget screen;
    switch (campania.tipoRetailtainment) {
      case 'demostracion':
        screen = RegistroDemostracionScreen(campania: campania, tienda: tienda);
        break;
      case 'canje_compra':
        screen = RegistroCanjeCompraScreen(campania: campania, tienda: tienda);
        break;
      case 'canje_dinamica':
        screen = RegistroDinamicaScreen(campania: campania, tienda: tienda);
        break;
      default:
        screen = RegistroDemostracionScreen(campania: campania, tienda: tienda);
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Color _getTipoColor() {
    switch (campania.tipoRetailtainment) {
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

  IconData _getTipoIcon() {
    switch (campania.tipoRetailtainment) {
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

  String _getTipoLabel() {
    switch (campania.tipoRetailtainment) {
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

  String _getFabLabel() {
    switch (campania.tipoRetailtainment) {
      case 'demostracion':
        return 'Registrar Demostración';
      case 'canje_compra':
        return 'Registrar Canje';
      case 'canje_dinamica':
        return 'Iniciar Dinámica';
      default:
        return 'Iniciar Registro';
    }
  }

  Color _getDinamicaColor(String tipo) {
    switch (tipo) {
      case 'producto':
        return Colors.green;
      case 'descuento':
        return Colors.orange;
      default:
        return Colors.purple;
    }
  }

  IconData _getDinamicaIcon(String tipo) {
    switch (tipo) {
      case 'producto':
        return Icons.card_giftcard_rounded;
      case 'descuento':
        return Icons.discount_rounded;
      default:
        return Icons.stars_rounded;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
