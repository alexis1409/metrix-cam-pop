import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/asignacion_rtmt.dart';
import '../../providers/demostrador_provider.dart';
import '../../providers/auth_provider.dart';
import 'demostrador_detail_screen.dart';

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
      backgroundColor: const Color(0xFFF8FAFC),
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

            // Separate active and completed
            final asignacionesActivas = provider.asignacionesHoy
                .where((a) =>
                    a.estado == EstadoAsignacion.pendiente ||
                    a.estado == EstadoAsignacion.enProgreso ||
                    a.estado == EstadoAsignacion.incidencia)
                .toList();
            final asignacionesTerminadas = provider.asignacionesHoy
                .where((a) => a.estado == EstadoAsignacion.completada)
                .toList();

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
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatFechaHoy(),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
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
                            bottom: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          labelColor: Colors.blue[600],
                          unselectedLabelColor: Colors.grey[500],
                          indicatorColor: Colors.blue[600],
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
                        _buildAsignacionesList(asignacionesActivas, true),
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
          backgroundColor: Colors.blue[600],
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: hasIncidencia
            ? const Border(
                left: BorderSide(color: Colors.orange, width: 4),
              )
            : null,
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

              // Incidence bar
              if (hasIncidencia)
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DemostradorDetailScreen(),
      ),
    );
  }
}
