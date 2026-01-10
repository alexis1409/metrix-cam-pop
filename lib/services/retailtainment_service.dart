import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/campania.dart';
import 'api_service.dart';

class RegistroRetailtainmentRequest {
  final String tipo;
  final String tiendaId;
  final double? montoTicket;
  final List<String>? upcsValidados;
  final List<Premio>? premiosEntregados;
  final int? dinamicaIndex;
  final String? dinamicaNombre;
  final String? recompensaEntregada;
  final String? tipoRecompensa;
  final DateTime? fecha;
  final String? notas;
  final List<String>? evidencias;

  RegistroRetailtainmentRequest({
    required this.tipo,
    required this.tiendaId,
    this.montoTicket,
    this.upcsValidados,
    this.premiosEntregados,
    this.dinamicaIndex,
    this.dinamicaNombre,
    this.recompensaEntregada,
    this.tipoRecompensa,
    this.fecha,
    this.notas,
    this.evidencias,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'tipo': tipo,
      'tiendaId': tiendaId,
    };

    if (montoTicket != null) json['montoTicket'] = montoTicket;
    if (upcsValidados != null && upcsValidados!.isNotEmpty) {
      json['upcsValidados'] = upcsValidados;
    }
    if (premiosEntregados != null && premiosEntregados!.isNotEmpty) {
      json['premiosEntregados'] = premiosEntregados!.map((p) => p.toJson()).toList();
    }
    if (dinamicaIndex != null) json['dinamicaIndex'] = dinamicaIndex;
    if (dinamicaNombre != null && dinamicaNombre!.isNotEmpty) {
      json['dinamicaNombre'] = dinamicaNombre;
    }
    if (recompensaEntregada != null && recompensaEntregada!.isNotEmpty) {
      json['recompensaEntregada'] = recompensaEntregada;
    }
    if (tipoRecompensa != null && tipoRecompensa!.isNotEmpty) {
      json['tipoRecompensa'] = tipoRecompensa;
    }
    if (fecha != null) json['fecha'] = fecha!.toIso8601String();
    if (notas != null && notas!.isNotEmpty) json['notas'] = notas;
    if (evidencias != null && evidencias!.isNotEmpty) {
      json['evidencias'] = evidencias;
    }

    return json;
  }
}

class RetailtainmentService {
  final ApiService _apiService;

  RetailtainmentService(this._apiService);

  /// Get all retailtainment campaigns for a user
  Future<List<Campania>> getRetailtainmentCampanias(String userId) async {
    try {
      debugPrint('🎪 [RetailtainmentService] Fetching retailtainment campaigns for user: $userId');

      final response = await _apiService.getList('/campanias/instalador/$userId');

      final campanias = response
          .map((json) => Campania.fromJson(json))
          .where((c) => c.esRetailtainment)
          .toList();

      debugPrint('🎪 [RetailtainmentService] Found ${campanias.length} retailtainment campaigns');
      return campanias;
    } catch (e) {
      debugPrint('❌ [RetailtainmentService] Error fetching retailtainment campaigns: $e');
      rethrow;
    }
  }

  /// Get retailtainment campaigns that are active today
  Future<List<Campania>> getActiveCampaniasHoy(String userId) async {
    final campanias = await getRetailtainmentCampanias(userId);

    return campanias.where((c) {
      // Check if campaign is within date range
      final now = DateTime.now();
      if (now.isBefore(c.fechaInicio) || now.isAfter(c.fechaFin)) {
        return false;
      }
      // Check if today is an active day
      return c.esDiaActivoHoy;
    }).toList();
  }

  /// Get a single campaign by ID with full retailtainment config
  Future<Campania> getCampaniaById(String campaniaId) async {
    try {
      debugPrint('🎪 [RetailtainmentService] Fetching campaign: $campaniaId');

      final response = await _apiService.get('/campanias/$campaniaId');
      return Campania.fromJson(response);
    } catch (e) {
      debugPrint('❌ [RetailtainmentService] Error fetching campaign: $e');
      rethrow;
    }
  }

  /// Register a retailtainment activity
  Future<bool> registrarActividad(
    String campaniaId,
    RegistroRetailtainmentRequest request,
  ) async {
    try {
      debugPrint('🎪 [RetailtainmentService] Registering activity for campaign: $campaniaId');
      debugPrint('🎪 [RetailtainmentService] Request: ${request.toJson()}');

      await _apiService.post(
        '/campanias/$campaniaId/registro-retailtainment',
        request.toJson(),
      );

      debugPrint('🎪 [RetailtainmentService] Activity registered successfully');
      return true;
    } catch (e) {
      debugPrint('❌ [RetailtainmentService] Error registering activity: $e');
      rethrow;
    }
  }

  /// Register a demonstration
  Future<bool> registrarDemostracion({
    required String campaniaId,
    required String tiendaId,
    String? notas,
    List<String>? evidencias,
  }) async {
    final request = RegistroRetailtainmentRequest(
      tipo: 'demostracion',
      tiendaId: tiendaId,
      notas: notas,
      evidencias: evidencias,
    );
    return registrarActividad(campaniaId, request);
  }

