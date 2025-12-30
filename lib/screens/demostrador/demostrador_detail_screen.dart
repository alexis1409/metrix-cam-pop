import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/asignacion_rtmt.dart';
import '../../providers/demostrador_provider.dart';
import 'momento_capture_screen.dart';

class DemostradorDetailScreen extends StatelessWidget {
  const DemostradorDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DemostradorProvider>(
      builder: (context, provider, child) {
        final asignacion = provider.asignacionActual;

        if (asignacion == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalle')),
            body: const Center(child: Text('No hay asignación seleccionada')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(asignacion.nombreCampana),
            actions: [
              if (provider.isSupervisor)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'forzar_cierre') {
                      _showForzarCierreDialog(context, provider);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'forzar_cierre',
                      child: Row(
                        children: [
                          Icon(Icons.lock_clock, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Forzar Cierre'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              await provider.loadVistaActual(asignacion.id);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(asignacion),
                  const SizedBox(height: 16),
                  _buildMomentosSection(context, asignacion, provider),
                  if (asignacion.camp?.canjeTicket == true) ...[
                    const SizedBox(height: 16),
                    _buildTicketsSection(context, asignacion),
                  ],
                  if (asignacion.tieneIncidencias) ...[
                    const SizedBox(height: 16),
                    _buildIncidenciasAlert(asignacion),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(AsignacionRTMT asignacion) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: asignacion.estado.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.storefront,
                    color: asignacion.estado.color,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asignacion.nombreTienda,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        asignacion.tienda.determinante,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(Icons.calendar_today, 'Fecha', asignacion.fechaFormateada),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.access_time, 'Hora', asignacion.horaFormateada),
            if (asignacion.tienda.direccionCompleta.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.location_on,
                'Dirección',
                asignacion.tienda.direccionCompleta,
              ),
            ],
            if (asignacion.agencia != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.business,
                'Agencia',
                asignacion.agencia!.nombre ?? asignacion.agencia!.clave ?? '',
              ),
            ],
            const SizedBox(height: 12),
            // Progress bar
            LinearProgressIndicator(
              value: asignacion.progreso,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                asignacion.estado == EstadoAsignacion.completada
                    ? Colors.green
                    : Colors.blue,
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              '${(asignacion.progreso * 100).toInt()}% completado',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
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
    );
  }

  Widget _buildMomentosSection(
    BuildContext context,
    AsignacionRTMT asignacion,
    DemostradorProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Momentos del Día',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildMomentoCard(
          context,
          MomentoRTMT.inicioActividades,
          asignacion.inicioActividades,
          asignacion.puedeAvanzarA(MomentoRTMT.inicioActividades),
          provider,
        ),
        const SizedBox(height: 8),
        _buildMomentoCard(
          context,
          MomentoRTMT.laborVenta,
          asignacion.laborVenta,
          asignacion.puedeAvanzarA(MomentoRTMT.laborVenta),
          provider,
        ),
        const SizedBox(height: 8),
        _buildMomentoCard(
          context,
          MomentoRTMT.cierreActividades,
          asignacion.cierreActividades,
          asignacion.puedeAvanzarA(MomentoRTMT.cierreActividades),
          provider,
        ),
      ],
    );
  }

  Widget _buildMomentoCard(
    BuildContext context,
    MomentoRTMT momento,
    RegistroMomento registro,
    bool canAdvance,
    DemostradorProvider provider,
  ) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (registro.incidencia) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
      statusText = 'Incidencia';
    } else if (registro.completada) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'Completado';
    } else if (canAdvance) {
      statusColor = Colors.blue;
      statusIcon = Icons.play_circle;
      statusText = 'Pendiente';
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.lock;
      statusText = 'Bloqueado';
    }

    return Card(
      elevation: canAdvance && !registro.completada ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: canAdvance && !registro.completada
            ? BorderSide(color: Colors.blue, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canAdvance && !registro.completada
            ? () => _navigateToMomento(context, momento)
            : (registro.incidencia
                ? () => _showCorregirIncidenciaDialog(context, momento, provider)
                : null),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(momento.icon, color: statusColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      momento.label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
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
                        if (registro.fecha != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${registro.fecha!.hour.toString().padLeft(2, '0')}:${registro.fecha!.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (canAdvance && !registro.completada)
                const Icon(Icons.arrow_forward_ios, color: Colors.blue)
              else if (registro.incidencia)
                TextButton(
                  onPressed: () => _showCorregirIncidenciaDialog(context, momento, provider),
                  child: const Text('Corregir'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketsSection(BuildContext context, AsignacionRTMT asignacion) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Tickets de Canje',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (asignacion.laborVenta.completada && !asignacion.laborVenta.incidencia)
              ElevatedButton.icon(
                onPressed: () {
                  // Navigate to ticket capture
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Captura de ticket - Por implementar')),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Nuevo Ticket'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (asignacion.cuestionario.numTickets > 0)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long, color: Colors.green),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${asignacion.cuestionario.numTickets} tickets',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'registrados hoy',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'No hay tickets registrados',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildIncidenciasAlert(AsignacionRTMT asignacion) {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tienes incidencias pendientes',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Corrige las incidencias para poder continuar',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToMomento(BuildContext context, MomentoRTMT momento) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MomentoCaptureScreen(momento: momento),
      ),
    );
  }

  void _showCorregirIncidenciaDialog(
    BuildContext context,
    MomentoRTMT momento,
    DemostradorProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Corregir Incidencia'),
        content: const Text('¿Deseas tomar una nueva foto para corregir la incidencia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MomentoCaptureScreen(
                    momento: momento,
                    isCorrection: true,
                  ),
                ),
              );
            },
            child: const Text('Corregir'),
          ),
        ],
      ),
    );
  }

  void _showForzarCierreDialog(BuildContext context, DemostradorProvider provider) {
    final motivoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forzar Cierre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Esta acción cerrará la asignación sin completar todos los momentos.'),
            const SizedBox(height: 16),
            TextField(
              controller: motivoController,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              if (motivoController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingresa un motivo')),
                );
                return;
              }
              Navigator.pop(context);
              final success = await provider.forzarCierre(
                motivo: motivoController.text,
              );
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cierre forzado exitosamente')),
                );
              }
            },
            child: const Text('Forzar Cierre'),
          ),
        ],
      ),
    );
  }
}
