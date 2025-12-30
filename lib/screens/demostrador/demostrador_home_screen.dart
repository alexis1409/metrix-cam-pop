import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/asignacion_rtmt.dart';
import '../../providers/demostrador_provider.dart';
import '../../providers/auth_provider.dart';
import 'demostrador_detail_screen.dart';

class DemostradorHomeScreen extends StatefulWidget {
  const DemostradorHomeScreen({super.key});

  @override
  State<DemostradorHomeScreen> createState() => _DemostradorHomeScreenState();
}

class _DemostradorHomeScreenState extends State<DemostradorHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _filterEstado;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
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
    return formatter.format(hoy);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final userName = authProvider.user?.name?.split(' ').first ?? 'Demostrador';

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

            // Calcular estadísticas
            final total = provider.asignacionesHoy.length;
            final pendientes = provider.asignacionesHoy
                .where((a) => a.estado == EstadoAsignacion.pendiente)
                .length;
            final enProgreso = provider.asignacionesHoy
                .where((a) => a.estado == EstadoAsignacion.enProgreso)
                .length;
            final completadas = provider.asignacionesHoy
                .where((a) => a.estado == EstadoAsignacion.completada)
                .length;

            // Filtrar asignaciones
            List<AsignacionRTMT> asignacionesFiltradas = provider.asignacionesHoy;
            if (_filterEstado != null) {
              asignacionesFiltradas = asignacionesFiltradas.where((a) {
                switch (_filterEstado) {
                  case 'pendiente':
                    return a.estado == EstadoAsignacion.pendiente;
                  case 'en_progreso':
                    return a.estado == EstadoAsignacion.enProgreso;
                  case 'completada':
                    return a.estado == EstadoAsignacion.completada;
                  default:
                    return true;
                }
              }).toList();
            }

            // Separar activas y terminadas
            final asignacionesActivas = asignacionesFiltradas
                .where((a) =>
                    a.estado == EstadoAsignacion.pendiente ||
                    a.estado == EstadoAsignacion.enProgreso ||
                    a.estado == EstadoAsignacion.incidencia)
                .toList();
            final asignacionesTerminadas = asignacionesFiltradas
                .where((a) => a.estado == EstadoAsignacion.completada)
                .toList();

            return RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  // Header con saludo
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

                  // Stats Cards
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Row(
                        children: [
                          _buildStatCard(
                            value: total.toString(),
                            label: 'Total',
                            isSelected: _filterEstado == null,
                            onTap: () => setState(() => _filterEstado = null),
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          _buildStatCard(
                            value: pendientes.toString(),
                            label: 'Pendientes',
                            isSelected: _filterEstado == 'pendiente',
                            onTap: () => setState(() {
                              _filterEstado = _filterEstado == 'pendiente' ? null : 'pendiente';
                            }),
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          _buildStatCard(
                            value: enProgreso.toString(),
                            label: 'En Progreso',
                            isSelected: _filterEstado == 'en_progreso',
                            onTap: () => setState(() {
                              _filterEstado = _filterEstado == 'en_progreso' ? null : 'en_progreso';
                            }),
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          _buildStatCard(
                            value: completadas.toString(),
                            label: 'Terminadas',
                            isSelected: _filterEstado == 'completada',
                            onTap: () => setState(() {
                              _filterEstado = _filterEstado == 'completada' ? null : 'completada';
                            }),
                            color: Colors.green,
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
      floatingActionButton: FloatingActionButton(
        onPressed: _loadData,
        backgroundColor: Colors.blue[600],
        child: const Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  Widget _buildStatCard({
    required String value,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(color: color, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color == Colors.grey ? Colors.grey[600] : color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
      padding: const EdgeInsets.all(16),
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
                    // Imagen de la campaña
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

                    // Info principal
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nombre campaña + indicadores
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
                              // Indicadores de momentos
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

                          // Tienda
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

                          // Fecha y hora
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

                          // Dirección
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

                    // Flecha
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

              // Barra de incidencia
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
