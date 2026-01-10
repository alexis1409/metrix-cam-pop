import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/asignacion_rtmt.dart';
import '../models/ticket_canje.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/demostrador_service.dart';

enum DemostradorStatus {
  initial,
  loading,
  loaded,
  error,
  submitting,
  submitted,
}

class DemostradorProvider extends ChangeNotifier {
  final DemostradorService _service;

  DemostradorStatus _status = DemostradorStatus.initial;
  List<AsignacionRTMT> _asignacionesHoy = [];
  List<AsignacionRTMT> _asignacionesPendientes = [];
  List<AsignacionRTMT> _asignacionesCompletadas = [];
  AsignacionRTMT? _asignacionActual;
  String? _errorMessage;
  User? _currentUser;
  Map<String, dynamic>? _vistaActual;
  Map<String, dynamic>? _premioCalculado;

  DemostradorProvider(ApiService apiService)
      : _service = DemostradorService(apiService);

  // Getters
  DemostradorStatus get status => _status;
  List<AsignacionRTMT> get asignacionesHoy => _asignacionesHoy;
  List<AsignacionRTMT> get asignacionesPendientes => _asignacionesPendientes;
  List<AsignacionRTMT> get asignacionesCompletadas => _asignacionesCompletadas;
  AsignacionRTMT? get asignacionActual => _asignacionActual;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == DemostradorStatus.loading;
  bool get isSubmitting => _status == DemostradorStatus.submitting;
  User? get currentUser => _currentUser;
  Map<String, dynamic>? get vistaActual => _vistaActual;
  Map<String, dynamic>? get premioCalculado => _premioCalculado;

  // Role-based getters
  bool get isImpulsador => _currentUser?.isImpulsador ?? false;
  bool get isSupervisor => _currentUser?.isSupervisorRetailtainment ?? false;
  bool get hasRetailtainmentRole => _currentUser?.hasRetailtainmentRole ?? false;

  /// Set the current user
  void setUser(User? user) {
    _currentUser = user;
    notifyListeners();
  }

