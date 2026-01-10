import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/campania.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/retailtainment_service.dart';

enum RetailtainmentStatus {
  initial,
  loading,
  loaded,
  error,
  submitting,
  submitted,
}

class RetailtainmentProvider extends ChangeNotifier {
  final RetailtainmentService _service;

  RetailtainmentStatus _status = RetailtainmentStatus.initial;
  List<Campania> _campanias = [];
  Campania? _selectedCampania;
  Tienda? _selectedTienda;
  String? _errorMessage;
  User? _currentUser;
  List<Tienda> _tiendasAsignadas = []; // Tiendas from API for impulsador/supervisor

  RetailtainmentProvider(ApiService apiService)
      : _service = RetailtainmentService(apiService);

  // Getters
  RetailtainmentStatus get status => _status;
  List<Campania> get campanias => _campanias;
  Campania? get selectedCampania => _selectedCampania;
  Tienda? get selectedTienda => _selectedTienda;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == RetailtainmentStatus.loading;
  bool get isSubmitting => _status == RetailtainmentStatus.submitting;
  User? get currentUser => _currentUser;
  List<Tienda> get tiendasAsignadas => _tiendasAsignadas;

  // Role-based getters
  bool get isImpulsador => _currentUser?.isImpulsador ?? false;
  bool get isSupervisor => _currentUser?.isSupervisorRetailtainment ?? false;
  bool get hasRetailtainmentRole => _currentUser?.hasRetailtainmentRole ?? false;
  Agencia? get agencia => _currentUser?.agenciaRetailtainment;
  String get roleName => isImpulsador ? 'Impulsador' : (isSupervisor ? 'Supervisor' : 'Usuario');

  /// Set the current user for role-based filtering
  void setUser(User? user) {
    _currentUser = user;
    notifyListeners();
  }

  /// Load assigned stores for the user from API
  Future<void> loadTiendasAsignadas(String userId, {String? proyectoId}) async {
    if (!hasRetailtainmentRole) {
      _tiendasAsignadas = [];
      return;
    }

    try {
      debugPrint('🏪 [RetailtainmentProvider] Loading assigned stores for user: $userId');
      _tiendasAsignadas = await _service.getTiendasAsignadas(userId, proyectoId: proyectoId);
      debugPrint('🏪 [RetailtainmentProvider] Loaded ${_tiendasAsignadas.length} assigned stores');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [RetailtainmentProvider] Error loading assigned stores: $e');
      _tiendasAsignadas = [];
    }
  }

  /// Get only campaigns active today
  List<Campania> get campaniasActivasHoy => _campanias.where((c) {
    final now = DateTime.now();
    if (now.isBefore(c.fechaInicio) || now.isAfter(c.fechaFin)) {
      return false;
    }
    return c.esDiaActivoHoy;
  }).toList();

  /// Get campaigns by type
  List<Campania> getCampaniasByTipo(String tipo) =>
      _campanias.where((c) => c.tipoRetailtainment == tipo).toList();

