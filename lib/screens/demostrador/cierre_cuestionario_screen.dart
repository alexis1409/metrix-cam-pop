import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/asignacion_rtmt.dart';
import '../../providers/demostrador_provider.dart';
import '../../config/api_config.dart';

class CierreCuestionarioScreen extends StatefulWidget {
  final File foto;
  final Ubicacion? ubicacion;

  const CierreCuestionarioScreen({
    super.key,
    required this.foto,
    this.ubicacion,
  });

  @override
  State<CierreCuestionarioScreen> createState() => _CierreCuestionarioScreenState();
}

class _CierreCuestionarioScreenState extends State<CierreCuestionarioScreen> {
  final _numClientesController = TextEditingController();
  final _comentariosController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Mapa para guardar las intenciones de compra por producto/marca
  final Map<String, int> _intencionesCompra = {};

  @override
  void initState() {
    super.initState();
    _initIntencionesCompra();
  }

  void _initIntencionesCompra() {
    final provider = context.read<DemostradorProvider>();
    final asignacion = provider.asignacionActual;

    // Inicializar con productos de la asignación
    if (asignacion?.productos.isNotEmpty == true) {
      for (var producto in asignacion!.productos) {
        final key = producto.upc ?? producto.nombre ?? '';
        _intencionesCompra[key] = producto.intencionesCompra;
      }
    }

    // Inicializar con marcas de la campaña
    if (asignacion?.camp?.marcas.isNotEmpty ?? false) {
      for (var marca in asignacion!.camp!.marcas) {
        final key = marca.id ?? marca.nombre;
        if (!_intencionesCompra.containsKey(key)) {
          _intencionesCompra[key] = 0;
        }
      }
    }
  }

