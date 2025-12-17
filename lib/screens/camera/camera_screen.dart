import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_theme.dart';

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

      for (int i = 0; i < _cameras.length; i++) {
        debugPrint('📷 [CameraScreen] Camera $i: ${_cameras[i].name} - ${_cameras[i].lensDirection}');
      }

      if (_cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No se encontraron cámaras disponibles';
        });
        return;
      }

      // Find the back camera (prefer wide angle over telephoto/ultra-wide)
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
      debugPrint('📷 [CameraScreen] Camera initialized successfully');

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
      debugPrint('📷 [CameraScreen] Taking picture...');
      final XFile photo = await _controller!.takePicture();
      debugPrint('📷 [CameraScreen] Picture taken: ${photo.path}');

      // Copy to app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = '${appDir.path}/$fileName';

      await File(photo.path).copy(savedPath);
      debugPrint('📷 [CameraScreen] Photo saved to: $savedPath');

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
        // Optionally delete the file
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera preview
            if (_isInitialized && _controller != null)
              Center(
                child: AspectRatio(
                  aspectRatio: 1 / _controller!.value.aspectRatio,
                  child: CameraPreview(_controller!),
                ),
              )
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 64,
                      ),
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
                    // Photo counter
                    if (_capturedPhotos.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