  /// Register a purchase redemption
  Future<bool> registrarCanjeCompra({
    required String campaniaId,
    required String tiendaId,
    required double montoTicket,
    List<String>? upcsValidados,
    required List<Premio> premiosEntregados,
    String? notas,
    List<String>? evidencias,
  }) async {
    final request = RegistroRetailtainmentRequest(
      tipo: 'canje_compra',
      tiendaId: tiendaId,
      montoTicket: montoTicket,
      upcsValidados: upcsValidados,
      premiosEntregados: premiosEntregados,
      notas: notas,
      evidencias: evidencias,
    );
    return registrarActividad(campaniaId, request);
  }

  /// Register a dynamic activity redemption
  Future<bool> registrarCanjeDinamica({
    required String campaniaId,
    required String tiendaId,
    required int dinamicaIndex,
    required String dinamicaNombre,
    required String recompensaEntregada,
    String? tipoRecompensa,
    String? notas,
    List<String>? evidencias,
  }) async {
    final request = RegistroRetailtainmentRequest(
      tipo: 'canje_dinamica',
      tiendaId: tiendaId,
      dinamicaIndex: dinamicaIndex,
      dinamicaNombre: dinamicaNombre,
      recompensaEntregada: recompensaEntregada,
      tipoRecompensa: tipoRecompensa,
      fecha: DateTime.now(),
      notas: notas,
      evidencias: evidencias,
    );
    return registrarActividad(campaniaId, request);
  }

  /// Upload evidence photos and return URLs
  Future<List<String>> uploadEvidencias(List<File> photos) async {
    try {
      if (photos.isEmpty) return [];

      debugPrint('🎪 [RetailtainmentService] Uploading ${photos.length} evidence photos');

      final response = await _apiService.uploadMultipleFiles(
        '/uploads/multiple',
        photos,
        fieldName: 'files',
      );

      final urls = List<String>.from(response['urls'] ?? []);
      debugPrint('🎪 [RetailtainmentService] Uploaded ${urls.length} photos');
      return urls;
    } catch (e) {
      debugPrint('❌ [RetailtainmentService] Error uploading evidence: $e');
      rethrow;
    }
  }

  /// Get stores for a campaign (from detalles)
  List<Tienda> getTiendasForCampania(Campania campania) {
    final tiendas = <String, Tienda>{};
    for (var detalle in campania.detalles) {
      if (detalle.tienda != null) {
        tiendas[detalle.tienda!.id] = detalle.tienda!;
      }
    }
    return tiendas.values.toList();
  }

  /// Get assigned stores for a user (for impulsador/supervisor)
  /// Endpoint: GET /users/:id/tiendas?proyecto=xxx
  Future<List<Tienda>> getTiendasAsignadas(String userId, {String? proyectoId}) async {
    try {
      debugPrint('🎪 [RetailtainmentService] Fetching assigned stores for user: $userId');

      String endpoint = '/users/$userId/tiendas';
      if (proyectoId != null) {
        endpoint += '?proyecto=$proyectoId';
      }

      final response = await _apiService.getList(endpoint);

      final tiendas = response.map((json) => Tienda.fromJson(json)).toList();
      debugPrint('🎪 [RetailtainmentService] Found ${tiendas.length} assigned stores');
      return tiendas;
    } catch (e) {
      debugPrint('❌ [RetailtainmentService] Error fetching assigned stores: $e');
      rethrow;
    }
  }

  /// Get retailtainment users (impulsadores and supervisores)
  /// Endpoint: GET /users/retailtainment
  Future<Map<String, List<dynamic>>> getRetailtainmentUsers() async {
    try {
      debugPrint('🎪 [RetailtainmentService] Fetching retailtainment users');

      final response = await _apiService.get('/users/retailtainment');

      return {
        'impulsadores': List.from(response['impulsadores'] ?? []),
        'supervisores': List.from(response['supervisores'] ?? []),
      };
    } catch (e) {
      debugPrint('❌ [RetailtainmentService] Error fetching retailtainment users: $e');
      rethrow;
    }
  }

  /// Get impulsadores only
  /// Endpoint: GET /users/rol/impulsador
  Future<List<dynamic>> getImpulsadores() async {
    try {
      final response = await _apiService.getList('/users/rol/impulsador');
      return response;
    } catch (e) {
      debugPrint('❌ [RetailtainmentService] Error fetching impulsadores: $e');
      rethrow;
    }
  }

  /// Get supervisores retailtainment only
  /// Endpoint: GET /users/rol/supervisor_retailtainment
  Future<List<dynamic>> getSupervisores() async {
    try {
      final response = await _apiService.getList('/users/rol/supervisor_retailtainment');
      return response;
    } catch (e) {
      debugPrint('❌ [RetailtainmentService] Error fetching supervisores: $e');
      rethrow;
    }
  }
}