  @override
  void dispose() {
    _numClientesController.dispose();
    _comentariosController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final numClientes = int.tryParse(_numClientesController.text);
    if (numClientes == null || numClientes < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un número válido de clientes')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final provider = context.read<DemostradorProvider>();

    // Construir lista de intenciones de compra
    List<ProductoAsignacion> intencionesCompra = [];
    _intencionesCompra.forEach((key, value) {
      intencionesCompra.add(ProductoAsignacion(
        upc: key,
        nombre: _getNombreProducto(key),
        intencionesCompra: value,
      ));
    });

    final success = await provider.registrarCierre(
      foto: widget.foto,
      ubicacion: widget.ubicacion,
      numClientes: numClientes,
      numTickets: provider.asignacionActual?.cuestionario.numTickets,
      intencionesCompra: intencionesCompra,
      notas: _comentariosController.text.isNotEmpty ? _comentariosController.text : null,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Actividad completada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      // Pop back to home
      Navigator.popUntil(context, (route) => route.isFirst);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Error al registrar cierre'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getNombreProducto(String key) {
    final provider = context.read<DemostradorProvider>();
    final asignacion = provider.asignacionActual;

    // Buscar en productos
    final producto = asignacion?.productos.firstWhere(
      (p) => p.upc == key || p.nombre == key,
      orElse: () => ProductoAsignacion(nombre: key),
    );
    if (producto?.nombre != null) return producto!.nombre!;

    // Buscar en marcas
    final marca = asignacion?.camp?.marcas.firstWhere(
      (m) => m.id == key || m.nombre == key,
      orElse: () => MarcaCampania(nombre: key),
    );
    return marca?.nombre ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DemostradorProvider>();
    final asignacion = provider.asignacionActual;
    // hasTickets debe ser true para canje_compra O canje_dinamica
    final hasTickets = asignacion?.camp?.canjeTicket == true ||
        asignacion?.camp?.esCanjeDinamica == true;
    final hasMarcas = (asignacion?.camp?.marcas.isNotEmpty ?? false) ||
        (asignacion?.productos.isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuestionario de Cierre'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photo preview
              _buildPhotoPreview(),

              const SizedBox(height: 24),

              // Resumen de evidencias
              _buildResumenEvidencias(asignacion),

              const SizedBox(height: 24),

              // Title
              const Text(
                'Cuestionario de Cierre',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ingresa los datos de tu actividad del día',
                style: TextStyle(color: Colors.grey[600]),
              ),

              const SizedBox(height: 24),

              // Num clientes
              TextFormField(
                controller: _numClientesController,
                decoration: const InputDecoration(
                  labelText: 'Número de clientes atendidos *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people),
                  hintText: 'Ej: 25',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Este campo es requerido';
                  }
                  final num = int.tryParse(value);
                  if (num == null || num < 0) {
                    return 'Ingresa un número válido';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Intenciones de compra por marca/producto
              if (hasMarcas) ...[
                _buildIntencionesCompraSection(asignacion),
                const SizedBox(height: 24),
              ],

              // Estadísticas de tickets (si aplica)
              if (hasTickets && (asignacion?.ticketsCanje.isNotEmpty ?? false)) ...[
                _buildTicketsSection(asignacion!),
                const SizedBox(height: 24),
              ],

              // Campo de comentarios
              const Text(
                'Comentarios (opcional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _comentariosController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Escribe observaciones o comentarios sobre tu jornada...',
                  prefixIcon: Icon(Icons.comment),
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 32),

              // Submit button
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle),
                  label: Text(
                    _isLoading ? 'Guardando...' : 'Finalizar Actividad',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Summary info
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Al finalizar, tu actividad será marcada como completada y no podrás realizar más cambios.',
                          style: TextStyle(color: Colors.blue[800], fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                widget.foto,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Evidencia de cierre',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Foto capturada',
                        style: TextStyle(color: Colors.green[600], fontSize: 12),
                      ),
                    ],
                  ),
                  if (widget.ubicacion != null)
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.green[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Ubicación registrada',
                          style: TextStyle(color: Colors.green[600], fontSize: 12),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenEvidencias(AsignacionRTMT? asignacion) {
    if (asignacion == null) return const SizedBox.shrink();

    final inicioEvidencias = asignacion.inicioActividades.evidencias;
    final laborEvidencias = asignacion.laborVenta.evidencias;
    final ticketsCount = asignacion.ticketsCanje.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.photo_library, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Resumen de Evidencias',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Grid de evidencias
            Row(
              children: [
                _buildEvidenciaItem(
                  'Inicio',
                  inicioEvidencias.length,
                  Icons.login,
                  Colors.blue,
                  inicioEvidencias.isNotEmpty ? inicioEvidencias.first.url : null,
                ),
                const SizedBox(width: 12),
                _buildEvidenciaItem(
                  'Labor',
                  laborEvidencias.length,
                  Icons.storefront,
                  Colors.orange,
                  laborEvidencias.isNotEmpty ? laborEvidencias.first.url : null,
                ),
                const SizedBox(width: 12),
                _buildEvidenciaItem(
                  'Cierre',
                  1,
                  Icons.logout,
                  Colors.green,
                  null, // La foto de cierre se mostrará arriba
                ),
              ],
            ),

            // Tickets si aplica
            if (ticketsCount > 0) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long, color: Colors.purple, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$ticketsCount tickets registrados',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Mostrar miniaturas de tickets
              SizedBox(
                height: 70,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: asignacion.ticketsCanje.length,
                  itemBuilder: (context, index) {
                    final ticket = asignacion.ticketsCanje[index];
                    final hasPremio = ticket.premioNombre != null && ticket.premioNombre!.isNotEmpty;
                    return Stack(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.purple.withOpacity(0.1),
                            border: Border.all(
                              color: hasPremio ? Colors.amber : Colors.purple.withOpacity(0.3),
                              width: hasPremio ? 2 : 1,
                            ),
                            image: ticket.fotoUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(_getFullImageUrl(ticket.fotoUrl!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: ticket.fotoUrl == null
                              ? const Icon(Icons.receipt, color: Colors.purple, size: 24)
                              : null,
                        ),
                        // Ícono de ticket superpuesto
                        Positioned(
                          bottom: 2,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.purple,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.receipt, color: Colors.white, size: 10),
                          ),
                        ),
                        // Ícono de premio si ganó
                        if (hasPremio)
                          Positioned(
                            top: 0,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.emoji_events, color: Colors.white, size: 10),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getFullImageUrl(String url) {
    if (url.startsWith('http')) return url;
    return '${ApiConfig.baseUrl}$url';
  }

  Widget _buildEvidenciaItem(
    String label,
    int count,
    IconData icon,
    Color color,
    String? imageUrl,
  ) {
    return Expanded(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: color.withOpacity(0.1),
                  image: imageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(_getFullImageUrl(imageUrl)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: imageUrl == null
                    ? Center(
                        child: Icon(icon, color: color, size: 28),
                      )
                    : null,
              ),
              // Ícono superpuesto cuando hay imagen
              if (imageUrl != null)
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 14),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 12),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          Text(
            '$count foto${count != 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntencionesCompraSection(AsignacionRTMT? asignacion) {
    // Obtener lista de marcas/productos
    List<Map<String, String>> items = [];

    if (asignacion?.camp?.marcas.isNotEmpty ?? false) {
      for (var marca in asignacion!.camp!.marcas) {
        items.add({
          'key': marca.id ?? marca.nombre,
          'nombre': marca.nombre,
        });
      }
    } else if (asignacion?.productos.isNotEmpty ?? false) {
      for (var producto in asignacion!.productos) {
        items.add({
          'key': producto.upc ?? producto.nombre ?? '',
          'nombre': producto.nombre ?? producto.upc ?? 'Producto',
        });
      }
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.trending_up, color: Colors.blue),
            SizedBox(width: 8),
            Text(
              'Intenciones de Compra',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Registra cuántos clientes mostraron interés en cada producto',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        const SizedBox(height: 12),
        ...items.map((item) => _buildIntencionItem(item['key']!, item['nombre']!)),
      ],
    );
  }

  Widget _buildIntencionItem(String key, String nombre) {
    final count = _intencionesCompra[key] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                nombre,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: count > 0
                      ? () {
                          setState(() {
                            _intencionesCompra[key] = count - 1;
                          });
                        }
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  color: Colors.red,
                  iconSize: 28,
                ),
                Container(
                  width: 50,
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _intencionesCompra[key] = count + 1;
                    });
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  color: Colors.green,
                  iconSize: 28,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketsSection(AsignacionRTMT asignacion) {
    final tickets = asignacion.ticketsCanje;
    if (tickets.isEmpty) return const SizedBox.shrink();

    // Calcular estadísticas
    final totalMonto = tickets.fold<double>(0, (sum, t) => sum + t.monto);
    final promedioMonto = totalMonto / tickets.length;

    // Contar premios por nombre
    final Map<String, int> premiosPorNombre = {};
    int ticketsSinPremio = 0;

    for (var ticket in tickets) {
      final premioNombre = ticket.premioNombre;
      if (premioNombre != null && premioNombre.isNotEmpty) {
        premiosPorNombre[premioNombre] = (premiosPorNombre[premioNombre] ?? 0) + 1;
      } else {
        ticketsSinPremio++;
      }
    }

    return Card(
      color: Colors.purple.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.purple[700]),
                const SizedBox(width: 8),
                Text(
                  'Resumen de Tickets',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Estadísticas generales
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Tickets',
                    '${tickets.length}',
                    Icons.receipt,
                    Colors.purple,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Ticket Promedio',
                    '\$${promedioMonto.toStringAsFixed(0)}',
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Monto Total',
                    '\$${totalMonto.toStringAsFixed(0)}',
                    Icons.monetization_on,
                    Colors.amber,
                  ),
                ),
              ],
            ),

            // Premios entregados
            if (premiosPorNombre.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Premios Entregados',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[800],
                ),
              ),
              const SizedBox(height: 8),
              ...premiosPorNombre.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${entry.value}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
              if (ticketsSinPremio > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.remove_circle_outline, color: Colors.grey[500], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sin premio',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$ticketsSinPremio',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
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

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
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
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
