import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/asignacion_rtmt.dart';
import '../../models/ticket_canje.dart';
import '../../providers/demostrador_provider.dart';
import 'momento_capture_screen.dart';
import 'ticket_canje_screen.dart';
import 'dinamica_participacion_screen.dart';

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
                    if (value == 'habilitar_cierre') {
                      _showHabilitarCierreDialog(context, provider);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'habilitar_cierre',
                      child: Row(
                        children: [
                          Icon(Icons.lock_open, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Habilitar Cierre'),
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
                  _buildInfoCard(context, asignacion),
                  const SizedBox(height: 16),
                  _buildMomentosSection(context, asignacion, provider),
                  // Mostrar tickets para canje_compra o canje_dinamica
                  if (asignacion.camp?.canjeTicket == true ||
                      asignacion.camp?.esCanjeDinamica == true) ...[
                    const SizedBox(height: 16),
                    _buildTicketsSection(context, asignacion),
                  ],
                  // Mostrar dinámicas adicionales solo para canje_dinamica
                  if (asignacion.camp?.esCanjeDinamica == true) ...[
                    const SizedBox(height: 16),
                    _buildDinamicasSection(context, asignacion),
                  ],
                  if (asignacion.tieneIncidencias) ...[
                    const SizedBox(height: 16),
                    _buildIncidenciasAlert(context, asignacion),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(BuildContext context, AsignacionRTMT asignacion) {
    return Card(
      color: context.surfaceColor,
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        asignacion.tienda.determinante,
                        style: TextStyle(
                          color: context.textSecondaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(height: 24, color: context.borderColor),
            _buildInfoRow(context, Icons.calendar_today, 'Fecha', asignacion.fechaFormateada),
            const SizedBox(height: 8),
            _buildInfoRow(context, Icons.access_time, 'Hora', asignacion.horaFormateada),
            if (asignacion.tienda.direccionCompleta.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                context,
                Icons.location_on,
                'Dirección',
                asignacion.tienda.direccionCompleta,
              ),
            ],
            if (asignacion.agencia != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                context,
                Icons.business,
                'Agencia',
                asignacion.agencia!.nombre ?? asignacion.agencia!.clave ?? '',
              ),
            ],
            const SizedBox(height: 12),
            // Progress bar
            LinearProgressIndicator(
              value: asignacion.progreso,
              backgroundColor: context.isDarkMode ? AppColors.surfaceVariantDark : Colors.grey[200],
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
                color: context.textSecondaryColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.textSecondaryColor),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(color: context.textSecondaryColor),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: context.textPrimaryColor,
            ),
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
        Text(
          'Momentos del Día',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.textPrimaryColor,
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
    final asignacion = provider.asignacionActual;
    // Verificar si el cierre esta bloqueado por tiempo
    final cierreBloqueadoPorTiempo = momento == MomentoRTMT.cierreActividades &&
        asignacion != null &&
        asignacion.cierreBloqueadoPorTiempo;
    // Verificar si el cierre fue habilitado por el supervisor
    final cierreHabilitadoPorSupervisor = momento == MomentoRTMT.cierreActividades &&
        asignacion != null &&
        (asignacion.cierreHabilitadoPorSupervisor?.habilitado ?? false);

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
    } else if (cierreBloqueadoPorTiempo) {
      statusColor = Colors.amber;
      statusIcon = Icons.schedule;
      statusText = 'Esperando hora';
    } else if (cierreHabilitadoPorSupervisor && canAdvance) {
      statusColor = Colors.green;
      statusIcon = Icons.lock_open;
      statusText = 'Habilitado';
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
      color: context.surfaceColor,
      elevation: canAdvance && !registro.completada ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: canAdvance && !registro.completada
            ? const BorderSide(color: Colors.blue, width: 2)
            : (cierreBloqueadoPorTiempo
                ? const BorderSide(color: Colors.amber, width: 2)
                : BorderSide(color: context.borderColor, width: 0.5)),
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimaryColor,
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
                              color: context.textSecondaryColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Mostrar mensaje de cuando se habilita el cierre o si fue habilitado por supervisor
                    if (cierreHabilitadoPorSupervisor && !registro.completada) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_open, size: 12, color: Colors.green[700]),
                            const SizedBox(width: 4),
                            Text(
                              'El supervisor habilitó tu cierre',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (cierreBloqueadoPorTiempo) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time, size: 12, color: Colors.amber[800]),
                            const SizedBox(width: 4),
                            Text(
                              'Se habilita a las ${asignacion.actividad?.horaHabilitaCierreFormateada ?? ""}',
                              style: TextStyle(
                                color: Colors.amber[800],
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
    // Solo permitir subir tickets cuando Inicio de Actividades esté completado
    // y el Cierre de Actividades NO esté completado
    final puedeSubirTickets = asignacion.inicioActividades.completada &&
        !asignacion.inicioActividades.incidencia &&
        !asignacion.cierreActividades.completada;

    // Determinar el mensaje a mostrar si no puede subir tickets
    String? mensajeBloqueo;
    if (asignacion.cierreActividades.completada) {
      mensajeBloqueo = 'La jornada ya fue cerrada, no se pueden registrar más tickets';
    } else if (!asignacion.inicioActividades.completada || asignacion.inicioActividades.incidencia) {
      mensajeBloqueo = 'Completa el Inicio de Actividades para poder registrar tickets';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tickets de Canje',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.textPrimaryColor,
              ),
            ),
            if (puedeSubirTickets)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TicketCanjeScreen(
                        asignacion: asignacion,
                        configCanje: asignacion.camp?.configCanje,
                        configDinamica: asignacion.camp?.configDinamica,
                        esCanjeDinamica: asignacion.camp?.esCanjeDinamica ?? false,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Nuevo Ticket'),
              ),
          ],
        ),
        // Mensaje si no puede subir tickets
        if (mensajeBloqueo != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: asignacion.cierreActividades.completada
                    ? Colors.grey.withOpacity(0.1)
                    : Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: asignacion.cierreActividades.completada
                      ? Colors.grey.withOpacity(0.3)
                      : Colors.amber.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    asignacion.cierreActividades.completada
                        ? Icons.lock
                        : Icons.info_outline,
                    color: asignacion.cierreActividades.completada
                        ? Colors.grey[600]
                        : Colors.amber[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mensajeBloqueo,
                      style: TextStyle(
                        fontSize: 12,
                        color: asignacion.cierreActividades.completada
                            ? Colors.grey[700]
                            : Colors.amber[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (asignacion.cuestionario.numTickets > 0)
          Card(
            color: context.surfaceColor,
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
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimaryColor,
                        ),
                      ),
                      Text(
                        'registrados hoy',
                        style: TextStyle(color: context.textSecondaryColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            color: context.surfaceColor,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long, size: 48, color: context.textMutedColor),
                    const SizedBox(height: 8),
                    Text(
                      'No hay tickets registrados',
                      style: TextStyle(color: context.textSecondaryColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDinamicasSection(BuildContext context, AsignacionRTMT asignacion) {
    // Solo permitir participar cuando Inicio de Actividades esté completado
    // y el Cierre de Actividades NO esté completado
    final puedeParticipar = asignacion.inicioActividades.completada &&
        !asignacion.inicioActividades.incidencia &&
        !asignacion.cierreActividades.completada;

    // Determinar el mensaje a mostrar si no puede participar
    String? mensajeBloqueo;
    if (asignacion.cierreActividades.completada) {
      mensajeBloqueo = 'La jornada ya fue cerrada, no se pueden registrar más dinámicas';
    } else if (!asignacion.inicioActividades.completada || asignacion.inicioActividades.incidencia) {
      mensajeBloqueo = 'Completa el Inicio de Actividades para poder registrar dinámicas';
    }

    final configDinamicas = asignacion.camp?.configDinamica ?? [];
    final participaciones = asignacion.participacionesDinamica;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dinámicas',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.textPrimaryColor,
          ),
        ),
        // Mensaje si no puede participar
        if (mensajeBloqueo != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: asignacion.cierreActividades.completada
                    ? Colors.grey.withOpacity(0.1)
                    : Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: asignacion.cierreActividades.completada
                      ? Colors.grey.withOpacity(0.3)
                      : Colors.amber.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    asignacion.cierreActividades.completada
                        ? Icons.lock
                        : Icons.info_outline,
                    color: asignacion.cierreActividades.completada
                        ? Colors.grey[600]
                        : Colors.amber[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mensajeBloqueo,
                      style: TextStyle(
                        fontSize: 12,
                        color: asignacion.cierreActividades.completada
                            ? Colors.grey[700]
                            : Colors.amber[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        // Mostrar dinámicas disponibles
        if (configDinamicas.isNotEmpty)
          ...configDinamicas.map((dinamica) => _buildDinamicaCard(
            context,
            dinamica,
            asignacion,
            puedeParticipar,
            participaciones,
          ))
        else
          Card(
            color: context.surfaceColor,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.celebration, size: 48, color: context.textMutedColor),
                    const SizedBox(height: 8),
                    Text(
                      'No hay dinámicas configuradas',
                      style: TextStyle(color: context.textSecondaryColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        // Contador de participaciones
        if (participaciones.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            color: context.surfaceColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.people, color: Colors.purple),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${participaciones.length} participaciones',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimaryColor,
                        ),
                      ),
                      Text(
                        'registradas hoy',
                        style: TextStyle(color: context.textSecondaryColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDinamicaCard(
    BuildContext context,
    ConfigDinamica dinamica,
    AsignacionRTMT asignacion,
    bool puedeParticipar,
    List<ParticipacionDinamica> participaciones,
  ) {
    // Contar cuántas veces se ha participado en esta dinámica
    final participacionesEnDinamica = participaciones
        .where((p) => p.dinamicaNombre == dinamica.nombre)
        .length;

    return Card(
      color: context.surfaceColor,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: puedeParticipar
            ? const BorderSide(color: Colors.purple, width: 1)
            : BorderSide(color: context.borderColor, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: puedeParticipar
            ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DinamicaParticipacionScreen(
                    asignacion: asignacion,
                    dinamica: dinamica,
                  ),
                ),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getRecompensaIcon(dinamica.tipoRecompensa),
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dinamica.nombre,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dinamica.descripcion,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondaryColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            dinamica.recompensa,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber[800],
                            ),
                          ),
                        ),
                        if (participacionesEnDinamica > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$participacionesEnDinamica registros',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (puedeParticipar)
                const Icon(Icons.add_circle_outline, color: Colors.purple),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getRecompensaIcon(String tipo) {
    switch (tipo) {
      case 'producto':
        return Icons.card_giftcard;
      case 'descuento':
        return Icons.discount;
      default:
        return Icons.emoji_events;
    }
  }

  Widget _buildIncidenciasAlert(BuildContext context, AsignacionRTMT asignacion) {
    return Card(
      color: context.isDarkMode ? Colors.orange.shade900.withOpacity(0.3) : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange[context.isDarkMode ? 400 : 700]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tienes incidencias pendientes',
                    style: TextStyle(
                      color: Colors.orange[context.isDarkMode ? 300 : 800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Corrige las incidencias para poder continuar',
                    style: TextStyle(
                      color: Colors.orange[context.isDarkMode ? 400 : 700],
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

  void _showHabilitarCierreDialog(BuildContext context, DemostradorProvider provider) {
    final motivoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Habilitar Cierre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Esta acción habilitará el cierre de actividades para que el demostrador pueda tomar su foto de cierre.'),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              if (motivoController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingresa un motivo')),
                );
                return;
              }
              Navigator.pop(context);
              final success = await provider.habilitarCierre(
                motivo: motivoController.text,
              );
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cierre habilitado exitosamente')),
                );
              }
            },
            child: const Text('Habilitar Cierre'),
          ),
        ],
      ),
    );
  }
}
