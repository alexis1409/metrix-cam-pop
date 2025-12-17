import 'package:flutter/material.dart';

class Clave {
  final String id;
  final String codigo;
  final String descripcion;
  final String tipo; // "positivo" | "negativo"
  final String? medioId; // null = genérica
  final String? color;
  final String? icono;
  final int orden;
  final bool isActive;

  Clave({
    required this.id,
    required this.codigo,
    required this.descripcion,
    required this.tipo,
    this.medioId,
    this.color,
    this.icono,
    required this.orden,
    required this.isActive,
  });

  factory Clave.fromJson(Map<String, dynamic> json) {
    // Handle medioId which can be a String, Map (populated), or null
    String? medioId;
    final rawMedioId = json['medioId'];
    if (rawMedioId is String) {
      medioId = rawMedioId;
    } else if (rawMedioId is Map) {
      medioId = rawMedioId['_id']?.toString() ?? rawMedioId['id']?.toString();
    }

    return Clave(
      id: json['_id'] ?? json['id'] ?? '',
      codigo: json['codigo'] ?? '',
      descripcion: json['descripcion'] ?? '',
      tipo: json['tipo'] ?? 'positivo',
      medioId: medioId,
      color: json['color'],
      icono: json['icono'],
      orden: json['orden'] ?? 0,
      isActive: json['isActive'] ?? true,
    );
  }

  bool get isPositivo => tipo == 'positivo';
  bool get isNegativo => tipo == 'negativo';
  bool get isGenerica => medioId == null;

  Color get displayColor {
    if (color != null && color!.isNotEmpty) {
      try {
        final hexColor = color!.replaceAll('#', '');
        return Color(int.parse('FF$hexColor', radix: 16));
      } catch (_) {}
    }
    return isPositivo ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
  }

  IconData get displayIcon {
    if (isPositivo) {
      return Icons.check_circle_rounded;
    } else {
      return Icons.cancel_rounded;
    }
  }
}