  /// Load today's assignments
  Future<void> loadAsignacionesHoy() async {
    _status = DemostradorStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint('📋 [DemostradorProvider] Loading today\'s assignments...');
      _asignacionesHoy = await _service.getAsignacionesHoy();
      debugPrint('📋 [DemostradorProvider] Loaded ${_asignacionesHoy.length} assignments');

      // Separate by status
      _asignacionesPendientes = _asignacionesHoy
          .where((a) => a.estado == EstadoAsignacion.pendiente ||
                        a.estado == EstadoAsignacion.enProgreso ||
                        a.estado == EstadoAsignacion.incidencia)
          .toList();

      _asignacionesCompletadas = _asignacionesHoy
          .where((a) => a.estado == EstadoAsignacion.completada)
          .toList();

      debugPrint('📋 [DemostradorProvider] Pendientes: ${_asignacionesPendientes.length}, Completadas: ${_asignacionesCompletadas.length}');
      _status = DemostradorStatus.loaded;
    } catch (e) {
      debugPrint('❌ [DemostradorProvider] Error loading assignments: $e');

      // Check if it's an authentication error
      if (e is AuthenticationException) {
        _errorMessage = 'Tu sesión ha expirado. Cierra la app e inicia sesión nuevamente.';
      } else {
        _errorMessage = 'Error al cargar asignaciones: $e';
      }
      _status = DemostradorStatus.error;
    }
    notifyListeners();
  }

  /// Load assignments by estado
  Future<void> loadAsignacionesPorEstado(String estado) async {
    _status = DemostradorStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      if (estado == 'pendiente') {
        _asignacionesPendientes = await _service.getAsignacionesPorEstado(estado);
      } else if (estado == 'completada') {
        _asignacionesCompletadas = await _service.getAsignacionesPorEstado(estado);
      }
      _status = DemostradorStatus.loaded;
    } catch (e) {
      _errorMessage = 'Error al cargar asignaciones: $e';
      _status = DemostradorStatus.error;
    }
    notifyListeners();
  }

  /// Select an assignment
  Future<void> selectAsignacion(AsignacionRTMT asignacion) async {
    _asignacionActual = asignacion;
    notifyListeners();

    // Load current view
    await loadVistaActual(asignacion.id);
  }

  /// Load current view for assignment
  Future<void> loadVistaActual(String asignacionId) async {
    try {
      _vistaActual = await _service.getVistaActual(asignacionId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading vista actual: $e');
    }
  }

  /// Clear selection
  void clearSelection() {
    _asignacionActual = null;
    _vistaActual = null;
    _premioCalculado = null;
    notifyListeners();
  }

  /// Register a moment
  Future<bool> registrarMomento({
    required MomentoRTMT momento,
    File? foto,
    Ubicacion? ubicacion,
    String? notas,
    String? productoUpc,
    String? marcaId,
    String? marcaNombre,
  }) async {
    if (_asignacionActual == null) {
      _errorMessage = 'No hay asignación seleccionada';
      return false;
    }

    _status = DemostradorStatus.submitting;
    _errorMessage = null;
    notifyListeners();

    try {
      // Guardar la campaña original antes de actualizar
      final campOriginal = _asignacionActual!.camp;

      AsignacionRTMT result;

      if (foto != null) {
        result = await _service.registrarMomentoConFoto(
          asignacionId: _asignacionActual!.id,
          momento: momento,
          foto: foto,
          ubicacion: ubicacion,
          notas: notas,
          productoUpc: productoUpc,
          marcaId: marcaId,
          marcaNombre: marcaNombre,
        );
      } else {
        result = await _service.registrarMomento(
          asignacionId: _asignacionActual!.id,
          momento: momento,
          ubicacion: ubicacion,
          notas: notas,
          productoUpc: productoUpc,
          marcaId: marcaId,
          marcaNombre: marcaNombre,
        );
      }

      // Si el resultado no tiene campaña completa, preservar la original
      // Verificamos: tipoRetailtainment, marcas, configCanje, configDinamica
      final campResult = result.camp;
      final necesitaPreservar = campResult == null ||
          campResult.tipoRetailtainment == null ||
          (campOriginal?.marcas.isNotEmpty == true && campResult.marcas.isEmpty) ||
          (campOriginal?.configCanje.isNotEmpty == true && campResult.configCanje.isEmpty) ||
          (campOriginal?.configDinamica.isNotEmpty == true && campResult.configDinamica.isEmpty);

      if (necesitaPreservar && campOriginal != null) {
        debugPrint('📋 [DemostradorProvider] Preservando campaña original porque faltan datos');
        debugPrint('📋 [DemostradorProvider] tipoRetailtainment result: ${campResult?.tipoRetailtainment}, original: ${campOriginal.tipoRetailtainment}');
        debugPrint('📋 [DemostradorProvider] marcas result: ${campResult?.marcas.length ?? 0}, original: ${campOriginal.marcas.length}');
        result = result.copyWithCamp(campOriginal);
      }

      _asignacionActual = result;
      await _updateAsignacionInList(result);

      _status = DemostradorStatus.submitted;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al registrar momento: $e';
      _status = DemostradorStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Mark incidencia
  Future<bool> marcarIncidencia({
    required MomentoRTMT momento,
    String? descripcion,
    bool incidenciaSupervisor = false,
  }) async {
    if (_asignacionActual == null) {
      _errorMessage = 'No hay asignación seleccionada';
      return false;
    }

    _status = DemostradorStatus.submitting;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.marcarIncidencia(
        asignacionId: _asignacionActual!.id,
        momento: momento,
        descripcion: descripcion,
        incidenciaSupervisor: incidenciaSupervisor,
      );

      _asignacionActual = result;
      await _updateAsignacionInList(result);

      _status = DemostradorStatus.submitted;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al marcar incidencia: $e';
      _status = DemostradorStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Correct incidencia
  Future<bool> corregirIncidencia({
    required MomentoRTMT momento,
    File? nuevaFoto,
    Ubicacion? ubicacion,
    String? notas,
  }) async {
    if (_asignacionActual == null) {
      _errorMessage = 'No hay asignación seleccionada';
      return false;
    }

    _status = DemostradorStatus.submitting;
    _errorMessage = null;
    notifyListeners();

    try {
      String? base64;
      if (nuevaFoto != null) {
        base64 = await _service.convertImageToBase64(nuevaFoto);
        base64 = 'data:image/jpeg;base64,$base64';
      }

      final result = await _service.corregirIncidencia(
        asignacionId: _asignacionActual!.id,
        momento: momento,
        nuevaEvidenciaBase64: base64,
        ubicacion: ubicacion,
        notas: notas,
      );

      _asignacionActual = result;
      await _updateAsignacionInList(result);

      _status = DemostradorStatus.submitted;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al corregir incidencia: $e';
      _status = DemostradorStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Calculate prize for amount
  Future<void> calcularPremio(double monto, {String? paisId}) async {
    if (_asignacionActual == null) return;

    try {
      _premioCalculado = await _service.calcularPremio(
        asignacionId: _asignacionActual!.id,
        monto: monto,
        paisId: paisId,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error calculating prize: $e');
      _premioCalculado = null;
      notifyListeners();
    }
  }

  /// Register ticket
  Future<Map<String, dynamic>?> registrarTicket({
    required String numTicket,
    required double monto,
    File? foto,
    Ubicacion? ubicacion,
  }) async {
    if (_asignacionActual == null) {
      _errorMessage = 'No hay asignación seleccionada';
      return null;
    }

    _status = DemostradorStatus.submitting;
    _errorMessage = null;
    notifyListeners();

    try {
      String? base64;
      if (foto != null) {
        base64 = await _service.convertImageToBase64(foto);
        base64 = 'data:image/jpeg;base64,$base64';
      }

      final result = await _service.registrarTicket(
        asignacionId: _asignacionActual!.id,
        numTicket: numTicket,
        monto: monto,
        imagenBase64: base64,
        ubicacion: ubicacion,
      );

      _status = DemostradorStatus.submitted;
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = 'Error al registrar ticket: $e';
      _status = DemostradorStatus.error;
      notifyListeners();
      return null;
    }
  }

  /// Redeem prize
  Future<bool> canjearPremio({
    required String ticketId,
    required String premioNombre,
  }) async {
    if (_asignacionActual == null) {
      _errorMessage = 'No hay asignación seleccionada';
      return false;
    }

    _status = DemostradorStatus.submitting;
    _errorMessage = null;
    notifyListeners();

    try {
      await _service.canjearPremio(
        asignacionId: _asignacionActual!.id,
        ticketId: ticketId,
        premioNombre: premioNombre,
      );

      _status = DemostradorStatus.submitted;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al canjear premio: $e';
      _status = DemostradorStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Register close with questionnaire
  Future<bool> registrarCierre({
    File? foto,
    Ubicacion? ubicacion,
    required int numClientes,
    int? numTickets,
    List<ProductoAsignacion>? intencionesCompra,
    String? notas,
  }) async {
    if (_asignacionActual == null) {
      _errorMessage = 'No hay asignación seleccionada';
      return false;
    }

    _status = DemostradorStatus.submitting;
    _errorMessage = null;
    notifyListeners();

    try {
      String? base64;
      if (foto != null) {
        base64 = await _service.convertImageToBase64(foto);
        base64 = 'data:image/jpeg;base64,$base64';
      }

      final result = await _service.registrarCierre(
        asignacionId: _asignacionActual!.id,
        evidenciaBase64: base64,
        ubicacion: ubicacion,
        numClientes: numClientes,
        numTickets: numTickets,
        intencionesCompra: intencionesCompra,
        notas: notas,
      );

      _asignacionActual = result;
      await _updateAsignacionInList(result);

      _status = DemostradorStatus.submitted;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al registrar cierre: $e';
      _status = DemostradorStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Habilitar cierre (supervisor) - Solo habilita el acceso para que el demostrador tome su foto
  Future<bool> habilitarCierre({required String motivo}) async {
    if (_asignacionActual == null) {
      _errorMessage = 'No hay asignación seleccionada';
      return false;
    }

    _status = DemostradorStatus.submitting;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.habilitarCierre(
        asignacionId: _asignacionActual!.id,
        motivo: motivo,
        supervisorId: _currentUser?.id,
      );

      _asignacionActual = result;
      await _updateAsignacionInList(result);

      _status = DemostradorStatus.submitted;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al habilitar cierre: $e';
      _status = DemostradorStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Force close (supervisor) - Completa automáticamente el cierre
  Future<bool> forzarCierre({required String motivo}) async {
    if (_asignacionActual == null) {
      _errorMessage = 'No hay asignación seleccionada';
      return false;
    }

    _status = DemostradorStatus.submitting;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _service.forzarCierre(
        asignacionId: _asignacionActual!.id,
        motivo: motivo,
        supervisorId: _currentUser?.id,
      );

      _asignacionActual = result;
      await _updateAsignacionInList(result);

      _status = DemostradorStatus.submitted;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al forzar cierre: $e';
      _status = DemostradorStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Update assignment in lists
  Future<void> _updateAsignacionInList(AsignacionRTMT updated) async {
    // Update in all lists
    final updateInList = (List<AsignacionRTMT> list) {
      final index = list.indexWhere((a) => a.id == updated.id);
      if (index != -1) {
        list[index] = updated;
      }
    };

    updateInList(_asignacionesHoy);
    updateInList(_asignacionesPendientes);
    updateInList(_asignacionesCompletadas);

    // Move between lists if status changed
    if (updated.estado == EstadoAsignacion.completada) {
      _asignacionesPendientes.removeWhere((a) => a.id == updated.id);
      if (!_asignacionesCompletadas.any((a) => a.id == updated.id)) {
        _asignacionesCompletadas.add(updated);
      }
    }
  }

  /// Reset status
  void resetStatus() {
    _status = DemostradorStatus.loaded;
    _errorMessage = null;
    notifyListeners();
  }

  /// Register ticket canje (canje por compra)
  Future<bool> registrarTicketCanje(TicketCanje ticket, File foto) async {
    if (_asignacionActual == null) {
      _errorMessage = 'No hay asignación seleccionada';
      return false;
    }

    _status = DemostradorStatus.submitting;
    _errorMessage = null;
    notifyListeners();

    try {
      // Convert image to base64
      final base64 = await _service.convertImageToBase64(foto);
      final base64WithPrefix = 'data:image/jpeg;base64,$base64';

      final result = await _service.registrarTicketCanje(
        asignacionId: _asignacionActual!.id ?? '',
        marcaId: ticket.marcaId,
        marcaNombre: ticket.marcaNombre,
        monto: ticket.monto,
        fotoBase64: base64WithPrefix,
        latitud: ticket.latitud,
        longitud: ticket.longitud,
        premioGanado: ticket.premioGanado,
      );

      if (result != null) {
        // Reload assignments to get updated data
        await loadAsignacionesHoy();
        // Re-select current assignment
        if (_asignacionActual != null) {
          _asignacionActual = _asignacionesHoy.firstWhere(
            (a) => a.id == _asignacionActual!.id,
            orElse: () => _asignacionActual!,
          );
        }
      }

      _status = DemostradorStatus.submitted;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al registrar ticket: $e';
      _status = DemostradorStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Register participation in dinamica (canje con dinámica)
  Future<bool> registrarParticipacionDinamica({
    required String dinamicaNombre,
    required File foto,
    Ubicacion? ubicacion,
    String? recompensaEntregada,
  }) async {
    if (_asignacionActual == null) {
      _errorMessage = 'No hay asignación seleccionada';
      return false;
    }

    _status = DemostradorStatus.submitting;
    _errorMessage = null;
    notifyListeners();

    try {
      // Convert image to base64
      final base64 = await _service.convertImageToBase64(foto);
      final base64WithPrefix = 'data:image/jpeg;base64,$base64';

      final result = await _service.registrarParticipacionDinamica(
        asignacionId: _asignacionActual!.id ?? '',
        dinamicaNombre: dinamicaNombre,
        fotoBase64: base64WithPrefix,
        latitud: ubicacion?.lat,
        longitud: ubicacion?.lng,
        recompensaEntregada: recompensaEntregada,
      );

      if (result != null) {
        // Reload assignments to get updated data
        await loadAsignacionesHoy();
        // Re-select current assignment
        if (_asignacionActual != null) {
          _asignacionActual = _asignacionesHoy.firstWhere(
            (a) => a.id == _asignacionActual!.id,
            orElse: () => _asignacionActual!,
          );
        }
      }

      _status = DemostradorStatus.submitted;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al registrar participación: $e';
      _status = DemostradorStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Get next moment to complete
  MomentoRTMT? get siguienteMomento => _asignacionActual?.siguienteMomento;

  /// Check if can advance to moment
  bool puedeAvanzarA(MomentoRTMT momento) =>
      _asignacionActual?.puedeAvanzarA(momento) ?? false;

  /// Get progress (0.0 - 1.0)
  double get progreso => _asignacionActual?.progreso ?? 0.0;

  /// Check if has incidences
  bool get tieneIncidencias => _asignacionActual?.tieneIncidencias ?? false;

  /// Verificar si el cierre es corrección de incidencia (no requiere cuestionario)
  Future<bool> verificarCorreccionCierre() async {
    if (_asignacionActual == null) return false;
    return _service.verificarCorreccionCierre(_asignacionActual!.id);
  }

  /// Recargar asignación actual desde el servidor
  Future<void> recargarAsignacionActual() async {
    if (_asignacionActual == null) return;

    try {
      final asignacionRecargada = await _service.getAsignacionById(_asignacionActual!.id);
      _asignacionActual = asignacionRecargada;
      await _updateAsignacionInList(asignacionRecargada);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [DemostradorProvider] Error recargando asignación: $e');
    }
  }
}
