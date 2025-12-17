import 'package:flutter/material.dart';

/// UPC Item for product validation
class UpcItem {
  final String codigo;
  final String descripcion;
  final String? marca;

  UpcItem({
    required this.codigo,
    required this.descripcion,
    this.marca,
  });

  factory UpcItem.fromJson(Map<String, dynamic> json) {
    return UpcItem(
      codigo: json['codigo'] ?? '',
      descripcion: json['descripcion'] ?? '',
      marca: json['marca'],
    );
  }

  Map<String, dynamic> toJson() => {
    'codigo': codigo,
    'descripcion': descripcion,
    if (marca != null) 'marca': marca,
  };
}

/// Premio (Prize) for redemption
class Premio {
  final String nombre;
  final String? descripcion;
  final int cantidad;

  Premio({
    required this.nombre,
    this.descripcion,
    required this.cantidad,
  });

  factory Premio.fromJson(Map<String, dynamic> json) {
    return Premio(
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'],
      cantidad: json['cantidad'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    if (descripcion != null) 'descripcion': descripcion,
    'cantidad': cantidad,
  };
}

/// Range of prizes based on ticket amount
class RangoPremio {
  final double montoMinimo;
  final double? montoMaximo; // null = no upper limit
  final List<Premio> premios;

  RangoPremio({
    required this.montoMinimo,
    this.montoMaximo,
    required this.premios,
  });

  factory RangoPremio.fromJson(Map<String, dynamic> json) {
    return RangoPremio(
      montoMinimo: (json['montoMinimo'] ?? 0).toDouble(),
      montoMaximo: json['montoMaximo']?.toDouble(),
      premios: (json['premios'] as List<dynamic>?)
          ?.map((p) => Premio.fromJson(p))
          .toList() ?? [],
    );
  }

  /// Check if a given amount falls within this range
  bool containsMonto(double monto) {
    if (monto < montoMinimo) return false;
    if (montoMaximo == null) return true;
    return monto <= montoMaximo!;
  }

  String get rangoLabel {
    if (montoMaximo == null) {
      return '\$${montoMinimo.toStringAsFixed(0)}+';
    }
    return '\$${montoMinimo.toStringAsFixed(0)} - \$${montoMaximo!.toStringAsFixed(0)}';
  }
}

/// Country-specific redemption configuration
class ConfigCanjePais {
  final String pais;
  final String paisNombre;
  final String moneda;
  final String simboloMoneda;
  final bool validarUpcs;
  final List<RangoPremio> rangos;

  ConfigCanjePais({
    required this.pais,
    required this.paisNombre,
    required this.moneda,
    required this.simboloMoneda,
    required this.validarUpcs,
    required this.rangos,
  });

  factory ConfigCanjePais.fromJson(Map<String, dynamic> json) {
    return ConfigCanjePais(
      pais: json['pais'] ?? '',
      paisNombre: json['paisNombre'] ?? '',
      moneda: json['moneda'] ?? 'USD',
      simboloMoneda: json['simboloMoneda'] ?? '\$',
      validarUpcs: json['validarUpcs'] ?? false,
      rangos: (json['rangos'] as List<dynamic>?)
          ?.map((r) => RangoPremio.fromJson(r))
          .toList() ?? [],
    );
  }

  /// Get the applicable range for a given amount
  RangoPremio? getRangoForMonto(double monto) {
    // Sort ranges by montoMinimo descending to find the highest applicable range
    final sortedRangos = List<RangoPremio>.from(rangos)
      ..sort((a, b) => b.montoMinimo.compareTo(a.montoMinimo));

    for (var rango in sortedRangos) {
      if (rango.containsMonto(monto)) {
        return rango;
      }
    }
    return null;
  }
}

/// Dynamic activity configuration
class ConfigDinamica {
  final String nombre;
  final String descripcion;
  final String tipoRecompensa; // 'producto' | 'descuento' | 'otro'
  final String recompensa;
  final String instrucciones;

  ConfigDinamica({
    required this.nombre,
    required this.descripcion,
    required this.tipoRecompensa,
    required this.recompensa,
    required this.instrucciones,
  });

  factory ConfigDinamica.fromJson(Map<String, dynamic> json) {
    return ConfigDinamica(
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'] ?? '',
      tipoRecompensa: json['tipoRecompensa'] ?? 'producto',
      recompensa: json['recompensa'] ?? '',
      instrucciones: json['instrucciones'] ?? '',
    );
  }

  IconData get tipoIcon {
    switch (tipoRecompensa) {
      case 'producto':
        return Icons.card_giftcard_rounded;
      case 'descuento':
        return Icons.discount_rounded;
      default:
        return Icons.stars_rounded;
    }
  }

  Color get tipoColor {
    switch (tipoRecompensa) {
      case 'producto':
        return Colors.green;
      case 'descuento':
        return Colors.orange;
      default:
        return Colors.purple;
    }
  }
}

/// Retailtainment type enum
enum TipoRetailtainment {
  demostracion,
  canjeCompra,
  canjeDinamica,
}

extension TipoRetailtainmentExtension on TipoRetailtainment {
  String get value {
    switch (this) {
      case TipoRetailtainment.demostracion:
        return 'demostracion';
      case TipoRetailtainment.canjeCompra:
        return 'canje_compra';
      case TipoRetailtainment.canjeDinamica:
        return 'canje_dinamica';
    }
  }

  String get label {
    switch (this) {
      case TipoRetailtainment.demostracion:
        return 'Demostración';
      case TipoRetailtainment.canjeCompra:
        return 'Canje por Compra';
      case TipoRetailtainment.canjeDinamica:
        return 'Canje con Dinámica';
    }
  }

  String get description {
    switch (this) {
      case TipoRetailtainment.demostracion:
        return 'Registro de demostración de producto';
      case TipoRetailtainment.canjeCompra:
        return 'Canje de premios según monto de compra';
      case TipoRetailtainment.canjeDinamica:
        return 'Participación en dinámicas y juegos';
    }
  }

  IconData get icon {
    switch (this) {
      case TipoRetailtainment.demostracion:
        return Icons.present_to_all_rounded;
      case TipoRetailtainment.canjeCompra:
        return Icons.receipt_long_rounded;
      case TipoRetailtainment.canjeDinamica:
        return Icons.casino_rounded;
    }
  }

  Color get color {
    switch (this) {
      case TipoRetailtainment.demostracion:
        return Colors.blue;
      case TipoRetailtainment.canjeCompra:
        return Colors.green;
      case TipoRetailtainment.canjeDinamica:
        return Colors.purple;
    }
  }

  static TipoRetailtainment fromString(String value) {
    switch (value) {
      case 'demostracion':
        return TipoRetailtainment.demostracion;
      case 'canje_compra':
        return TipoRetailtainment.canjeCompra;
      case 'canje_dinamica':
        return TipoRetailtainment.canjeDinamica;
      default:
        return TipoRetailtainment.demostracion;
    }
  }
}

/// Model for registering retailtainment activity
class RegistroRetailtainment {
  final String tipo;
  final String tiendaId;
  final double? montoTicket;
  final List<String>? upcsValidados;
  final List<Premio>? premiosEntregados;
  final int? dinamicaIndex;
  final String? notas;
  final List<String>? evidencias;

  RegistroRetailtainment({
    required this.tipo,
    required this.tiendaId,
    this.montoTicket,
    this.upcsValidados,
    this.premiosEntregados,
    this.dinamicaIndex,
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
    if (notas != null && notas!.isNotEmpty) json['notas'] = notas;
    if (evidencias != null && evidencias!.isNotEmpty) {
      json['evidencias'] = evidencias;
    }

    return json;
  }
}

/// Helper functions
bool esDiaActivo(List<int> diasActivos) {
  if (diasActivos.isEmpty) return true; // All days active
  final hoy = DateTime.now().weekday % 7; // Convert to 0=Sunday format
  return diasActivos.contains(hoy);
}

String getDiaLabel(int dia) {
  const dias = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
  return dias[dia % 7];
}

String getDiaLabelFull(int dia) {
  const dias = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
  return dias[dia % 7];
}
