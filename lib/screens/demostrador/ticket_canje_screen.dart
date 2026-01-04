import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/asignacion_rtmt.dart';
import '../../models/ticket_canje.dart';
import '../../providers/demostrador_provider.dart';
import 'quick_camera_screen.dart';

class TicketCanjeScreen extends StatefulWidget {
  final AsignacionRTMT asignacion;
  final List<ConfigCanje>? configCanje;
  final List<ConfigDinamica>? configDinamica;
  final bool esCanjeDinamica;

  const TicketCanjeScreen({
    super.key,
    required this.asignacion,
    this.configCanje,
    this.configDinamica,
    this.esCanjeDinamica = false,
  });

  @override
  State<TicketCanjeScreen> createState() => _TicketCanjeScreenState();
}

class _TicketCanjeScreenState extends State<TicketCanjeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montoController = TextEditingController();

  File? _fotoTicket;
  MarcaCampania? _marcaSeleccionada;
  Ubicacion? _ubicacion;
  bool _obteniendoUbicacion = false;
  String? _locationError;
  bool _guardando = false;
  PremioGanado? _premioCalculado;
  ConfigCanje? _configCanjeActiva;
  ConfigDinamica? _premioSeleccionado; // Para canje_dinamica: premio elegido manualmente

  @override
  void initState() {
    super.initState();
    _obtenerUbicacion();
    // Usar la primera configuración de canje (México por defecto)
    if (widget.configCanje != null && widget.configCanje!.isNotEmpty) {
      _configCanjeActiva = widget.configCanje!.first;
    }
  }

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  Future<void> _obtenerUbicacion() async {
    setState(() {
      _obteniendoUbicacion = true;
      _locationError = null;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permiso de ubicación denegado');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permiso de ubicación denegado permanentemente');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _ubicacion = Ubicacion(
          lat: position.latitude,
          lng: position.longitude,
        );
        _obteniendoUbicacion = false;
      });
    } catch (e) {
      setState(() {
        _locationError = e.toString();
        _obteniendoUbicacion = false;
      });
    }
  }

  Future<void> _tomarFoto() async {
    // Navigate to quick camera screen (same as labor de venta)
    final File? result = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (context) => const QuickCameraScreen(),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _fotoTicket = result;
      });
    }
  }

  void _calcularPremio() {
    final montoText = _montoController.text.replaceAll(',', '.');
    final monto = double.tryParse(montoText);

    if (monto != null && _configCanjeActiva != null) {
      setState(() {
        _premioCalculado = _configCanjeActiva!.encontrarPremio(monto);
      });
    } else {
      setState(() => _premioCalculado = null);
    }
  }

  Future<void> _guardarTicket() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fotoTicket == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor toma una foto del ticket')),
      );
      return;
    }

    if (_marcaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona una marca')),
      );
      return;
    }

    // Para canje_dinamica, validar que se haya seleccionado un premio
    if (widget.esCanjeDinamica && _premioSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona el premio a entregar')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final provider = context.read<DemostradorProvider>();
      final montoText = _montoController.text.replaceAll(',', '.');
      final monto = double.parse(montoText);

      // Para canje_dinamica, crear el premio basado en la selección manual
      PremioGanado? premioFinal;
      if (widget.esCanjeDinamica && _premioSeleccionado != null) {
        premioFinal = PremioGanado(
          nombre: _premioSeleccionado!.recompensa,
          descripcion: _premioSeleccionado!.nombre,
          cantidad: 1,
          rangoId: _premioSeleccionado!.id ?? '',
          montoMinimo: 0,
        );
      } else {
        premioFinal = _premioCalculado;
      }

      final ticket = TicketCanje(
        asignacionId: widget.asignacion.id,
        marcaId: _marcaSeleccionada!.id ?? '',
        marcaNombre: _marcaSeleccionada!.nombre,
        monto: monto,
        latitud: _ubicacion?.lat,
        longitud: _ubicacion?.lng,
        fecha: DateTime.now(),
        premioGanado: premioFinal,
      );

      await provider.registrarTicketCanje(ticket, _fotoTicket!);

      if (mounted) {
        _mostrarExito();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar ticket: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  void _mostrarExito() {
    // Determinar el premio a mostrar
    final premioAMostrar = widget.esCanjeDinamica ? _premioSeleccionado : null;
    final premioCalculadoAMostrar = widget.esCanjeDinamica ? null : _premioCalculado;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 64),
            ),
            const SizedBox(height: 16),
            const Text(
              '¡Ticket Registrado!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Mostrar premio seleccionado para canje_dinamica
            if (premioAMostrar != null) ...[
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                    const SizedBox(height: 8),
                    const Text(
                      '¡Premio Entregado!',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      premioAMostrar.recompensa,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      premioAMostrar.nombre,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else if (premioCalculadoAMostrar != null) ...[
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
                    const SizedBox(height: 8),
                    const Text(
                      '¡Felicidades! Premio Ganado:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      premioCalculadoAMostrar.nombre,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (premioCalculadoAMostrar.descripcion != null &&
                        premioCalculadoAMostrar.descripcion!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          premioCalculadoAMostrar.descripcion!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Entrega el premio al cliente',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange[700],
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (!widget.esCanjeDinamica) ...[
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600], size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'Sin premio para este monto',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'El monto del ticket no alcanza para obtener un premio. Revisa los rangos de premios disponibles.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Cerrar dialog
              Navigator.of(context).pop(); // Volver a pantalla anterior
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final marcas = widget.asignacion.camp?.marcas ?? [];

    // Auto-seleccionar si solo hay una marca
    if (marcas.length == 1 && _marcaSeleccionada == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _marcaSeleccionada = marcas.first;
          });
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Ticket'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Instructions card
              Card(
                color: Colors.orange.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long, color: Colors.orange[700], size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ticket de Canje',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Toma foto del ticket, selecciona la marca e ingresa el monto',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Brand selector (same style as labor de venta)
              _buildMarcaSelector(marcas),

              // Photo section (same style as labor de venta)
              _buildPhotoSection(),

              const SizedBox(height: 24),

              // Monto section
              _buildMontoSection(),

              const SizedBox(height: 24),

              // Location section (same style as labor de venta)
              _buildLocationSection(),

              const SizedBox(height: 24),

              // Para canje_dinamica: selector de premio manual
              if (widget.esCanjeDinamica && widget.configDinamica != null && widget.configDinamica!.isNotEmpty) ...[
                _buildPremioSelectorDinamica(),
                const SizedBox(height: 24),
              ],

              // Para canje_compra: premio calculado automáticamente
              if (!widget.esCanjeDinamica && _premioCalculado != null) ...[
                _buildPremioSection(),
                const SizedBox(height: 24),
              ],

              // Rangos de premios disponibles (solo para canje_compra)
              if (!widget.esCanjeDinamica && _configCanjeActiva != null && _configCanjeActiva!.rangos.isNotEmpty) ...[
                _buildRangosSection(),
                const SizedBox(height: 24),
              ],

              // Submit button
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _guardando ? null : _guardarTicket,
                  icon: _guardando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    _guardando ? 'Guardando...' : 'Guardar Ticket',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarcaSelector(List<MarcaCampania> marcas) {
    if (marcas.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selecciona la Marca',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Elige la marca del producto comprado',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: marcas.map((marca) {
            final isSelected = _marcaSeleccionada?.id == marca.id;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _marcaSeleccionada = marca;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue[50] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.check_circle,
                          size: 20,
                          color: Colors.blue[600],
                        ),
                      ),
                    Text(
                      marca.nombre,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? Colors.blue[700] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto del Ticket',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_fotoTicket != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _fotoTicket!,
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => setState(() => _fotoTicket = null),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
            ],
          )
        else
          GestureDetector(
            onTap: _tomarFoto,
            child: Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 2,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      size: 40,
                      color: Colors.orange[400],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tomar Foto',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Toca para abrir la cámara',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMontoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Monto del Ticket',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ingresa el monto total del ticket de compra',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _montoController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            prefixText: _configCanjeActiva?.simboloMoneda ?? '\$ ',
            prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            hintText: '0.00',
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Ingresa el monto del ticket';
            }
            final monto = double.tryParse(value.replaceAll(',', '.'));
            if (monto == null || monto <= 0) {
              return 'Ingresa un monto valido';
            }
            return null;
          },
          onChanged: (value) => _calcularPremio(),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _ubicacion != null
                    ? Colors.green.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: _obteniendoUbicacion
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.location_on,
                      color: _ubicacion != null ? Colors.green : Colors.grey,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ubicación GPS',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  if (_obteniendoUbicacion)
                    const Text('Obteniendo ubicación...')
                  else if (_ubicacion != null)
                    Text(
                      '${_ubicacion!.lat.toStringAsFixed(6)}, ${_ubicacion!.lng.toStringAsFixed(6)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    )
                  else if (_locationError != null)
                    Text(
                      _locationError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    )
                  else
                    const Text('No disponible'),
                ],
              ),
            ),
            if (_locationError != null)
              IconButton(
                onPressed: _obtenerUbicacion,
                icon: const Icon(Icons.refresh),
                tooltip: 'Reintentar',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremioSection() {
    return Card(
      color: Colors.amber.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.amber, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.emoji_events, color: Colors.amber, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Premio a entregar:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  Text(
                    _premioCalculado!.nombre,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  if (_premioCalculado!.descripcion != null &&
                      _premioCalculado!.descripcion!.isNotEmpty)
                    Text(
                      _premioCalculado!.descripcion!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rangos de Premios',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Premios disponibles según el monto de compra',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        ..._configCanjeActiva!.rangos.map((rango) {
          final premioNombre = rango.premios.isNotEmpty
              ? rango.premios.first.nombre
              : 'Sin premio';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      rango.rangoLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.arrow_forward, size: 16, color: Colors.grey[400]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      premioNombre,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPremioSelectorDinamica() {
    final dinamicas = widget.configDinamica ?? [];
    if (dinamicas.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber[700], size: 24),
            const SizedBox(width: 8),
            const Text(
              'Selecciona el Premio',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Elige el premio que entregaste al cliente',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 12),
        ...dinamicas.map((dinamica) {
          final isSelected = _premioSeleccionado?.id == dinamica.id;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _premioSeleccionado = dinamica;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.amber.withOpacity(0.1) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.amber : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.amber.withOpacity(0.2) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getIconForTipoRecompensa(dinamica.tipoRecompensa),
                        color: isSelected ? Colors.amber[700] : Colors.grey[600],
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dinamica.recompensa,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.amber[800] : Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dinamica.nombre,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (dinamica.descripcion.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              dinamica.descripcion,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  IconData _getIconForTipoRecompensa(String tipo) {
    switch (tipo) {
      case 'producto':
        return Icons.shopping_bag;
      case 'descuento':
        return Icons.discount;
      default:
        return Icons.card_giftcard;
    }
  }
}