  /// Load retailtainment campaigns for a user
  Future<void> loadCampanias(String userId) async {
    _status = RetailtainmentStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _campanias = await _service.getRetailtainmentCampanias(userId);
      _status = RetailtainmentStatus.loaded;
    } catch (e) {
      _errorMessage = 'Error al cargar campañas: $e';
      _status = RetailtainmentStatus.error;
    }
    notifyListeners();
  }

  /// Load a specific campaign with full details
  Future<void> loadCampaniaDetail(String campaniaId) async {
    _status = RetailtainmentStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _selectedCampania = await _service.getCampaniaById(campaniaId);
      _status = RetailtainmentStatus.loaded;
    } catch (e) {
      _errorMessage = 'Error al cargar detalle: $e';
      _status = RetailtainmentStatus.error;
    }
    notifyListeners();
  }

  /// Select a campaign
  void selectCampania(Campania campania) {
    _selectedCampania = campania;
    _selectedTienda = null;
    notifyListeners();
  }

  /// Select a store
  void selectTienda(Tienda tienda) {
    _selectedTienda = tienda;
    notifyListeners();
  }

  /// Clear selection
  void clearSelection() {
    _selectedCampania = null;
    _selectedTienda = null;
    notifyListeners();
  }

  /// Get stores for the selected campaign, filtered by user role
  /// Uses _tiendasAsignadas from API for impulsador/supervisor
  List<Tienda> get tiendasDisponibles {
    if (_selectedCampania == null) return [];
    final allTiendas = _service.getTiendasForCampania(_selectedCampania!);

    // If no user or no retailtainment role, return all stores from campaign
    if (_currentUser == null || !hasRetailtainmentRole) {
      return allTiendas;
    }

    // If we have assigned stores from API, filter campaign stores by them
    if (_tiendasAsignadas.isNotEmpty) {
      final assignedIds = _tiendasAsignadas.map((t) => t.id).toSet();
      return allTiendas.where((tienda) => assignedIds.contains(tienda.id)).toList();
    }

    // Fallback: filter by user's tiendasAsignadas (local)
    return allTiendas.where((tienda) =>
      _currentUser!.canAccessTienda(tienda.id)
    ).toList();
  }

  /// Get the single assigned store for impulsador (convenience getter)
  Tienda? get tiendaAsignadaImpulsador {
    if (!isImpulsador) return null;

    // First try from API-loaded tiendas
    if (_tiendasAsignadas.isNotEmpty) {
      return _tiendasAsignadas.first;
    }

    // Fallback to campaign tiendas
    if (_selectedCampania == null) return null;
    final tiendaId = _currentUser?.tiendaAsignadaImpulsador;
    if (tiendaId == null) return null;

    final allTiendas = _service.getTiendasForCampania(_selectedCampania!);
    return allTiendas.cast<Tienda?>().firstWhere(
      (t) => t?.id == tiendaId,
      orElse: () => null,
    );
  }

  /// Check if user can access a specific store
  bool canAccessTienda(String tiendaId) {
    // If we have API-loaded tiendas, use those
    if (_tiendasAsignadas.isNotEmpty) {
      return _tiendasAsignadas.any((t) => t.id == tiendaId);
    }
    // Fallback to user's local check
    return _currentUser?.canAccessTienda(tiendaId) ?? true;
  }

  /// Register a demonstration
  Future<bool> registrarDemostracion({
    required String tiendaId,
    String? notas,
    List<File>? photos,
  }) async {
    if (_selectedCampania == null) {
      _errorMessage = 'No hay campaña seleccionada';
      return false;
    }

    _status = RetailtainmentStatus.submitting;
    _errorMessage = null;
    notifyListeners();

    try {
      List<String>? evidencias;
      if (photos != null && photos.isNotEmpty) {
        evidencias = await _service.uploadEvidencias(photos);
      }

      await _service.registrarDemostracion(
        campaniaId: _selectedCampania!.id,
        tiendaId: tiendaId,
        notas: notas,
        evidencias: evidencias,
      );

      _status = RetailtainmentStatus.submitted;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al registrar demostración: $e';
      _status = RetailtainmentStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Register a purchase redemption
  Future<bool> registrarCanjeCompra({
    required String tiendaId,
    required double montoTicket,
    List<String>? upcsValidados,
    required List<Premio> premiosEntregados,
    String? notas,
    List<File>? photos,
  }) async {
    if (_selectedCampania == null) {
      _errorMessage = 'No hay campaña seleccionada';
      return false;
    }

    _status = RetailtainmentStatus.submitting;
    _errorMessage = null;
    notifyListeners();

    try {
      List<String>? evidencias;
      if (photos != null && photos.isNotEmpty) {
        evidencias = await _service.uploadEvidencias(photos);
      }

      await _service.registrarCanjeCompra(
        campaniaId: _selectedCampania!.id,
        tiendaId: tiendaId,
        montoTicket: montoTicket,
        upcsValidados: upcsValidados,
        premiosEntregados: premiosEntregados,
        notas: notas,
        evidencias: evidencias,
      );

      _status = RetailtainmentStatus.submitted;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al registrar canje: $e';
      _status = RetailtainmentStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Register a dynamic activity redemption
  Future<bool> registrarCanjeDinamica({
    required String tiendaId,
    required int dinamicaIndex,
    required String dinamicaNombre,
    required String recompensaEntregada,
    String? tipoRecompensa,
    String? notas,
    List<File>? photos,
  }) async {
    if (_selectedCampania == null) {
      _errorMessage = 'No hay campaña seleccionada';
      return false;
    }

    _status = RetailtainmentStatus.submitting;
    _errorMessage = null;
    notifyListeners();

    try {
      List<String>? evidencias;
      if (photos != null && photos.isNotEmpty) {
        evidencias = await _service.uploadEvidencias(photos);
      }

      await _service.registrarCanjeDinamica(
        campaniaId: _selectedCampania!.id,
        tiendaId: tiendaId,
        dinamicaIndex: dinamicaIndex,
        dinamicaNombre: dinamicaNombre,
        recompensaEntregada: recompensaEntregada,
        tipoRecompensa: tipoRecompensa,
        notas: notas,
        evidencias: evidencias,
      );

      _status = RetailtainmentStatus.submitted;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al registrar dinámica: $e';
      _status = RetailtainmentStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Reset status after submission
  void resetStatus() {
    _status = RetailtainmentStatus.loaded;
    _errorMessage = null;
    notifyListeners();
  }

  /// Get config for selected campaign's country
  ConfigCanjePais? get configCanjeActual {
    if (_selectedCampania == null) return null;
    final paisId = _selectedCampania!.pais?.id;
    if (paisId == null) {
      return _selectedCampania!.configCanje.isNotEmpty
          ? _selectedCampania!.configCanje.first
          : null;
    }
    return _selectedCampania!.getConfigCanjePorPais(paisId);
  }
}
