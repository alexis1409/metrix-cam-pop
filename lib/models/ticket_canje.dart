/// Modelo para ticket de canje por compra
class TicketCanje {
  final String? id;
  final String asignacionId;
  final String marcaId;
  final String marcaNombre;
  final double monto;
  final String? fotoUrl;
  final String? fotoBase64;
  final double? latitud;
  final double? longitud;
  final String? direccion;
  final DateTime fecha;
  final PremioGanado? premioGanado;

  TicketCanje({
    this.id,
    required this.asignacionId,
    required this.marcaId,
    required this.marcaNombre,
    required this.monto,
    this.fotoUrl,
    this.fotoBase64,
    this.latitud,
    this.longitud,
    this.direccion,
    required this.fecha,
    this.premioGanado,
  });

  factory TicketCanje.fromJson(Map<String, dynamic> json) {
    return TicketCanje(
      id: json['_id'] ?? json['id'],
      asignacionId: json['asignacionId'] ?? '',
      marcaId: json['marcaId'] ?? '',
      marcaNombre: json['marcaNombre'] ?? '',
      monto: (json['monto'] ?? 0).toDouble(),
      fotoUrl: json['fotoUrl'],
      fotoBase64: json['fotoBase64'],
      latitud: json['ubicacion']?['lat']?.toDouble(),
      longitud: json['ubicacion']?['lng']?.toDouble(),
      direccion: json['ubicacion']?['direccion'],
      fecha: json['fecha'] != null
          ? DateTime.parse(json['fecha'])
          : DateTime.now(),
      premioGanado: json['premioGanado'] != null
          ? PremioGanado.fromJson(json['premioGanado'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) '_id': id,
      'asignacionId': asignacionId,
      'marcaId': marcaId,
      'marcaNombre': marcaNombre,
      'monto': monto,
      if (fotoUrl != null) 'fotoUrl': fotoUrl,
      if (fotoBase64 != null) 'fotoBase64': fotoBase64,
      'ubicacion': {
        'lat': latitud,
        'lng': longitud,
        if (direccion != null) 'direccion': direccion,
      },
      'fecha': fecha.toIso8601String(),
      if (premioGanado != null) 'premioGanado': premioGanado!.toJson(),
    };
  }
}

/// Premio ganado por el ticket
class PremioGanado {
  final String nombre;
  final String? descripcion;
  final int cantidad;
  final String rangoId;
  final double montoMinimo;
  final double? montoMaximo;

  PremioGanado({
    required this.nombre,
    this.descripcion,
    required this.cantidad,
    required this.rangoId,
    required this.montoMinimo,
    this.montoMaximo,
  });

  factory PremioGanado.fromJson(Map<String, dynamic> json) {
    return PremioGanado(
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'],
      cantidad: json['cantidad'] ?? 0,
      rangoId: json['rangoId'] ?? '',
      montoMinimo: (json['montoMinimo'] ?? 0).toDouble(),
      montoMaximo: json['montoMaximo']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      if (descripcion != null) 'descripcion': descripcion,
      'cantidad': cantidad,
      'rangoId': rangoId,
      'montoMinimo': montoMinimo,
      if (montoMaximo != null) 'montoMaximo': montoMaximo,
    };
  }
}

/// Configuración de canje por país
class ConfigCanje {
  final String paisId;
  final String paisNombre;
  final String moneda;
  final String simboloMoneda;
  final bool validarUpcs;
  final List<RangoPremio> rangos;

  ConfigCanje({
    required this.paisId,
    required this.paisNombre,
    required this.moneda,
    required this.simboloMoneda,
    required this.validarUpcs,
    required this.rangos,
  });

  factory ConfigCanje.fromJson(Map<String, dynamic> json) {
    return ConfigCanje(
      paisId: json['pais']?.toString() ?? json['_id']?.toString() ?? '',
      paisNombre: json['paisNombre'] ?? '',
      moneda: json['moneda'] ?? 'MXN',
      simboloMoneda: json['simboloMoneda'] ?? '\$',
      validarUpcs: json['validarUpcs'] ?? false,
      rangos: (json['rangos'] as List<dynamic>?)
              ?.map((r) => RangoPremio.fromJson(r))
              .toList() ??
          [],
    );
  }

