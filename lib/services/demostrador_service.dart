import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../models/asignacion_rtmt.dart';
import '../models/ticket_canje.dart';
import 'api_service.dart';

/// Servicio para manejar las operaciones del demostrador RTMT
class DemostradorService {
  final ApiService _apiService;

  DemostradorService(this._apiService);

  /// Obtener asignaciones del dia para el usuario actual
  Future<List<AsignacionRTMT>> getAsignacionesHoy() async {
    try {
      debugPrint('📋 [DemostradorService] Fetching today assignments...');
      debugPrint('📋 [DemostradorService] Token presente: ${_apiService.hasToken}');

      final response = await _apiService.getList('/asignaciones/demostrador/hoy');

      debugPrint('📋 [DemostradorService] Response received: ${response.length} items');

      final asignaciones = response
          .map((json) {
            try {
              return AsignacionRTMT.fromJson(json);
            } catch (parseError) {
              debugPrint('❌ [DemostradorService] Error parsing assignment: $parseError');
              debugPrint('❌ [DemostradorService] JSON: $json');
              rethrow;
            }
          })
          .toList();

      debugPrint('📋 [DemostradorService] Found ${asignaciones.length} assignments');
      return asignaciones;
    } catch (e) {
      debugPrint('❌ [DemostradorService] Error fetching today assignments: $e');
      debugPrint('❌ [DemostradorService] Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  /// Obtener asignaciones por estado
  Future<List<AsignacionRTMT>> getAsignacionesPorEstado(String estado) async {
    try {
      debugPrint('📋 [DemostradorService] Fetching assignments with estado: $estado');

      final response = await _apiService.getList('/asignaciones/demostrador/estado/$estado');

      final asignaciones = response
          .map((json) => AsignacionRTMT.fromJson(json))
          .toList();

      debugPrint('📋 [DemostradorService] Found ${asignaciones.length} assignments');
      return asignaciones;
    } catch (e) {
      debugPrint('❌ [DemostradorService] Error fetching assignments by estado: $e');
      rethrow;
    }
  }

  /// Obtener detalle de una asignacion
  Future<AsignacionRTMT> getAsignacionById(String id) async {
    try {
      debugPrint('📋 [DemostradorService] Fetching assignment: $id');

      final response = await _apiService.get('/asignaciones/$id');
      return AsignacionRTMT.fromJson(response);
    } catch (e) {
      debugPrint('❌ [DemostradorService] Error fetching assignment: $e');
      rethrow;
    }
  }

  /// Obtener vista actual del demostrador
  Future<Map<String, dynamic>> getVistaActual(String asignacionId) async {
    try {
      debugPrint('📋 [DemostradorService] Getting current view for: $asignacionId');

      final response = await _apiService.get('/asignaciones/$asignacionId/vista-actual');
      return response;
    } catch (e) {
      debugPrint('❌ [DemostradorService] Error getting current view: $e');
      rethrow;
    }
  }

  /// Registrar un momento (inicio, labor, cierre)
  Future<AsignacionRTMT> registrarMomento({
    required String asignacionId,
    required MomentoRTMT momento,
    String? evidenciaBase64,
    String? evidenciaUrl,
    Ubicacion? ubicacion,
    String? notas,
    String? productoUpc,
    String? marcaId,
    String? marcaNombre,
  }) async {
    try {
      debugPrint('📋 [DemostradorService] Registering moment: ${momento.value}');

      final body = <String, dynamic>{
        'momento': momento.value,
      };

      if (evidenciaBase64 != null) body['evidenciaBase64'] = evidenciaBase64;
      if (evidenciaUrl != null) body['evidenciaUrl'] = evidenciaUrl;
      if (ubicacion != null) body['ubicacion'] = ubicacion.toJson();
      if (notas != null) body['notas'] = notas;
      if (productoUpc != null) body['productoUpc'] = productoUpc;
      if (marcaId != null) body['marcaId'] = marcaId;
      if (marcaNombre != null) body['marcaNombre'] = marcaNombre;

      final response = await _apiService.post(
        '/asignaciones/$asignacionId/momento-rtmt',
        body,
      );

      debugPrint('📋 [DemostradorService] Moment registered successfully');
      return AsignacionRTMT.fromJson(response);
    } catch (e) {
      debugPrint('❌ [DemostradorService] Error registering moment: $e');
      rethrow;
    }
  }

  /// Subir foto y convertir a base64 con compresión
  Future<String> convertImageToBase64(File photo) async {
    final bytes = await photo.readAsBytes();

    // Decodificar la imagen
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('No se pudo decodificar la imagen');
    }

    // Redimensionar si es muy grande (máximo 600px)
    img.Image resized;
    if (image.width > 600 || image.height > 600) {
      if (image.width > image.height) {
        resized = img.copyResize(image, width: 600);
      } else {
        resized = img.copyResize(image, height: 600);
      }
    } else {
      resized = image;
    }

    // Comprimir como JPEG con calidad 50%
    final compressedBytes = img.encodeJpg(resized, quality: 50);

    debugPrint('📷 [DemostradorService] Imagen original: ${bytes.length} bytes');
    debugPrint('📷 [DemostradorService] Imagen comprimida: ${compressedBytes.length} bytes');

    return base64Encode(compressedBytes);
  }

  /// Registrar momento con foto
  Future<AsignacionRTMT> registrarMomentoConFoto({
    required String asignacionId,
    required MomentoRTMT momento,
    required File foto,
    Ubicacion? ubicacion,
    String? notas,
    String? productoUpc,
    String? marcaId,
    String? marcaNombre,
  }) async {
    final base64 = await convertImageToBase64(foto);
    return registrarMomento(
      asignacionId: asignacionId,
      momento: momento,
      evidenciaBase64: 'data:image/jpeg;base64,$base64',
      ubicacion: ubicacion,
      notas: notas,
      productoUpc: productoUpc,
      marcaId: marcaId,
      marcaNombre: marcaNombre,
    );
  }

  /// Marcar incidencia en un momento
  Future<AsignacionRTMT> marcarIncidencia({
    required String asignacionId,
    required MomentoRTMT momento,
    String? descripcion,
    bool incidenciaSupervisor = false,
  }) async {
    try {
      debugPrint('📋 [DemostradorService] Marking incidencia for: ${momento.value}');

      final response = await _apiService.post(
        '/asignaciones/$asignacionId/incidencia',
        {
          'momento': momento.value,
          if (descripcion != null) 'descripcion': descripcion,
          'incidenciaSupervisor': incidenciaSupervisor,
        },
      );

      return AsignacionRTMT.fromJson(response);
    } catch (e) {
      debugPrint('❌ [DemostradorService] Error marking incidencia: $e');
      rethrow;
    }
  }

  /// Corregir incidencia
  Future<AsignacionRTMT> corregirIncidencia({
    required String asignacionId,
    required MomentoRTMT momento,
    String? nuevaEvidenciaBase64,
    String? nuevaEvidenciaUrl,
    Ubicacion? ubicacion,
    String? notas,
  }) async {
    try {
      debugPrint('📋 [DemostradorService] Correcting incidencia for: ${momento.value}');

      final body = <String, dynamic>{
        'momento': momento.value,
      };

      if (nuevaEvidenciaBase64 != null) body['nuevaEvidenciaBase64'] = nuevaEvidenciaBase64;
      if (nuevaEvidenciaUrl != null) body['nuevaEvidenciaUrl'] = nuevaEvidenciaUrl;
      if (ubicacion != null) body['ubicacion'] = ubicacion.toJson();
      if (notas != null) body['notas'] = notas;

      final response = await _apiService.post(
        '/asignaciones/$asignacionId/corregir-incidencia',
        body,
      );

      return AsignacionRTMT.fromJson(response);
    } catch (e) {
      debugPrint('❌ [DemostradorService] Error correcting incidencia: $e');
      rethrow;
    }
  }

  /// Calcular premio segun monto
  Future<Map<String, dynamic>> calcularPremio({
    required String asignacionId,
    required double monto,
    String? paisId,
  }) async {
    try {
      debugPrint('📋 [DemostradorService] Calculating prize for amount: $monto');

      String endpoint = '/asignaciones/$asignacionId/calcular-premio?monto=$monto';
      if (paisId != null) endpoint += '&paisId=$paisId';

      final response = await _apiService.get(endpoint);
      return response;
    } catch (e) {
      debugPrint('❌ [DemostradorService] Error calculating prize: $e');
      rethrow;
    }
  }

  /// Registrar ticket de canje
  Future<Map<String, dynamic>> registrarTicket({
    required String asignacionId,
    required String numTicket,
    required double monto,
    String? imagenBase64,
    Ubicacion? ubicacion,
  }) async {
    try {
      debugPrint('📋 [DemostradorService] Registering ticket: $numTicket');

      final body = <String, dynamic>{
        'numTicket': numTicket,
        'monto': monto,
      };

      if (imagenBase64 != null) body['imagenBase64'] = imagenBase64;
      if (ubicacion != null) body['ubicacion'] = ubicacion.toJson();

      final response = await _apiService.post(
        '/asignaciones/$asignacionId/ticket',
        body,
      );

      debugPrint('📋 [DemostradorService] Ticket registered successfully');
      return response;
    } catch (e) {
      debugPrint('❌ [DemostradorService] Error registering ticket: $e');
      rethrow;
    }
  }

  /// Canjear premio
  Future<Map<String, dynamic>> canjearPremio({
    required String asignacionId,
    required String ticketId,
    required String premioNombre,
  }) async {
    try {
      debugPrint('📋 [DemostradorService] Redeeming prize: $premioNombre');

      final response = await _apiService.post(
        '/asignaciones/$asignacionId/canjear-premio',
        {
          'ticketId': ticketId,
          'premioNombre': premioNombre,
        },
      );

      return response;
    } catch (e) {
      debugPrint('❌ [DemostradorService] Error redeeming prize: $e');
      rethrow;
    }
  }

  /// Registrar cuestionario de cierre
  Future<AsignacionRTMT> registrarCuestionario({
    required String asignacionId,
    required int numClientes,
    int? numTickets,
    List<ProductoAsignacion>? intencionesCompra,
  }) async {
    try {
      debugPrint('📋 [DemostradorService] Registering questionnaire');

      final body = <String, dynamic>{
        'numClientes': numClientes,
      };

      if (numTickets != null) body['numTickets'] = numTickets;
      if (intencionesCompra != null && intencionesCompra.isNotEmpty) {
        body['intencionesCompra'] = intencionesCompra.map((p) => p.toJson()).toList();
      }

      final response = await _apiService.patch(
        '/asignaciones/$asignacionId/cuestionario',
        body,
      );

      return AsignacionRTMT.fromJson(response);
    } catch (e) {
      debugPrint('❌ [DemostradorService] Error registering questionnaire: $e');
      rethrow;
    }
  }

  /// Registrar cierre completo (con cuestionario)
  Future<AsignacionRTMT> registrarCierre({
    required String asignacionId,
    String? evidenciaBase64,
    String? evidenciaUrl,
    Ubicacion? ubicacion,
    required int numClientes,
    int? numTickets,
    List<ProductoAsignacion>? intencionesCompra,
    String? notas,
  }) async {
    try {
      debugPrint('📋 [DemostradorService] Registering close with questionnaire');

      final body = <String, dynamic>{
        'cuestionario': {
          'numClientes': numClientes,
          if (numTickets != null) 'numTickets': numTickets,
          if (intencionesCompra != null && intencionesCompra.isNotEmpty)
            'intencionesCompra': intencionesCompra.map((p) => p.toJson()).toList(),
        },
      };

      if (evidenciaBase64 != null) body['evidenciaBase64'] = evidenciaBase64;
      if (evidenciaUrl != null) body['evidenciaUrl'] = evidenciaUrl;
      if (ubicacion != null) body['ubicacion'] = ubicacion.toJson();
      if (notas != null) body['notas'] = notas;

      final response = await _apiService.post(
        '/asignaciones/$asignacionId/cierre-rtmt',
        body,
      );

      return AsignacionRTMT.fromJson(response);
    } catch (e) {
      debugPrint('❌ [DemostradorService] Error registering close: $e');
      rethrow;
    }
  }

  /// Habilitar cierre (supervisor) - Solo habilita el acceso para que el demostrador tome su foto
  Future<AsignacionRTMT> habilitarCierre({
    required String asignacionId,
    required String motivo,
    String? supervisorId,
  }) async {
    try {
      debugPrint('📋 [DemostradorService] Enabling close access');

      final response = await _apiService.post(
        '/asignaciones/$asignacionId/habilitar-cierre',
        {
          'motivo': motivo,
          if (supervisorId != null) 'supervisorId': supervisorId,
        },
      );

      return AsignacionRTMT.fromJson(response);
    } catch (e) {
      debugPrint('❌ [DemostradorService] Error enabling close: $e');
      rethrow;
    }
  }

  /// Forzar cierre (supervisor) - Completa automáticamente el cierre
  Future<AsignacionRTMT> forzarCierre({
    required String asignacionId,
    required String motivo,
    String? supervisorId,
  }) async {
    try {
      debugPrint('📋 [DemostradorService] Forcing close');

      final response = await _apiService.post(
        '/asignaciones/$asignacionId/forzar-cierre-rtmt',
        {
          'motivo': motivo,
          if (supervisorId != null) 'supervisorId': supervisorId,
        },
      );

      return AsignacionRTMT.fromJson(response);
    } catch (e) {
      debugPrint('❌ [DemostradorService] Error forcing close: $e');
      rethrow;
    }
  }

  /// Registrar ticket de canje por compra
  Future<Map<String, dynamic>?> registrarTicketCanje({
    required String asignacionId,
    required String marcaId,
    required String marcaNombre,
    required double monto,
    required String fotoBase64,
    double? latitud,
    double? longitud,
    PremioGanado? premioGanado,
  }) async {
    try {
      debugPrint('📋 [DemostradorService] Registering ticket canje');
      debugPrint('📋 [DemostradorService] Marca: $marcaNombre, Monto: $monto');

      final body = <String, dynamic>{
        'marcaId': marcaId,
        'marcaNombre': marcaNombre,
        'monto': monto,
        'fotoBase64': fotoBase64,
        'fecha': DateTime.now().toIso8601String(),
      };

      if (latitud != null && longitud != null) {
        body['ubicacion'] = {
          'lat': latitud,
          'lng': longitud,
        };
      }

      if (premioGanado != null) {
        body['premioGanado'] = premioGanado.toJson();
      }

      final response = await _apiService.post(
        '/asignaciones/$asignacionId/ticket-canje',
        body,
      );

      debugPrint('📋 [DemostradorService] Ticket registered successfully');
      return response;
    } catch (e) {
      debugPrint('❌ [DemostradorService] Error registering ticket canje: $e');
      rethrow;
    }
  }

  /// Registrar participación en dinámica
  Future<Map<String, dynamic>?> registrarParticipacionDinamica({
    required String asignacionId,
    required String dinamicaNombre,
    required String fotoBase64,
    double? latitud,
    double? longitud,
    String? recompensaEntregada,
  }) async {
    try {
      debugPrint('📋 [DemostradorService] Registering dinamica participation');
      debugPrint('📋 [DemostradorService] Dinamica: $dinamicaNombre');

      final body = <String, dynamic>{
        'dinamicaNombre': dinamicaNombre,
        'fotoBase64': fotoBase64,
        'fecha': DateTime.now().toIso8601String(),
        'completada': true,
      };

      if (latitud != null && longitud != null) {
        body['ubicacion'] = {
          'lat': latitud,
          'lng': longitud,
        };
      }

      if (recompensaEntregada != null) {
        body['recompensaEntregada'] = recompensaEntregada;
      }

      final response = await _apiService.post(
        '/asignaciones/$asignacionId/participacion-dinamica',
        body,
      );

      debugPrint('📋 [DemostradorService] Dinamica participation registered successfully');
      return response;
    } catch (e) {
      debugPrint('❌ [DemostradorService] Error registering dinamica participation: $e');
      rethrow;
    }
  }
}
