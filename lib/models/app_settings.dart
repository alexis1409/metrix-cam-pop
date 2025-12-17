import 'package:flutter/material.dart';

class StatusColor {
  final Color fondo;
  final Color texto;
  final Color borde;

  StatusColor({
    required this.fondo,
    required this.texto,
    required this.borde,
  });

  factory StatusColor.fromJson(Map<String, dynamic> json) {
    return StatusColor(
      fondo: _parseColor(json['fondo'] ?? '#f3f4f6'),
      texto: _parseColor(json['texto'] ?? '#6b7280'),
      borde: _parseColor(json['borde'] ?? '#d1d5db'),
    );
  }

  static Color _parseColor(String hex) {
    final hexColor = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexColor', radix: 16));
  }
}

class WatermarkConfig {
  final bool habilitado;
  final bool mostrarFecha;
  final bool mostrarHora;
  final bool mostrarCoordenadas;
  final bool mostrarTienda;
  final bool mostrarUsuario;

  WatermarkConfig({
    this.habilitado = true,
    this.mostrarFecha = true,
    this.mostrarHora = true,
    this.mostrarCoordenadas = true,
    this.mostrarTienda = true,
    this.mostrarUsuario = false,
  });

  factory WatermarkConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return WatermarkConfig();
    return WatermarkConfig(
      habilitado: json['habilitado'] ?? true,
      mostrarFecha: json['mostrarFecha'] ?? true,
      mostrarHora: json['mostrarHora'] ?? true,
      mostrarCoordenadas: json['mostrarCoordenadas'] ?? true,
      mostrarTienda: json['mostrarTienda'] ?? true,
      mostrarUsuario: json['mostrarUsuario'] ?? false,
    );
  }
}

class AntiFraudeConfig {
  final int distanciaMaximaMetros;
  final WatermarkConfig watermark;
  final bool permitirGaleriaDispositivo;
  final bool validarUbicacionAlSubir;

  AntiFraudeConfig({
    this.distanciaMaximaMetros = 800,
    WatermarkConfig? watermark,
    this.permitirGaleriaDispositivo = false,
    this.validarUbicacionAlSubir = true,
  }) : watermark = watermark ?? WatermarkConfig();

  factory AntiFraudeConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return AntiFraudeConfig();
    return AntiFraudeConfig(
      distanciaMaximaMetros: json['distanciaMaximaMetros'] ?? 800,
      watermark: WatermarkConfig.fromJson(json['watermark'] as Map<String, dynamic>?),
      permitirGaleriaDispositivo: json['permitirGaleriaDispositivo'] ?? false,
      validarUbicacionAlSubir: json['validarUbicacionAlSubir'] ?? true,
    );
  }
}

class AppSettings {
  final Map<String, StatusColor> estadosCampania;
  final Map<String, StatusColor> estadosDetalle;
  final AntiFraudeConfig antiFraude;

  AppSettings({
    required this.estadosCampania,
    required this.estadosDetalle,
    AntiFraudeConfig? antiFraude,
  }) : antiFraude = antiFraude ?? AntiFraudeConfig();

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final estadosCampaniaJson = json['estadosCampania'] as Map<String, dynamic>? ?? {};
    final estadosDetalleJson = json['estadosDetalle'] as Map<String, dynamic>? ?? {};

    return AppSettings(
      estadosCampania: estadosCampaniaJson.map(
        (key, value) => MapEntry(key, StatusColor.fromJson(value as Map<String, dynamic>)),
      ),
      estadosDetalle: estadosDetalleJson.map(
        (key, value) => MapEntry(key, StatusColor.fromJson(value as Map<String, dynamic>)),
      ),
      antiFraude: AntiFraudeConfig.fromJson(json['antiFraude'] as Map<String, dynamic>?),
    );
  }

  factory AppSettings.defaults() {
    return AppSettings(
      estadosCampania: {
        'borrador': StatusColor(fondo: const Color(0xFFF3F4F6), texto: const Color(0xFF6B7280), borde: const Color(0xFFD1D5DB)),
        'alta': StatusColor(fondo: const Color(0xFFDBEAFE), texto: const Color(0xFF1D4ED8), borde: const Color(0xFF93C5FD)),
        'supervision': StatusColor(fondo: const Color(0xFFFEF3C7), texto: const Color(0xFFD97706), borde: const Color(0xFFFCD34D)),
        'baja': StatusColor(fondo: const Color(0xFFFCE7F3), texto: const Color(0xFFBE185D), borde: const Color(0xFFF9A8D4)),
        'finalizada': StatusColor(fondo: const Color(0xFFD1FAE5), texto: const Color(0xFF047857), borde: const Color(0xFF6EE7B7)),
        'cancelada': StatusColor(fondo: const Color(0xFFFEE2E2), texto: const Color(0xFFDC2626), borde: const Color(0xFFFCA5A5)),
      },
      estadosDetalle: {
        'pendiente': StatusColor(fondo: const Color(0xFFF3F4F6), texto: const Color(0xFF6B7280), borde: const Color(0xFFD1D5DB)),
        'alta': StatusColor(fondo: const Color(0xFFDBEAFE), texto: const Color(0xFF1D4ED8), borde: const Color(0xFF93C5FD)),
        'supervision': StatusColor(fondo: const Color(0xFFFEF3C7), texto: const Color(0xFFD97706), borde: const Color(0xFFFCD34D)),
        'baja': StatusColor(fondo: const Color(0xFFFCE7F3), texto: const Color(0xFFBE185D), borde: const Color(0xFFF9A8D4)),
        'completado': StatusColor(fondo: const Color(0xFFD1FAE5), texto: const Color(0xFF047857), borde: const Color(0xFF6EE7B7)),
      },
    );
  }

  StatusColor getDetalleColor(String estado) {
    return estadosDetalle[estado] ?? estadosDetalle['pendiente']!;
  }

  StatusColor getCampaniaColor(String estado) {
    return estadosCampania[estado] ?? estadosCampania['borrador']!;
  }
}
