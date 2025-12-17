import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart';
import '../camera/camera_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../models/clave.dart';
import '../../models/local_photo.dart';
import '../../models/tienda_pendiente.dart';
import '../../providers/photo_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/api_service.dart';
import '../../services/claves_cache_service.dart';
import '../../services/evidence_upload_service.dart';
import '../../services/location_service.dart';
import '../../services/watermark_service.dart';

class UploadEvidenceScreen extends StatefulWidget {
  final TiendaPendiente tiendaPendiente;

  const UploadEvidenceScreen({
    super.key,
    required this.tiendaPendiente,
  });

  @override
  State<UploadEvidenceScreen> createState() => _UploadEvidenceScreenState();
}

class _UploadEvidenceScreenState extends State<UploadEvidenceScreen> {
  final List<File> _selectedPhotos = [];
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _notasController = TextEditingController();
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isNearStore = false;
  double? _distanceToStore;
  String? _errorMessage;

  List<Clave> _claves = [];
  bool _isLoadingClaves = false;
  bool _clavesLoadError = false;
  String _clavesErrorMessage = '';
  bool _isUsingCachedClaves = false;
  Clave? _selectedClave;
  final ClavesCacheService _clavesCache = ClavesCacheService();
  final WatermarkService _watermarkService = WatermarkService();
  Position? _currentPosition;

  bool get _isDesktop => Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  bool get _requiresNotas => _selectedClave?.isNegativo ?? false;

  @override
  void initState() {
    super.initState();
    _checkDistanceToStore();
    _loadClaves();
  }

  @override
  void dispose() {
    _notasController.dispose();
    super.dispose();
  }

  Future<void> _loadClaves() async {
    setState(() => _isLoadingClaves = true);

    final medioId = widget.tiendaPendiente.medio.id;
    debugPrint('🔑 Loading claves for medio: $medioId (${widget.tiendaPendiente.medio.nombre})');

    try {
      final apiService = context.read<ApiService>();
      final data = await apiService.getList('/claves/medio/$medioId?includeGeneric=true');

      debugPrint('🔑 API returned ${data.length} claves');

      final claves = data.map((json) => Clave.fromJson(json)).toList();
      claves.sort((a, b) => a.orden.compareTo(b.orden));

      // Cache for offline use
      if (claves.isNotEmpty) {
        await _clavesCache.cacheClaves(medioId, claves);
      }

      setState(() {
        _claves = claves;
        _clavesLoadError = false;
        _isUsingCachedClaves = false;
      });
    } catch (e) {
      debugPrint('🔑 Error loading claves: $e');

      // Try to load from cache
      final cachedClaves = await _clavesCache.getCachedClaves(medioId);

      if (cachedClaves != null && cachedClaves.isNotEmpty) {
        debugPrint('🔑 Using ${cachedClaves.length} cached claves');
        setState(() {
          _claves = cachedClaves;
          _clavesLoadError = false;
          _isUsingCachedClaves = true;
        });
      } else {
        setState(() {
          _clavesLoadError = true;
          _clavesErrorMessage = _getFriendlyErrorMessage(e);
          _isUsingCachedClaves = false;
        });
      }
    } finally {
      setState(() => _isLoadingClaves = false);
    }
  }

