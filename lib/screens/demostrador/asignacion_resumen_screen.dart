import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/asignacion_rtmt.dart';
import '../../providers/demostrador_provider.dart';

/// Pantalla de resumen para asignaciones de días pasados (terminadas)
/// Muestra un resumen de lo que se hizo sin permitir acciones
class AsignacionResumenScreen extends StatelessWidget {
  const AsignacionResumenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DemostradorProvider>(
      builder: (context, provider, child) {
        final asignacion = provider.asignacionActual;

        if (asignacion == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Resumen')),
            body: const Center(child: Text('No hay asignación seleccionada')),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            title: const Text('Resumen de Actividad'),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0,
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con info de la campaña
                _buildCampaignHeader(asignacion),

                // Estado general
                _buildEstadoGeneral(asignacion),

                const SizedBox(height: 16),

                // Momentos
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Detalle de Momentos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Inicio de Actividades
                _buildMomentoResumen(
                  context,
                  momento: MomentoRTMT.inicioActividades,
                  registro: asignacion.inicioActividades,
                ),

                // Labor de Venta
                _buildMomentoResumen(
                  context,
                  momento: MomentoRTMT.laborVenta,
                  registro: asignacion.laborVenta,
                ),

                // Cierre de Actividades
                _buildMomentoResumen(
                  context,
                  momento: MomentoRTMT.cierreActividades,
                  registro: asignacion.cierreActividades,
                ),

                const SizedBox(height: 16),

                // Cuestionario de cierre si existe
                if (asignacion.cierreActividades.completada)
                  _buildCuestionarioResumen(asignacion),

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCampaignHeader(AsignacionRTMT asignacion) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icono de campaña
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: asignacion.camp?.medioIcono != null
                      ? Image.network(
                          asignacion.camp!.medioIcono!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Text('🎯', style: TextStyle(fontSize: 24)),
                          ),
                        )
                      : const Center(
                          child: Text('🎯', style: TextStyle(fontSize: 24)),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asignacion.nombreCampana,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      asignacion.nombreTienda,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Fecha y hora
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 6),
              Text(
                asignacion.fechaFormateada,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              if (asignacion.horaFormateada.isNotEmpty) ...[
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  asignacion.horaFormateada,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoGeneral(AsignacionRTMT asignacion) {
    final completada = asignacion.estado == EstadoAsignacion.completada;
    final tieneIncidencias = asignacion.tieneIncidencias;

    Color bgColor;
    Color textColor;
    IconData icon;
    String mensaje;

    if (completada) {
      bgColor = Colors.green[50]!;
      textColor = Colors.green[700]!;
      icon = Icons.check_circle;
      mensaje = 'Actividad completada exitosamente';
    } else if (tieneIncidencias) {
      bgColor = Colors.orange[50]!;
      textColor = Colors.orange[700]!;
      icon = Icons.warning_amber;
      mensaje = 'Actividad con incidencias pendientes';
    } else {
      bgColor = Colors.red[50]!;
      textColor = Colors.red[700]!;
      icon = Icons.cancel;
      mensaje = 'Actividad no completada - Turno finalizado';
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              mensaje,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMomentoResumen(
    BuildContext context, {
    required MomentoRTMT momento,
    required RegistroMomento registro,
  }) {
    final completada = registro.completada;
    final tieneIncidencia = registro.incidencia;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (tieneIncidencia) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
      statusText = 'Con incidencia';
    } else if (completada) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Completado';
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.cancel;
      statusText = 'No realizado';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: momento.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(momento.icon, color: momento.color, size: 24),
          ),
          title: Text(
            momento.label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          subtitle: Row(
            children: [
              Icon(statusIcon, size: 14, color: statusColor),
              const SizedBox(width: 4),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          children: [
            if (completada || tieneIncidencia) ...[
              // Mostrar evidencias
              if (registro.evidencias.isNotEmpty) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Evidencias:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: registro.evidencias.length,
                    itemBuilder: (context, index) {
                      final evidencia = registro.evidencias[index];
                      return GestureDetector(
                        onTap: () => _mostrarImagenCompleta(context, evidencia),
                        child: Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  evidencia.url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.broken_image),
                                  ),
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: progress.expectedTotalBytes != null
                                            ? progress.cumulativeBytesLoaded /
                                                progress.expectedTotalBytes!
                                            : null,
                                        strokeWidth: 2,
                                      ),
                                    );
                                  },
                                ),
                                // Mostrar marca si es labor de venta
                                if (evidencia.marcaNombre != null)
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.7),
                                          ],
                                        ),
                                      ),
                                      child: Text(
                                        evidencia.marcaNombre!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.image_not_supported, color: Colors.grey[400]),
                      const SizedBox(width: 8),
                      Text(
                        'Sin evidencias registradas',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],

              // Fecha de registro
              if (registro.fecha != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      'Registrado: ${_formatDateTime(registro.fecha!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],

              // Ubicación
              if (registro.ubicacion != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '${registro.ubicacion!.lat.toStringAsFixed(4)}, ${registro.ubicacion!.lng.toStringAsFixed(4)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],

              // Notas si existen
              if (registro.notas != null && registro.notas!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notas:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        registro.notas!,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              // Momento no realizado
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red[400]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Este momento no fue registrado antes de que finalizara el turno.',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCuestionarioResumen(AsignacionRTMT asignacion) {
    final cuestionario = asignacion.cuestionario;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.assignment, color: Colors.purple[400]),
              ),
              const SizedBox(width: 12),
              const Text(
                'Cuestionario de Cierre',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCuestionarioItem(
            'Clientes atendidos',
            cuestionario.numClientes.toString(),
            Icons.people,
          ),
          const SizedBox(height: 10),
          _buildCuestionarioItem(
            'Tickets canjeados',
            cuestionario.numTickets.toString(),
            Icons.confirmation_number,
          ),
          // Productos si existen
          if (asignacion.productos.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'Intenciones de Compra por Producto:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...asignacion.productos.map((producto) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        producto.nombre ?? producto.upc ?? 'Producto',
                        style: const TextStyle(fontSize: 14),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${producto.intencionesCompra}',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildCuestionarioItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[500]),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _mostrarImagenCompleta(BuildContext context, EvidenciaMomento evidencia) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botón cerrar
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
              ),
            ),
            // Imagen
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                evidencia.url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  padding: const EdgeInsets.all(40),
                  color: Colors.grey[800],
                  child: const Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              ),
            ),
            // Info de la evidencia
            if (evidencia.marcaNombre != null || evidencia.fecha != null)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    if (evidencia.marcaNombre != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.label, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Marca: ${evidencia.marcaNombre}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    if (evidencia.fecha != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule, size: 16),
                          const SizedBox(width: 6),
                          Text(_formatDateTime(evidencia.fecha!)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
