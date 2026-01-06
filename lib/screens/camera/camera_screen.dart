import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

class CameraScreen extends StatefulWidget {
  final int maxPhotos;

  const CameraScreen({
    super.key,
    this.maxPhotos = 10,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isTakingPicture = false;
  String? _errorMessage;
  int _selectedCameraIndex = 0;
  final List<String> _capturedPhotos = [];

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
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      debugPrint('📷 [CameraScreen] Getting available cameras...');
      _cameras = await availableCameras();
      debugPrint('📷 [CameraScreen] Found ${_cameras.length} cameras');

      if (_cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No se encontraron cámaras disponibles';
        });
        return;
      }

      // Find the back camera
      int backCameraIndex = _cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );

      if (backCameraIndex == -1) {
        backCameraIndex = 0;
      }

      _selectedCameraIndex = backCameraIndex;
      await _setupCamera(_cameras[_selectedCameraIndex]);
    } catch (e) {
      debugPrint('❌ [CameraScreen] Error initializing camera: $e');
      setState(() {
        _errorMessage = 'Error al inicializar cámara: $e';
      });
    }
  }

  Future<void> _setupCamera(CameraDescription camera) async {
    debugPrint('📷 [CameraScreen] Setting up camera: ${camera.name}');

    _controller?.dispose();

    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();

      // Get zoom limits
      _minZoom = await _controller!.getMinZoomLevel();
      _maxZoom = await _controller!.getMaxZoomLevel();
      _currentZoom = 1.0.clamp(_minZoom, _maxZoom);
      await _controller!.setZoomLevel(_currentZoom);

      debugPrint('📷 [CameraScreen] Camera initialized. Zoom: $_minZoom - $_maxZoom');

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('❌ [CameraScreen] Error setting up camera: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al configurar cámara: $e';
        });
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

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isTakingPicture) {
      return;
    }

    if (_capturedPhotos.length >= widget.maxPhotos) {
      setState(() => _errorMessage = 'Máximo ${widget.maxPhotos} fotos');
      return;
    }

    setState(() => _isTakingPicture = true);

    try {
      final XFile photo = await _controller!.takePicture();

      // Copy to app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = '${appDir.path}/$fileName';

      await File(photo.path).copy(savedPath);

      if (mounted) {
        setState(() {
          _capturedPhotos.add(savedPath);
          _isTakingPicture = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [CameraScreen] Error taking picture: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al tomar foto: $e';
          _isTakingPicture = false;
        });
      }
    }
  }

  void _finishCapture() {
    if (_capturedPhotos.isEmpty) {
      Navigator.pop(context);
    } else {
      Navigator.pop(context, _capturedPhotos);
    }
  }

  void _removeLastPhoto() {
    if (_capturedPhotos.isNotEmpty) {
      setState(() {
        final lastPath = _capturedPhotos.removeLast();
        try {
          File(lastPath).deleteSync();
        } catch (e) {
          debugPrint('📷 [CameraScreen] Could not delete file: $e');
        }
      });
    }
  }

  void _switchCamera() async {
    if (_cameras.length < 2) return;

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _setupCamera(_cameras[_selectedCameraIndex]);
  }

  // Build zoom preset button (iPhone style)
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
              GestureDetector(
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
              )
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _initializeCamera,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(180),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: _finishCapture,
                    ),
                    // Flash button
                    if (_isInitialized)
                      GestureDetector(
                        onTap: _toggleFlash,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_getFlashIcon(), color: Colors.white, size: 24),
                        ),
                      ),
                    Row(
                      children: [
                        // Photo counter
                        if (_capturedPhotos.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(30),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_capturedPhotos.length}/${widget.maxPhotos}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        if (_cameras.length > 1)
                          IconButton(
                            icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 28),
                            onPressed: _switchCamera,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom bar with capture button and thumbnails
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withAlpha(200),
                      Colors.black.withAlpha(100),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Zoom presets (iPhone style)
                    if (_isInitialized && _maxZoom > _minZoom)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
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
                    // Thumbnails row
                    if (_capturedPhotos.isNotEmpty)
                      Container(
                        height: 60,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _capturedPhotos.length,
                          itemBuilder: (ctx, index) {
                            return Stack(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.file(
                                      File(_capturedPhotos[index]),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                if (index == _capturedPhotos.length - 1)
                                  Positioned(
                                    top: -4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: _removeLastPhoto,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    // Capture button row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Done button (left side)
                        SizedBox(
                          width: 80,
                          child: _capturedPhotos.isNotEmpty
                              ? GestureDetector(
                                  onTap: _finishCapture,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'Listo',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        // Capture button (center)
                        GestureDetector(
                          onTap: _isInitialized && !_isTakingPicture ? _takePicture : null,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              color: _isTakingPicture ? Colors.grey : Colors.transparent,
                            ),
                            child: _isTakingPicture
                                ? const Center(
                                    child: SizedBox(
                                      width: 30,
                                      height: 30,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : Container(
                                    margin: const EdgeInsets.all(8),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        // Spacer (right side)
                        const SizedBox(width: 80),
                      ],
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
}
