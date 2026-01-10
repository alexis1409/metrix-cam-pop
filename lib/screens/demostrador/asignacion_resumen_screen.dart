import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
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
          backgroundColor: context.backgroundColor,
          appBar: AppBar(
            title: Text(
              'Resumen de Actividad',
              style: TextStyle(color: context.textPrimaryColor),
            ),
            backgroundColor: context.surfaceColor,
            foregroundColor: context.textPrimaryColor,
            elevation: 0,
            iconTheme: IconThemeData(color: context.textPrimaryColor),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              await provider.loadVistaActual(asignacion.id);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con info de la campaña
                _buildCampaignHeader(context, asignacion),

                // Estado general
                _buildEstadoGeneral(context, asignacion),

                const SizedBox(height: 16),

                // Momentos
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Detalle de Momentos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimaryColor,
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
                  _buildCuestionarioResumen(context, asignacion),

                const SizedBox(height: 32),
              ],
            ),
          ),
          ),
        );
      },
    );
  }

  Widget _buildCampaignHeader(BuildContext context, AsignacionRTMT asignacion) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(context.isDarkMode ? 0.2 : 0.05),
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
                  color: context.isDarkMode ? AppColors.surfaceVariantDark : Colors.grey[100],
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      asignacion.nombreTienda,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textSecondaryColor,
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
              Icon(Icons.calendar_today, size: 16, color: context.textMutedColor),
              const SizedBox(width: 6),
              Text(
                asignacion.fechaFormateada,
                style: TextStyle(fontSize: 14, color: context.textSecondaryColor),
              ),
              if (asignacion.horaFormateada.isNotEmpty) ...[
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: context.textMutedColor),
                const SizedBox(width: 6),
                Text(
                  asignacion.horaFormateada,
                  style: TextStyle(fontSize: 14, color: context.textSecondaryColor),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoGeneral(BuildContext context, AsignacionRTMT asignacion) {
    final completada = asignacion.estado == EstadoAsignacion.completada;
    final tieneIncidencias = asignacion.tieneIncidencias;
    final isDark = context.isDarkMode;

    Color bgColor;
    Color textColor;
    IconData icon;
    String mensaje;

    if (completada) {
      bgColor = isDark ? Colors.green.shade900.withOpacity(0.3) : Colors.green[50]!;
      textColor = isDark ? Colors.green[300]! : Colors.green[700]!;
      icon = Icons.check_circle;
      mensaje = 'Actividad completada exitosamente';
    } else if (tieneIncidencias) {
      bgColor = isDark ? Colors.orange.shade900.withOpacity(0.3) : Colors.orange[50]!;
      textColor = isDark ? Colors.orange[300]! : Colors.orange[700]!;
      icon = Icons.warning_amber;
      mensaje = 'Actividad con incidencias pendientes';
    } else {
      bgColor = isDark ? Colors.red.shade900.withOpacity(0.3) : Colors.red[50]!;
      textColor = isDark ? Colors.red[300]! : Colors.red[700]!;
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
    final isDark = context.isDarkMode;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (tieneIncidencia) {
      statusColor = isDark ? Colors.orange[300]! : Colors.orange;
      statusIcon = Icons.warning;
      statusText = 'Con incidencia';
    } else if (completada) {
      statusColor = isDark ? Colors.green[300]! : Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Completado';
    } else {
      statusColor = context.textMutedColor;
      statusIcon = Icons.cancel;
      statusText = 'No realizado';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
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
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: context.textPrimaryColor,
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Evidencias:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: context.textPrimaryColor,
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
                            border: Border.all(color: context.borderColor),
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
                                    color: context.isDarkMode ? AppColors.surfaceVariantDark : Colors.grey[200],
                                    child: Icon(Icons.broken_image, color: context.textMutedColor),
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
                    color: context.isDarkMode ? AppColors.surfaceVariantDark : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.image_not_supported, color: context.textMutedColor),
                      const SizedBox(width: 8),
                      Text(
                        'Sin evidencias registradas',
                        style: TextStyle(color: context.textSecondaryColor),
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
                    Icon(Icons.schedule, size: 14, color: context.textMutedColor),
                    const SizedBox(width: 4),
                    Text(
                      'Registrado: ${_formatDateTime(registro.fecha!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondaryColor,
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
                    Icon(Icons.location_on, size: 14, color: context.textMutedColor),
                    const SizedBox(width: 4),
                    Text(
                      '${registro.ubicacion!.lat.toStringAsFixed(4)}, ${registro.ubicacion!.lng.toStringAsFixed(4)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondaryColor,
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
                    color: context.isDarkMode ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue[50],
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
                          color: context.isDarkMode ? Colors.blue[300] : Colors.blue[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        registro.notas!,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.isDarkMode ? Colors.blue[200] : Colors.blue[900],
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
                  color: context.isDarkMode ? Colors.red.shade900.withOpacity(0.3) : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: context.isDarkMode ? Colors.red[300] : Colors.red[400]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Este momento no fue registrado antes de que finalizara el turno.',
                        style: TextStyle(
                          color: context.isDarkMode ? Colors.red[300] : Colors.red[700],
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

  Widget _buildCuestionarioResumen(BuildContext context, AsignacionRTMT asignacion) {
    final cuestionario = asignacion.cuestionario;
    final isDark = context.isDarkMode;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
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
                  color: isDark ? Colors.purple.shade900.withOpacity(0.3) : Colors.purple[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.assignment, color: isDark ? Colors.purple[300] : Colors.purple[400]),
              ),
              const SizedBox(width: 12),
              Text(
                'Cuestionario de Cierre',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCuestionarioItem(
            context,
            'Clientes atendidos',
            cuestionario.numClientes.toString(),
            Icons.people,
          ),
          const SizedBox(height: 10),
          _buildCuestionarioItem(
            context,
            'Tickets canjeados',
            cuestionario.numTickets.toString(),
            Icons.confirmation_number,
          ),
          // Productos si existen
          if (asignacion.productos.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: context.borderColor),
            const SizedBox(height: 12),
            Text(
              'Intenciones de Compra por Producto:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.textPrimaryColor,
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
                        style: TextStyle(fontSize: 14, color: context.textPrimaryColor),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.blue.shade900.withOpacity(0.3) : Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${producto.intencionesCompra}',
                          style: TextStyle(
                            color: isDark ? Colors.blue[300] : Colors.blue[700],
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

  Widget _buildCuestionarioItem(BuildContext context, String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.textMutedColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondaryColor,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: context.isDarkMode ? AppColors.surfaceVariantDark : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.textPrimaryColor,
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
