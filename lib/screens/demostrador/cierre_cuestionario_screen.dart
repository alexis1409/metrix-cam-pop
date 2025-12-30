import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/asignacion_rtmt.dart';
import '../../providers/demostrador_provider.dart';

class CierreCuestionarioScreen extends StatefulWidget {
  final File foto;
  final Ubicacion? ubicacion;
  final String? notas;

  const CierreCuestionarioScreen({
    super.key,
    required this.foto,
    this.ubicacion,
    this.notas,
  });

  @override
  State<CierreCuestionarioScreen> createState() => _CierreCuestionarioScreenState();
}

class _CierreCuestionarioScreenState extends State<CierreCuestionarioScreen> {
  final _numClientesController = TextEditingController();
  final _numTicketsController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _numClientesController.dispose();
    _numTicketsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final numClientes = int.tryParse(_numClientesController.text);
    if (numClientes == null || numClientes < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un número válido de clientes')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final provider = context.read<DemostradorProvider>();
    final numTickets = int.tryParse(_numTicketsController.text);

    // Get intenciones from productos if available
    List<ProductoAsignacion>? intencionesCompra;
    if (provider.asignacionActual?.productos.isNotEmpty == true) {
      intencionesCompra = provider.asignacionActual!.productos;
    }

    final success = await provider.registrarCierre(
      foto: widget.foto,
      ubicacion: widget.ubicacion,
      numClientes: numClientes,
      numTickets: numTickets,
      intencionesCompra: intencionesCompra,
      notas: widget.notas,
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DemostradorProvider>();
    final asignacion = provider.asignacionActual;
    final hasTickets = asignacion?.camp?.canjeTicket == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuestionario de Cierre'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Photo preview
            Card(
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
            ),

            const SizedBox(height: 24),

            // Title
            const Text(
              'Completa el cuestionario',
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
            TextField(
              controller: _numClientesController,
              decoration: const InputDecoration(
                labelText: 'Número de clientes atendidos *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.people),
                hintText: 'Ej: 25',
              ),
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 16),

            // Num tickets (if applicable)
            if (hasTickets) ...[
              TextField(
                controller: _numTicketsController,
                decoration: const InputDecoration(
                  labelText: 'Número de tickets canjeados',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.receipt_long),
                  hintText: 'Ej: 10',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
            ],

            // Intenciones de compra (if productos available)
            if (asignacion?.productos.isNotEmpty == true) ...[
              const Text(
                'Intenciones de compra',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Registra cuántos clientes mostraron interés en cada producto',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 12),
              ...asignacion!.productos.map((producto) => _buildProductoItem(producto)),
            ],

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

            // Summary
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
    );
  }

  Widget _buildProductoItem(ProductoAsignacion producto) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    producto.nombre ?? 'Producto',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (producto.upc != null)
                    Text(
                      'UPC: ${producto.upc}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {
                    if (producto.intencionesCompra > 0) {
                      setState(() => producto.intencionesCompra--);
                    }
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                  color: Colors.red,
                ),
                Container(
                  width: 40,
                  alignment: Alignment.center,
                  child: Text(
                    '${producto.intencionesCompra}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() => producto.intencionesCompra++);
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  color: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