  /// Encuentra el premio correspondiente al monto del ticket
  /// Ordena los rangos de mayor a menor para encontrar el mejor premio posible
  PremioGanado? encontrarPremio(double monto) {
    // Ordenar rangos de mayor a menor por montoMinimo
    // Así encontramos el rango más alto que aplique primero
    final rangosOrdenados = List<RangoPremio>.from(rangos)
      ..sort((a, b) => b.montoMinimo.compareTo(a.montoMinimo));

    for (final rango in rangosOrdenados) {
      final cumpleMinimo = monto >= rango.montoMinimo;
      final cumpleMaximo = rango.montoMaximo == null || monto <= rango.montoMaximo!;

      if (cumpleMinimo && cumpleMaximo && rango.premios.isNotEmpty) {
        final premio = rango.premios.first;
        return PremioGanado(
          nombre: premio.nombre,
          descripcion: premio.descripcion,
          cantidad: premio.cantidad,
          rangoId: rango.id ?? '',
          montoMinimo: rango.montoMinimo,
          montoMaximo: rango.montoMaximo,
        );
      }
    }
    return null;
  }
}

/// Rango de monto con premios
class RangoPremio {
  final String? id;
  final double montoMinimo;
  final double? montoMaximo;
  final List<Premio> premios;

  RangoPremio({
    this.id,
    required this.montoMinimo,
    this.montoMaximo,
    required this.premios,
  });

  factory RangoPremio.fromJson(Map<String, dynamic> json) {
    return RangoPremio(
      id: json['_id']?.toString(),
      montoMinimo: (json['montoMinimo'] ?? 0).toDouble(),
      montoMaximo: json['montoMaximo']?.toDouble(),
      premios: (json['premios'] as List<dynamic>?)
              ?.map((p) => Premio.fromJson(p))
              .toList() ??
          [],
    );
  }

  String get rangoLabel {
    if (montoMaximo == null) {
      return '\$${montoMinimo.toStringAsFixed(0)}+';
    }
    return '\$${montoMinimo.toStringAsFixed(0)} - \$${montoMaximo!.toStringAsFixed(0)}';
  }
}

/// Premio individual
class Premio {
  final String? id;
  final String nombre;
  final String? descripcion;
  final int cantidad;

  Premio({
    this.id,
    required this.nombre,
    this.descripcion,
    required this.cantidad,
  });

  factory Premio.fromJson(Map<String, dynamic> json) {
    return Premio(
      id: json['_id']?.toString(),
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'],
      cantidad: json['cantidad'] ?? 0,
    );
  }
}

/// Configuración de dinámica para canje_dinamica
class ConfigDinamica {
  final String? id;
  final String nombre;
  final String descripcion;
  final String tipoRecompensa; // 'producto' | 'descuento' | 'otro'
  final String recompensa;
  final String? instrucciones;

  ConfigDinamica({
    this.id,
    required this.nombre,
    required this.descripcion,
    required this.tipoRecompensa,
    required this.recompensa,
    this.instrucciones,
  });

  factory ConfigDinamica.fromJson(Map<String, dynamic> json) {
    return ConfigDinamica(
      id: json['_id']?.toString(),
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'] ?? '',
      tipoRecompensa: json['tipoRecompensa'] ?? 'otro',
      recompensa: json['recompensa'] ?? '',
      instrucciones: json['instrucciones'],
    );
  }

  /// Icono según tipo de recompensa
  String get tipoRecompensaLabel {
    switch (tipoRecompensa) {
      case 'producto':
        return 'Producto';
      case 'descuento':
        return 'Descuento';
      default:
        return 'Premio';
    }
  }
}

/// Participación en una dinámica
class ParticipacionDinamica {
  final String? id;
  final String dinamicaNombre;
  final String? fotoUrl;
  final DateTime? fecha;
  final String? recompensaEntregada;
  final bool completada;

  ParticipacionDinamica({
    this.id,
    required this.dinamicaNombre,
    this.fotoUrl,
    this.fecha,
    this.recompensaEntregada,
    this.completada = false,
  });

  factory ParticipacionDinamica.fromJson(Map<String, dynamic> json) {
    return ParticipacionDinamica(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      dinamicaNombre: json['dinamicaNombre'] ?? '',
      fotoUrl: json['fotoUrl'],
      fecha: json['fecha'] != null ? DateTime.tryParse(json['fecha'].toString()) : null,
      recompensaEntregada: json['recompensaEntregada'],
      completada: json['completada'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) '_id': id,
    'dinamicaNombre': dinamicaNombre,
    if (fotoUrl != null) 'fotoUrl': fotoUrl,
    if (fecha != null) 'fecha': fecha!.toIso8601String(),
    if (recompensaEntregada != null) 'recompensaEntregada': recompensaEntregada,
    'completada': completada,
  };
}
