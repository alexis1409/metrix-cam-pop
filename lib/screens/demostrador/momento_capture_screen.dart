import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/asignacion_rtmt.dart';
import '../../providers/demostrador_provider.dart';
import 'cierre_cuestionario_screen.dart';

class MomentoCaptureScreen extends StatefulWidget {
  final MomentoRTMT momento;
  final bool isCorrection;

  const MomentoCaptureScreen({
    super.key,
    required this.momento,
    this.isCorrection = false,
  });

  @override
  State<MomentoCaptureScreen> createState() => _MomentoCaptureScreenState();
}

class _MomentoCaptureScreenState extends State<MomentoCaptureScreen> {
  File? _photo;
  Ubicacion? _ubicacion;
  final _notasController = TextEditingController();
  bool _isLoading = false;
  bool _isGettingLocation = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  @override
  void dispose() {
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() {
      _isGettingLocation = true;
      _locationError = null;
    });

    try {
      // Check permission
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

      // Get position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _ubicacion = Ubicacion(
          lat: position.latitude,
          lng: position.longitude,
        );
        _isGettingLocation = false;
      });
    } catch (e) {
      setState(() {
        _locationError = e.toString();
        _isGettingLocation = false;
      });
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _photo = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _photo = File(pickedFile.path);
      });
    }
  }

  Future<void> _submit() async {
    if (_photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor toma una foto')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final provider = context.read<DemostradorProvider>();

    bool success;
    if (widget.isCorrection) {
      success = await provider.corregirIncidencia(
        momento: widget.momento,
        nuevaFoto: _photo,
        ubicacion: _ubicacion,
        notas: _notasController.text.isNotEmpty ? _notasController.text : null,
      );
    } else {
      // If it's cierre, navigate to questionnaire
      if (widget.momento == MomentoRTMT.cierreActividades) {
        setState(() => _isLoading = false);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => CierreCuestionarioScreen(
                foto: _photo!,
                ubicacion: _ubicacion,
                notas: _notasController.text.isNotEmpty ? _notasController.text : null,
              ),
            ),
          );
        }
        return;
      }

      success = await provider.registrarMomento(
        momento: widget.momento,
        foto: _photo,
        ubicacion: _ubicacion,
        notas: _notasController.text.isNotEmpty ? _notasController.text : null,
      );
    }

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isCorrection
              ? 'Incidencia corregida'
              : '${widget.momento.label} registrado'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Error al registrar'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isCorrection
            ? 'Corregir ${widget.momento.label}'
            : widget.momento.label),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Instructions card
            Card(
              color: widget.momento.color.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(widget.momento.icon, color: widget.momento.color, size: 32),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.momento.label,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: widget.momento.color,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getInstructions(),
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

            // Photo section
            _buildPhotoSection(),

            const SizedBox(height: 24),

            // Location section
            _buildLocationSection(),

            const SizedBox(height: 24),

            // Notes section
            TextField(
              controller: _notasController,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                border: OutlineInputBorder(),
                hintText: 'Agrega comentarios adicionales...',
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
                    : const Icon(Icons.check),
                label: Text(
                  _isLoading
                      ? 'Guardando...'
                      : (widget.isCorrection ? 'Corregir' : 'Registrar ${widget.momento.shortLabel}'),
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.momento.color,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInstructions() {
    switch (widget.momento) {
      case MomentoRTMT.inicioActividades:
        return 'Toma una foto al iniciar tus actividades en la tienda';
      case MomentoRTMT.laborVenta:
        return 'Registra un momento de tu labor de venta';
      case MomentoRTMT.cierreActividades:
        return 'Toma una foto y completa el cuestionario de cierre';
    }
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Evidencia Fotográfica',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_photo != null)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _photo!,
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => setState(() => _photo = null),
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
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[400]!, style: BorderStyle.solid),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt, size: 48, color: Colors.grey[500]),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _takePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Cámara'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Galería'),
                    ),
                  ],
                ),
              ],
            ),
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
              child: _isGettingLocation
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
                  if (_isGettingLocation)
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
                onPressed: _getLocation,
                icon: const Icon(Icons.refresh),
                tooltip: 'Reintentar',
              ),
          ],
        ),
      ),
    );
  }
}