  String _getFriendlyErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('socketexception') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('network is unreachable') ||
        errorStr.contains('no internet')) {
      return 'Sin conexión a internet';
    }

    if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
      return 'El servidor tardó demasiado en responder';
    }

    if (errorStr.contains('404')) {
      return 'No se encontraron claves para este medio';
    }

    if (errorStr.contains('401') || errorStr.contains('403')) {
      return 'Sesión expirada, por favor inicia sesión de nuevo';
    }

    if (errorStr.contains('500') || errorStr.contains('502') || errorStr.contains('503')) {
      return 'El servidor no está disponible temporalmente';
    }

    return 'No se pudieron cargar las claves';
  }

  Future<void> _checkDistanceToStore() async {
    setState(() => _isLoading = true);

    // Capture settings before async gap
    final settings = context.read<SettingsProvider>();
    final maxDistance = settings.distanciaMaximaMetros;

    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentPosition();

      if (position != null && widget.tiendaPendiente.tienda.hasCoordinates) {
        final distance = locationService.calculateDistance(
          position.latitude,
          position.longitude,
          widget.tiendaPendiente.tienda.latitud!,
          widget.tiendaPendiente.tienda.longitud!,
        );

        setState(() {
          _currentPosition = position;
          _distanceToStore = distance;
          _isNearStore = distance <= maxDistance;
        });
      } else {
        setState(() {
          _currentPosition = position;
          _isNearStore = false;
          _distanceToStore = null;
        });
      }
    } catch (e) {
      setState(() {
        _isNearStore = false;
        _errorMessage = 'No se pudo obtener ubicación';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _takePhoto() async {
    if (!_isNearStore && !_isDesktop) {
      _showDistanceWarning();
      return;
    }

    try {
      List<String> imagePaths = [];

      if (_isDesktop) {
        const XTypeGroup imageTypeGroup = XTypeGroup(
          label: 'images',
          extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
        );
        final XFile? file = await openFile(acceptedTypeGroups: [imageTypeGroup]);
        if (file != null) {
          imagePaths = [file.path];
        }
      } else {
        // Use custom camera screen for better multi-camera support
        // Returns List<String> for multiple photos
        debugPrint('📷 [Camera] Opening custom camera screen...');
        final remainingSlots = 10 - _selectedPhotos.length;
        final result = await Navigator.push<dynamic>(
          context,
          MaterialPageRoute(
            builder: (context) => CameraScreen(maxPhotos: remainingSlots),
          ),
        );
        debugPrint('📷 [Camera] Camera result: $result');

        if (result is List<String>) {
          imagePaths = result;
        } else if (result is String) {
          // Backwards compatibility for single photo
          imagePaths = [result];
        }
      }

      if (imagePaths.isNotEmpty) {
        for (final imagePath in imagePaths) {
          // Add watermark to each photo
          final watermarkedPath = await _addWatermarkToPhoto(imagePath);
          _selectedPhotos.add(File(watermarkedPath));
        }
        setState(() {});
      }
    } catch (e) {
      debugPrint('❌ [TakePhoto] Error: $e');
      if (mounted) {
        setState(() => _errorMessage = 'Error al tomar foto: $e');
      }
    }
  }

  Future<String> _addWatermarkToPhoto(String imagePath) async {
    try {
      final settings = context.read<SettingsProvider>();
      final watermarkConfig = settings.watermarkConfig;

      // Check if watermark is enabled
      if (!watermarkConfig.habilitado) {
        debugPrint('Watermark disabled by configuration');
        return imagePath;
      }

      final tienda = widget.tiendaPendiente.tienda;

      final watermarkData = WatermarkData(
        storeName: tienda.nombre,
        storeId: tienda.determinante,
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        config: watermarkConfig,
      );

      final watermarkedPath = await _watermarkService.addWatermark(imagePath, watermarkData);
      debugPrint('Watermark added successfully: $watermarkedPath');
      return watermarkedPath;
    } catch (e) {
      debugPrint('Error adding watermark: $e');
      // If watermark fails, return original image
      return imagePath;
    }
  }

  void _showDistanceWarning() {
    final settings = context.read<SettingsProvider>();
    final maxDistance = settings.distanciaMaximaMetros;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.location_off_rounded, color: AppColors.warning),
            ),
            const SizedBox(width: 12),
            const Text('Muy lejos'),
          ],
        ),
        content: Text(
          'Estás a ${_distanceToStore?.toInt() ?? '?'}m de la tienda. '
          'Debes estar a menos de ${maxDistance}m para tomar fotos nuevas.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showPhotoSourceSelector() {
    final settings = context.read<SettingsProvider>();
    final maxDistance = settings.distanciaMaximaMetros;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PhotoSourceSheet(
        tiendaId: widget.tiendaPendiente.tienda.id,
        canTakePhoto: _isNearStore || _isDesktop,
        distanceToStore: _distanceToStore,
        maxDistance: maxDistance,
        onTakePhoto: () {
          Navigator.pop(ctx);
          _takePhoto();
        },
        onSelectFromGallery: (photos) {
          debugPrint('📸 [UploadEvidence] onSelectFromGallery called with ${photos.length} photos');
          // Add photos to the list
          for (final photo in photos) {
            debugPrint('📸 [UploadEvidence] Adding photo: ${photo.filePath}');
            final file = File(photo.filePath);
            if (file.existsSync()) {
              _selectedPhotos.add(file);
              debugPrint('📸 [UploadEvidence] File exists, added!');
            } else {
              debugPrint('❌ [UploadEvidence] File does NOT exist: ${photo.filePath}');
            }
          }
          debugPrint('📸 [UploadEvidence] Total selected photos: ${_selectedPhotos.length}');
          setState(() {});
          // Note: Navigator.pop is NOT needed here because _LocalPhotoSelectorScreen already closes itself
        },
      ),
    );
  }

  void _removePhoto(int index) {
    setState(() {
      _selectedPhotos.removeAt(index);
    });
  }

  Future<void> _uploadEvidences() async {
    if (_selectedPhotos.isEmpty) {
      setState(() => _errorMessage = 'Selecciona al menos una foto');
      return;
    }

    if (_selectedClave == null) {
      setState(() => _errorMessage = 'Selecciona una clave');
      return;
    }

    if (_requiresNotas && _notasController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'El comentario es obligatorio para claves negativas');
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final apiService = context.read<ApiService>();
      final uploadService = EvidenceUploadService(apiService);

      final nextState = _getNextState();
      final notas = _notasController.text.trim().isNotEmpty ? _notasController.text.trim() : null;

      debugPrint('📤 [Upload] Starting upload...');
      debugPrint('📤 [Upload] Photos: ${_selectedPhotos.length}');
      debugPrint('📤 [Upload] CampaniaId: ${widget.tiendaPendiente.campania.id}');
      debugPrint('📤 [Upload] DetalleIndex: ${widget.tiendaPendiente.detalleIndex}');
      debugPrint('📤 [Upload] NextState: $nextState');
      debugPrint('📤 [Upload] ClaveId: ${_selectedClave!.id}');

      final success = await uploadService.uploadEvidenciasAndUpdateEstado(
        photos: _selectedPhotos,
        campaniaId: widget.tiendaPendiente.campania.id,
        detalleIndex: widget.tiendaPendiente.detalleIndex,
        fase: nextState,
        claveId: _selectedClave!.id,
        notas: notas,
      );

      debugPrint('📤 [Upload] Result: $success');

      if (success && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Evidencias subidas correctamente', style: TextStyle(fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        setState(() => _errorMessage = 'Error al subir evidencias');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  String _getNextState() {
    switch (widget.tiendaPendiente.estadoDetalle) {
      case 'pendiente':
        return 'alta';
      case 'alta':
        return 'supervision';
      case 'supervision':
        return 'baja';
      case 'baja':
        return 'completado';
      default:
        return 'alta';
    }
  }

  String _getNextStateLabel() {
    switch (widget.tiendaPendiente.estadoDetalle) {
      case 'pendiente':
        return 'Alta';
      case 'alta':
        return 'Supervisión';
      case 'supervision':
        return 'Baja';
      case 'baja':
        return 'Completado';
      default:
        return 'Alta';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildStoreInfo()),
          SliverToBoxAdapter(child: _buildLocationStatus()),
          SliverToBoxAdapter(child: _buildClaveSelector()),
          if (_selectedClave != null)
            SliverToBoxAdapter(child: _buildNotasField()),
          if (_errorMessage != null)
            SliverToBoxAdapter(child: _buildErrorMessage()),
          SliverToBoxAdapter(child: _buildPhotoGrid()),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomSheet: _selectedPhotos.isNotEmpty ? _buildBottomBar() : null,
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppShadows.small,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(60, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Subir Evidencias',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withAlpha(40),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Status: ${_getNextStateLabel()}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withAlpha(200),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoreInfo() {
    final tienda = widget.tiendaPendiente.tienda;
    final campania = widget.tiendaPendiente.campania;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.store_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tienda.nombre,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '#${tienda.determinante} · ${tienda.ciudad}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryStart.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: AppColors.secondaryStart,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        campania.nombre,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Estado actual: ${widget.tiendaPendiente.estadoLabel}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStatus() {
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppShadows.small,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Verificando ubicación...'),
          ],
        ),
      );
    }

    final isNear = _isNearStore || _isDesktop;
    final color = isNear ? AppColors.success : AppColors.warning;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isNear ? Icons.location_on_rounded : Icons.location_off_rounded,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isNear ? 'Cerca de la tienda' : 'Lejos de la tienda',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _distanceToStore != null
                      ? 'Estás a ${_distanceToStore!.toInt()}m'
                      : _isDesktop
                          ? 'Modo escritorio - Selecciona archivos'
                          : 'Ubicación no disponible',
                  style: TextStyle(
                    fontSize: 13,
                    color: color.withAlpha(200),
                  ),
                ),
              ],
            ),
          ),
          if (!isNear)
            TextButton(
              onPressed: _checkDistanceToStore,
              child: const Text('Reintentar'),
            ),
        ],
      ),
    );
  }

  Widget _buildClaveSelector() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.key_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selecciona una clave',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Indica el resultado de la visita',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingClaves)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_clavesLoadError)
            _buildClavesErrorWidget()
          else if (_claves.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.textMuted),
                  SizedBox(width: 12),
                  Text(
                    'No hay claves disponibles',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isUsingCachedClaves)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.info.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.info.withAlpha(40)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.offline_bolt_rounded,
                          size: 16,
                          color: AppColors.info.withAlpha(180),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Usando claves guardadas (modo offline)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.info.withAlpha(180),
                          ),
                        ),
                      ],
                    ),
                  ),
                DropdownButtonFormField<Clave>(
                  value: _selectedClave,
                  isExpanded: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    hintText: 'Selecciona una clave',
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.primaryStart,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  items: _claves.map((clave) {
                    return DropdownMenuItem<Clave>(
                      value: clave,
                      child: Row(
                        children: [
                          Icon(
                            clave.displayIcon,
                            size: 20,
                            color: clave.displayColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              clave.descripcion,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: clave.displayColor.withAlpha(20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              clave.isPositivo ? 'Positiva' : 'Negativa',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: clave.displayColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (Clave? newValue) {
                    setState(() {
                      _selectedClave = newValue;
                      if (!_requiresNotas) {
                        _notasController.clear();
                      }
                    });
                  },
                  selectedItemBuilder: (context) {
                    return _claves.map((clave) {
                      return Row(
                        children: [
                          Icon(
                            clave.displayIcon,
                            size: 20,
                            color: clave.displayColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              clave.descripcion,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: clave.displayColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildClavesErrorWidget() {
    final isOffline = _clavesErrorMessage.contains('conexión') ||
        _clavesErrorMessage.contains('internet');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOffline
            ? AppColors.warning.withAlpha(15)
            : AppColors.error.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOffline
              ? AppColors.warning.withAlpha(50)
              : AppColors.error.withAlpha(50),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isOffline
                      ? AppColors.warning.withAlpha(30)
                      : AppColors.error.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                  color: isOffline ? AppColors.warning : AppColors.error,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOffline ? 'Sin conexión' : 'Error al cargar',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isOffline ? AppColors.warning : AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _clavesErrorMessage,
                      style: TextStyle(
                        fontSize: 13,
                        color: (isOffline ? AppColors.warning : AppColors.error)
                            .withAlpha(180),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: _loadClaves,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
              style: TextButton.styleFrom(
                foregroundColor: isOffline ? AppColors.warning : AppColors.error,
                backgroundColor: isOffline
                    ? AppColors.warning.withAlpha(20)
                    : AppColors.error.withAlpha(20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotasField() {
    final isRequired = _requiresNotas;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.small,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isRequired
                      ? AppColors.warning.withAlpha(20)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.comment_rounded,
                  color: isRequired ? AppColors.warning : AppColors.textMuted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Comentario',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (isRequired) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withAlpha(20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Obligatorio',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isRequired
                          ? 'Explica por qué la clave es negativa'
                          : 'Agrega un comentario opcional',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notasController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Escribe tu comentario aquí...',
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isRequired ? AppColors.warning : AppColors.primaryStart,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withAlpha(50)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.error, size: 20),
            onPressed: () => setState(() => _errorMessage = null),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid() {
    if (_selectedPhotos.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_photo_alternate_rounded,
                size: 48,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No hay fotos seleccionadas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Toca el botón + para agregar fotos',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fotos seleccionadas (${_selectedPhotos.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (_selectedPhotos.length >= 10)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Máx. 10',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.warning,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _selectedPhotos.length,
            itemBuilder: (ctx, index) => _buildPhotoTile(index),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoTile(int index) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.small,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              _selectedPhotos[index],
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: () => _removePhoto(index),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(40),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFab() {
    if (_selectedPhotos.length >= 10) return const SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(bottom: _selectedPhotos.isNotEmpty ? 80 : 0),
      child: FloatingActionButton.extended(
        onPressed: _showPhotoSourceSelector,
        backgroundColor: Colors.transparent,
        elevation: 0,
        label: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryStart.withAlpha(80),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.add_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Agregar foto',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isUploading ? null : _uploadEvidences,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryStart,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isUploading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_upload_rounded),
                      const SizedBox(width: 10),
                      Text(
                        'Subir ${_selectedPhotos.length} ${_selectedPhotos.length == 1 ? 'foto' : 'fotos'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _PhotoSourceSheet extends StatelessWidget {
  final String tiendaId;
  final bool canTakePhoto;
  final double? distanceToStore;
  final int maxDistance;
  final VoidCallback onTakePhoto;
  final void Function(List<LocalPhoto>) onSelectFromGallery;

  const _PhotoSourceSheet({
    required this.tiendaId,
    required this.canTakePhoto,
    required this.distanceToStore,
    required this.maxDistance,
    required this.onTakePhoto,
    required this.onSelectFromGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Agregar fotos',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),

                // Take photo option
                _buildOption(
                  context,
                  icon: Icons.camera_alt_rounded,
                  title: 'Tomar foto',
                  subtitle: canTakePhoto
                      ? 'Usar la cámara'
                      : 'Debes estar a menos de ${maxDistance}m',
                  enabled: canTakePhoto,
                  gradient: AppColors.primaryGradient,
                  onTap: canTakePhoto ? onTakePhoto : null,
                ),

                const SizedBox(height: 12),

                // Gallery from store
                _buildOption(
                  context,
                  icon: Icons.photo_library_rounded,
                  title: 'Galería de esta tienda',
                  subtitle: 'Fotos ya tomadas para esta tienda',
                  enabled: true,
                  gradient: AppColors.secondaryGradient,
                  onTap: () => _selectFromLocalGallery(context, tiendaId),
                ),

                const SizedBox(height: 12),

                // Unknown gallery
                _buildOption(
                  context,
                  icon: Icons.help_outline_rounded,
                  title: 'Fotos sin asignar',
                  subtitle: 'Carpeta "Desconocidos"',
                  enabled: true,
                  gradient: LinearGradient(
                    colors: [Colors.grey.shade500, Colors.grey.shade700],
                  ),
                  onTap: () => _selectFromLocalGallery(context, 'desconocido'),
                ),

                SizedBox(height: MediaQuery.of(context).padding.bottom + 12),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    required Gradient gradient,
    VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (enabled)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                  if (!enabled)
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectFromLocalGallery(BuildContext context, String tiendaId) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _LocalPhotoSelectorScreen(
          tiendaId: tiendaId,
          onPhotosSelected: onSelectFromGallery,
        ),
      ),
    );
  }
}

class _LocalPhotoSelectorScreen extends StatefulWidget {
  final String tiendaId;
  final void Function(List<LocalPhoto>) onPhotosSelected;

  const _LocalPhotoSelectorScreen({
    required this.tiendaId,
    required this.onPhotosSelected,
  });

  @override
  State<_LocalPhotoSelectorScreen> createState() => _LocalPhotoSelectorScreenState();
}

class _LocalPhotoSelectorScreenState extends State<_LocalPhotoSelectorScreen> {
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    // Load photos when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PhotoProvider>().loadPhotos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final photoProvider = context.watch<PhotoProvider>();
    final photos = photoProvider.getPhotosForTienda(widget.tiendaId);

    debugPrint('📸 [LocalPhotoSelector] tiendaId: ${widget.tiendaId}');
    debugPrint('📸 [LocalPhotoSelector] photos count: ${photos.length}');
    debugPrint('📸 [LocalPhotoSelector] selected count: ${_selectedIds.length}');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          widget.tiendaId == 'desconocido' ? 'Fotos sin asignar' : 'Fotos de la tienda',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_selectedIds.isNotEmpty)
            TextButton(
              onPressed: () {
                debugPrint('📸 [LocalPhotoSelector] Agregar pressed!');
                debugPrint('📸 [LocalPhotoSelector] Selected IDs: $_selectedIds');
                final selectedPhotos = photos.where((p) => _selectedIds.contains(p.id)).toList();
                debugPrint('📸 [LocalPhotoSelector] Selected photos: ${selectedPhotos.length}');
                for (final p in selectedPhotos) {
                  debugPrint('📸 [LocalPhotoSelector] Photo: ${p.id} - ${p.filePath}');
                }
                widget.onPhotosSelected(selectedPhotos);
                Navigator.pop(context);
              },
              child: Text(
                'Agregar (${_selectedIds.length})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      body: photos.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay fotos disponibles',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: photos.length,
              itemBuilder: (ctx, index) {
                final photo = photos[index];
                final isSelected = _selectedIds.contains(photo.id);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedIds.remove(photo.id);
                      } else {
                        _selectedIds.add(photo.id);
                      }
                    });
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(photo.filePath),
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (isSelected)
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: AppColors.primaryStart.withAlpha(100),
                            border: Border.all(
                              color: AppColors.primaryStart,
                              width: 3,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
