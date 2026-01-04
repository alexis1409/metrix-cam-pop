import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/asignacion_rtmt.dart';
import '../../providers/demostrador_provider.dart';
import '../../providers/auth_provider.dart';
import 'demostrador_detail_screen.dart';
import 'asignacion_resumen_screen.dart';

/// Content widget for Demostrador Home - to be used inside a tab/indexed stack
class DemostradorHomeContent extends StatefulWidget {
  const DemostradorHomeContent({super.key});

  @override
  State<DemostradorHomeContent> createState() => _DemostradorHomeContentState();
}

class _DemostradorHomeContentState extends State<DemostradorHomeContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final provider = context.read<DemostradorProvider>();
    final authProvider = context.read<AuthProvider>();

    if (authProvider.user != null) {
      provider.setUser(authProvider.user);
    }

    await provider.loadAsignacionesHoy();
  }

  String _formatFechaHoy() {
    final hoy = DateTime.now();
    final formatter = DateFormat("EEEE, d 'de' MMMM 'de' yyyy", 'es_MX');
    final formatted = formatter.format(hoy);
    // Capitalize first letter
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userName = authProvider.user?.name.split(' ').first ?? 'Demostrador';

    return Scaffold(
      backgroundColor: context.backgroundColor,
      body: SafeArea(
        child: Consumer<DemostradorProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (provider.errorMessage != null) {
              return _buildErrorState(provider.errorMessage!);
            }

            // Separar activas, próximas y terminadas
            // Activas: solo asignaciones de HOY
            final asignacionesActivas = provider.asignacionesHoy
                .where((a) => a.estaActiva)
                .toList();
            // Próximas: asignaciones de días FUTUROS
            final asignacionesProximas = provider.asignacionesHoy
                .where((a) => a.esProxima)
                .toList()
              ..sort((a, b) {
                // Ordenar por fecha ascendente
                final fechaA = a.actividad?.fechaDate;
                final fechaB = b.actividad?.fechaDate;
                if (fechaA == null && fechaB == null) return 0;
                if (fechaA == null) return 1;
                if (fechaB == null) return -1;
                return fechaA.compareTo(fechaB);
              });
            // Terminadas: solo asignaciones de dias PASADOS
            // Ordenadas por fecha descendente (más reciente primero)
            final asignacionesTerminadas = provider.asignacionesHoy
                .where((a) => a.estaTerminada)
                .toList()
              ..sort((a, b) {
                // Ordenar por fecha descendente (más reciente primero)
                final fechaA = a.actividad?.fechaDate;
                final fechaB = b.actividad?.fechaDate;
                if (fechaA == null && fechaB == null) return 0;
                if (fechaA == null) return 1;
                if (fechaB == null) return -1;
                return fechaB.compareTo(fechaA); // Descendente
              });

            return RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // Header with greeting
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '¡Hola, $userName!',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: context.textPrimaryColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatFechaHoy(),
                            style: TextStyle(
                              fontSize: 14,
                              color: context.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Tabs
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: context.borderColor),
                          ),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          labelColor: AppColors.primaryStart,
                          unselectedLabelColor: context.textMutedColor,
                          indicatorColor: AppColors.primaryStart,
                          indicatorWeight: 2,
                          labelStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          tabs: [
                            Tab(text: 'Activas (${asignacionesActivas.length})'),
                            Tab(text: 'Terminadas (${asignacionesTerminadas.length})'),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Content based on tab
                  SliverFillRemaining(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildActivasConProximas(asignacionesActivas, asignacionesProximas),
                        _buildAsignacionesList(asignacionesTerminadas, false),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: FloatingActionButton(
          onPressed: _loadData,
          backgroundColor: AppColors.primaryStart,
          child: const Icon(Icons.refresh, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red[700]),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  /// Construye la lista de activas con sección de próximas
  Widget _buildActivasConProximas(
    List<AsignacionRTMT> activas,
    List<AsignacionRTMT> proximas,
  ) {
    if (activas.isEmpty && proximas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📋', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text(
              'Sin actividades',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No tienes actividades pendientes',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        // Sección: Activas (hoy)
        if (activas.isNotEmpty) ...[
          ...activas.map((a) => _buildAsignacionCard(a)),
        ] else ...[
          // Mensaje si no hay activas hoy
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[400]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No tienes actividades para hoy',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Sección: Próximas
        if (proximas.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.schedule, color: Colors.orange[700], size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Próximas (${proximas.length})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          ...proximas.map((a) => _buildAsignacionCardProxima(a)),
        ],
      ],
    );
  }

  Widget _buildAsignacionesList(List<AsignacionRTMT> asignaciones, bool isActive) {
    if (asignaciones.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isActive ? '📋' : '✅',
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 16),
            Text(
              isActive ? 'Sin actividades activas' : 'Sin actividades terminadas',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isActive
                  ? 'No tienes actividades pendientes para hoy'
                  : 'Aún no has completado ninguna actividad',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120), // Extra bottom padding for nav bar
      itemCount: asignaciones.length,
      itemBuilder: (context, index) {
        final asignacion = asignaciones[index];
        return _buildAsignacionCard(asignacion);
      },
    );
  }

  Widget _buildAsignacionCard(AsignacionRTMT asignacion) {
    final hasIncidencia = asignacion.tieneIncidencias;
    // Verificar si es de un dia pasado y no se completo
    final noCompletadaYPaso = asignacion.esDeDiaPasado &&
        asignacion.estado != EstadoAsignacion.completada;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: noCompletadaYPaso ? Colors.red[50] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: noCompletadaYPaso
            ? const Border(
                left: BorderSide(color: Colors.red, width: 4),
              )
            : (hasIncidencia
                ? const Border(
                    left: BorderSide(color: Colors.orange, width: 4),
                  )
                : null),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToDetail(asignacion),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Campaign image
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: asignacion.camp?.medioIcono != null &&
                                asignacion.camp!.medioIcono!.isNotEmpty
                            ? Image.network(
                                asignacion.camp!.medioIcono!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Text('🎯', style: TextStyle(fontSize: 28)),
                                  );
                                },
                              )
                            : const Center(
                                child: Text('🎯', style: TextStyle(fontSize: 28)),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Main info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Campaign name + indicators
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  asignacion.nombreCampana,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F2937),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Moment indicators
                              Row(
                                children: [
                                  _buildMomentoDot(asignacion.inicioActividades),
                                  const SizedBox(width: 2),
                                  _buildMomentoDot(asignacion.laborVenta),
                                  const SizedBox(width: 2),
                                  _buildMomentoDot(asignacion.cierreActividades),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Store
                          Text(
                            '(${asignacion.tienda.determinante}) ${asignacion.nombreTienda}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),

                          // Date and time
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                asignacion.fechaFormateada,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                              if (asignacion.horaFormateada.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  asignacion.horaFormateada,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ],
                          ),

                          // Address
                          if (asignacion.tienda.direccionCompleta.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    asignacion.tienda.direccionCompleta,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[400],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Arrow
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.chevron_right,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),

              // Status bar (no completada o incidencia)
              if (noCompletadaYPaso)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border(
                      top: BorderSide(color: Colors.red[200]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cancel_outlined, size: 16, color: Colors.red[700]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'No completada - Turno finalizado',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (hasIncidencia)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border(
                      top: BorderSide(color: Colors.orange[100]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 6),
                      Text(
                        'Tienes una incidencia por corregir',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Card para asignaciones próximas (días futuros)
  Widget _buildAsignacionCardProxima(AsignacionRTMT asignacion) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Solo mostrar info, no navegar ya que es futura
            _showProximaInfo(asignacion);
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Icono de campaña
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: asignacion.camp?.medioIcono != null
                            ? Image.network(
                                asignacion.camp!.medioIcono!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Icon(Icons.schedule, color: Colors.orange[400]),
                                ),
                              )
                            : Center(
                                child: Icon(Icons.schedule, color: Colors.orange[400]),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            asignacion.nombreCampana,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2937),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            asignacion.nombreTienda,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Fecha y hora
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: Colors.orange[700]),
                    const SizedBox(width: 6),
                    Text(
                      asignacion.fechaFormateada,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[700],
                      ),
                    ),
                    if (asignacion.horaFormateada.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      Icon(Icons.access_time, size: 14, color: Colors.orange[700]),
                      const SizedBox(width: 6),
                      Text(
                        asignacion.horaFormateada,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Próxima',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProximaInfo(AsignacionRTMT asignacion) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.schedule, color: Colors.orange[600], size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Actividad Programada',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Próxima asignación',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildInfoRow(Icons.campaign, 'Campaña', asignacion.nombreCampana),
            _buildInfoRow(Icons.store, 'Tienda', asignacion.nombreTienda),
            _buildInfoRow(Icons.calendar_today, 'Fecha', asignacion.fechaFormateada),
            if (asignacion.horaFormateada.isNotEmpty)
              _buildInfoRow(Icons.access_time, 'Hora', asignacion.horaFormateada),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Esta actividad estará disponible el día programado.',
                      style: TextStyle(color: Colors.blue[700], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(color: Colors.grey[600]),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMomentoDot(RegistroMomento registro) {
    Color color;
    if (registro.incidencia) {
      color = Colors.orange;
    } else if (registro.completada) {
      color = Colors.green;
    } else {
      color = Colors.grey[300]!;
    }

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  void _navigateToDetail(AsignacionRTMT asignacion) {
    final provider = context.read<DemostradorProvider>();
    provider.selectAsignacion(asignacion);

    // Si es de un día pasado, ir a pantalla de resumen (solo lectura)
    // Si es de hoy, ir a pantalla de detalle (permite acciones)
    if (asignacion.esDeDiaPasado) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const AsignacionResumenScreen(),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const DemostradorDetailScreen(),
        ),
      );
    }
  }
}
