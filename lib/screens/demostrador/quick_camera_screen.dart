import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class QuickCameraScreen extends StatefulWidget {
  const QuickCameraScreen({super.key});

  @override
  State<QuickCameraScreen> createState() => _QuickCameraScreenState();
}

class _QuickCameraScreenState extends State<QuickCameraScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;

  // Zoom controls
  double _currentZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _baseZoom = 1.0;

  // Flash control
  FlashMode _flashMode = FlashMode.off;

  // Zoom presets for quick access
  List<double> get _zoomPresets {
    final presets = <double>[];
    // Add 0.5x if available (ultra wide)
    if (_minZoom <= 0.6) presets.add(0.5);
    // Always add 1x
    presets.add(1.0);
    // Add 2x if available
    if (_maxZoom >= 2.0) presets.add(2.0);
    // Add 5x if available
    if (_maxZoom >= 5.0) presets.add(5.0);
    return presets;
  }

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se encontró cámara')),
          );
        }
        return;
      }

      // Use back camera
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.max, // Máxima resolución disponible
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      // Get zoom limits
      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();
      _currentZoom = 1.0.clamp(_minZoom, _maxZoom);
      await _controller!.setZoomLevel(_currentZoom);

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al iniciar cámara: $e')),
        );
      }
    }
  }

  // Zoom methods
  Future<void> _setZoom(double zoom) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final newZoom = zoom.clamp(_minZoom, _maxZoom);
    await _controller!.setZoomLevel(newZoom);
    setState(() => _currentZoom = newZoom);
  }

  void _onScaleStart(ScaleStartDetails details) {
    _baseZoom = _currentZoom;
  }

  Future<void> _onScaleUpdate(ScaleUpdateDetails details) async {
    final newZoom = _baseZoom * details.scale;
    await _setZoom(newZoom);
  }

  // Flash methods
  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    FlashMode newMode;
    switch (_flashMode) {
      case FlashMode.off:
        newMode = FlashMode.auto;
        break;
      case FlashMode.auto:
        newMode = FlashMode.always;
        break;
      case FlashMode.always:
        newMode = FlashMode.torch;
        break;
      case FlashMode.torch:
        newMode = FlashMode.off;
        break;
    }

    await _controller!.setFlashMode(newMode);
    setState(() => _flashMode = newMode);
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.torch:
        return Icons.highlight;
    }
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) {
      return;
    }

    setState(() => _isCapturing = true);

    try {
      final XFile photo = await _controller!.takePicture();

      // Return original photo without compression
      if (mounted) {
        Navigator.pop(context, File(photo.path));
      }
    } catch (e) {
      setState(() => _isCapturing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al capturar: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // Build zoom preset button
  Widget _buildZoomButton(double zoom) {
    final isSelected = (_currentZoom - zoom).abs() < 0.1;
    final isAvailable = zoom >= _minZoom && zoom <= _maxZoom;

    String label;
    if (zoom < 1) {
      label = '.${(zoom * 10).toInt()}';
    } else {
      label = zoom.toInt().toString();
    }

    return GestureDetector(
      onTap: isAvailable ? () => _setZoom(zoom) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: isSelected ? 45 : 35,
        height: isSelected ? 45 : 35,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? Colors.amber.withOpacity(0.3) : Colors.transparent,
        ),
        child: Center(
          child: Text(
            isSelected ? '${zoom}x' : label,
            style: TextStyle(
              color: isSelected ? Colors.amber : (isAvailable ? Colors.white : Colors.white38),
              fontSize: isSelected ? 14 : 16,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera preview con proporción 4:3 y zoom con pellizco
            if (_isInitialized && _controller != null)
              Positioned.fill(
                child: GestureDetector(
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: _onScaleUpdate,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 3 / 4, // Proporción 4:3 en vertical
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _controller!.value.previewSize?.height ?? 1,
                              height: _controller!.value.previewSize?.width ?? 1,
                              child: CameraPreview(_controller!),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // Top bar with close button and flash
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Close button
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black45,
                    ),
                  ),
                  // Flash button
                  if (_isInitialized)
                    GestureDetector(
                      onTap: _toggleFlash,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_getFlashIcon(), color: Colors.white, size: 24),
                      ),
                    ),
                ],
              ),
            ),

            // Zoom presets (iPhone style) - above capture button
            if (_isInitialized && _maxZoom > _minZoom)
              Positioned(
                bottom: 150,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _zoomPresets.map((zoom) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: _buildZoomButton(zoom),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

            // Capture button
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _isCapturing ? null : _capturePhoto,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Center(
                      child: _isCapturing
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            )
                          : Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
