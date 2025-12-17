import 'package:flutter/foundation.dart';
import '../models/campania.dart';
import '../models/tienda_pendiente.dart';
import '../services/api_service.dart';
import '../services/campania_service.dart';

enum CampaniaStatus {
  initial,
  loading,
  loaded,
  error,
}

class CampaniaProvider extends ChangeNotifier {
  final CampaniaService _campaniaService;

  CampaniaStatus _status = CampaniaStatus.initial;
  List<TiendaPendiente> _tiendasPendientes = [];
  List<Campania> _campanias = [];
  Campania? _selectedCampania;
  TiendaPendiente? _selectedTienda;
  String? _errorMessage;
  bool _isUsingCachedData = false;
  DateTime? _cacheTime;

  CampaniaProvider(this._campaniaService);

  CampaniaStatus get status => _status;
  List<TiendaPendiente> get tiendasPendientes => _tiendasPendientes;
  List<Campania> get campanias => _campanias;
  Campania? get selectedCampania => _selectedCampania;
  TiendaPendiente? get selectedTienda => _selectedTienda;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == CampaniaStatus.loading;
  bool get isUsingCachedData => _isUsingCachedData;
  DateTime? get cacheTime => _cacheTime;

  Future<void> loadTiendasPendientes(String userId, {bool forceRefresh = false}) async {
    _status = CampaniaStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _campaniaService.getTiendasPendientesOfflineFirst(
        userId,
        forceRefresh: forceRefresh,
      );
      _tiendasPendientes = result.data;
      _isUsingCachedData = result.fromCache;
      _cacheTime = result.cacheTime;
      _status = CampaniaStatus.loaded;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = CampaniaStatus.error;
    } catch (e) {
      _errorMessage = 'Error al cargar tiendas: $e';
      _status = CampaniaStatus.error;
    }

    notifyListeners();
  }

  Future<void> loadCampaniasByInstalador(String userId) async {
    _status = CampaniaStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _campanias = await _campaniaService.getCampaniasByInstalador(userId);
      _status = CampaniaStatus.loaded;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = CampaniaStatus.error;
    } catch (e) {
      _errorMessage = 'Error al cargar campañas: $e';
      _status = CampaniaStatus.error;
    }

    notifyListeners();
  }

  Future<void> loadCampaniaById(String id) async {
    _status = CampaniaStatus.loading;
    notifyListeners();

    try {
      _selectedCampania = await _campaniaService.getCampaniaById(id);
      _status = CampaniaStatus.loaded;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = CampaniaStatus.error;
    } catch (e) {
      _errorMessage = 'Error al cargar campaña: $e';
      _status = CampaniaStatus.error;
    }

    notifyListeners();
  }

  void selectCampania(Campania campania) {
    _selectedCampania = campania;
    notifyListeners();
  }

  void selectTienda(TiendaPendiente tienda) {
    _selectedTienda = tienda;
    notifyListeners();
  }

  void clearSelection() {
    _selectedCampania = null;
    _selectedTienda = null;
    notifyListeners();
  }

  Future<bool> actualizarEstadoDetalle(
    String campaniaId,
    int detalleIndex,
    String nuevoEstado,
  ) async {
    try {
      await _campaniaService.actualizarEstadoDetalle(
        campaniaId,
        detalleIndex,
        nuevoEstado,
      );
      return true;
    } catch (e) {
      _errorMessage = 'Error al actualizar estado: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> agregarEvidencias(
    String campaniaId,
    int detalleIndex,
    String fase,
    List<String> evidencias,
  ) async {
    try {
      await _campaniaService.agregarEvidencias(
        campaniaId,
        detalleIndex,
        fase,
        evidencias,
      );
      return true;
    } catch (e) {
      _errorMessage = 'Error al agregar evidencias: $e';
      notifyListeners();
      return false;
    }
  }

  // Filtros por estado
  List<TiendaPendiente> get tiendasPorAlta =>
      _tiendasPendientes.where((t) => t.estadoDetalle == 'pendiente' || t.estadoDetalle == 'alta').toList();

  List<TiendaPendiente> get tiendasPorSupervision =>
      _tiendasPendientes.where((t) => t.estadoDetalle == 'supervision').toList();

  List<TiendaPendiente> get tiendasPorBaja =>
      _tiendasPendientes.where((t) => t.estadoDetalle == 'baja').toList();
}
