class Tienda {
  final String id;
  final String nombre;
  final String determinante;
  final String direccion;
  final String ciudad;

  Tienda({
    required this.id,
    required this.nombre,
    required this.determinante,
    required this.direccion,
    required this.ciudad,
  });

  factory Tienda.fromJson(Map<String, dynamic> json) {
    return Tienda(
      id: json['_id'] ?? json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      determinante: json['determinante'] ?? '',
      direccion: json['direccion'] ?? '',
      ciudad: json['ciudad'] ?? '',
    );
  }
}

class Medio {
  final String id;
  final String nombre;
  final String codigo;
  final String tipo;
  final String categoria;

  Medio({
    required this.id,
    required this.nombre,
    required this.codigo,
    required this.tipo,
    required this.categoria,
  });

  factory Medio.fromJson(Map<String, dynamic> json) {
    return Medio(
      id: json['_id'] ?? json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      codigo: json['codigo'] ?? '',
      tipo: json['tipo'] ?? '',
      categoria: json['categoria'] ?? '',
    );
  }
}

class DetalleCampania {
  final Tienda? tienda;
  final Medio? medio;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;
  final String estadoDetalle;
  final List<String> evidenciasAlta;
  final List<String> evidenciasSupervision;
  final List<String> evidenciasBaja;
  final DateTime? fechaAlta;
  final DateTime? fechaSupervision;
  final DateTime? fechaBaja;
  final String? notas;

  DetalleCampania({
    this.tienda,
    this.medio,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
    required this.estadoDetalle,
    required this.evidenciasAlta,
    required this.evidenciasSupervision,
    required this.evidenciasBaja,
    this.fechaAlta,
    this.fechaSupervision,
    this.fechaBaja,
    this.notas,
  });

  factory DetalleCampania.fromJson(Map<String, dynamic> json) {
    return DetalleCampania(
      tienda: json['tienda'] is Map ? Tienda.fromJson(json['tienda']) : null,
      medio: json['medio'] is Map ? Medio.fromJson(json['medio']) : null,
      cantidad: json['cantidad'] ?? 0,
      precioUnitario: (json['precioUnitario'] ?? 0).toDouble(),
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      estadoDetalle: json['estadoDetalle'] ?? 'pendiente',
      evidenciasAlta: List<String>.from(json['evidenciasAlta'] ?? []),
      evidenciasSupervision: List<String>.from(json['evidenciasSupervision'] ?? []),
      evidenciasBaja: List<String>.from(json['evidenciasBaja'] ?? []),
      fechaAlta: json['fechaAlta'] != null ? DateTime.tryParse(json['fechaAlta']) : null,
      fechaSupervision: json['fechaSupervision'] != null ? DateTime.tryParse(json['fechaSupervision']) : null,
      fechaBaja: json['fechaBaja'] != null ? DateTime.tryParse(json['fechaBaja']) : null,
      notas: json['notas'],
    );
  }
}

class Anunciante {
  final String id;
  final String nombre;
  final String codigo;
  final String? logo;

  Anunciante({
    required this.id,
    required this.nombre,
    required this.codigo,
    this.logo,
  });

  factory Anunciante.fromJson(Map<String, dynamic> json) {
    return Anunciante(
      id: json['_id'] ?? json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      codigo: json['codigo'] ?? '',
      logo: json['logo'],
    );
  }
}

class Marca {
  final String id;
  final String nombre;
  final String codigo;
  final String? logo;

  Marca({
    required this.id,
    required this.nombre,
    required this.codigo,
    this.logo,
  });

  factory Marca.fromJson(Map<String, dynamic> json) {
    return Marca(
      id: json['_id'] ?? json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      codigo: json['codigo'] ?? '',
      logo: json['logo'],
    );
  }
}

class Pais {
  final String id;
  final String nombre;
  final String codigo;

  Pais({
    required this.id,
    required this.nombre,
    required this.codigo,
  });

  factory Pais.fromJson(Map<String, dynamic> json) {
    return Pais(
      id: json['_id'] ?? json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      codigo: json['codigo'] ?? '',
    );
  }
}

class Campania {
  final String id;
  final String nombre;
  final String codigo;
  final Anunciante? anunciante;
  final Marca? marca;
  final Pais? pais;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String estado;
  final List<DetalleCampania> detalles;
  final String? notas;
  final DateTime? createdAt;

  // Retailtainment fields
  final bool esRetailtainment;
  final String? tipoRetailtainment; // 'demostracion' | 'canje_compra' | 'canje_dinamica'
  final List<int> diasActivos; // 0=Sunday, 1=Monday, ..., 6=Saturday (empty = all days)
  final List<UpcItem> upcs;
  final List<ConfigCanjePais> configCanje;
  final List<ConfigDinamica> configDinamica;

  Campania({
    required this.id,
    required this.nombre,
    required this.codigo,
    this.anunciante,
    this.marca,
    this.pais,
    required this.fechaInicio,
    required this.fechaFin,
    required this.estado,
    required this.detalles,
    this.notas,
    this.createdAt,
    this.esRetailtainment = false,
    this.tipoRetailtainment,
    this.diasActivos = const [],
    this.upcs = const [],
    this.configCanje = const [],
    this.configDinamica = const [],
  });

  factory Campania.fromJson(Map<String, dynamic> json) {
    return Campania(
      id: json['_id'] ?? json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      codigo: json['codigo'] ?? '',
      anunciante: json['anunciante'] is Map ? Anunciante.fromJson(json['anunciante']) : null,
      marca: json['marca'] is Map ? Marca.fromJson(json['marca']) : null,
      pais: json['pais'] is Map ? Pais.fromJson(json['pais']) : null,
      fechaInicio: DateTime.tryParse(json['fechaInicio'] ?? '') ?? DateTime.now(),
      fechaFin: DateTime.tryParse(json['fechaFin'] ?? '') ?? DateTime.now(),
      estado: json['estado'] ?? 'borrador',
      detalles: (json['detalles'] as List<dynamic>?)
              ?.map((d) => DetalleCampania.fromJson(d))
              .toList() ??
          [],
      notas: json['notas'],
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      // Retailtainment fields
      esRetailtainment: json['esRetailtainment'] ?? false,
      tipoRetailtainment: json['tipoRetailtainment'],
      diasActivos: (json['diasActivos'] as List<dynamic>?)
              ?.map((d) => d as int)
              .toList() ??
          [],
      upcs: (json['upcs'] as List<dynamic>?)
              ?.map((u) => UpcItem.fromJson(u))
              .toList() ??
          [],
      configCanje: (json['configCanje'] as List<dynamic>?)
              ?.map((c) => ConfigCanjePais.fromJson(c))
              .toList() ??
          [],
      configDinamica: (json['configDinamica'] as List<dynamic>?)
              ?.map((d) => ConfigDinamica.fromJson(d))
              .toList() ??
          [],
    );
  }

  int get totalDetalles => detalles.length;

  int get detallesPendientes => detalles.where((d) => d.estadoDetalle == 'pendiente').length;

  int get detallesCompletados => detalles.where((d) => d.estadoDetalle == 'completado').length;

  double get progreso {
    if (detalles.isEmpty) return 0;
    return detallesCompletados / totalDetalles;
  }

  /// Check if today is an active day for this retailtainment campaign
  bool get esDiaActivoHoy {
    if (diasActivos.isEmpty) return true; // All days active
    final hoy = DateTime.now().weekday % 7; // Convert to 0=Sunday format
    return diasActivos.contains(hoy);
  }

  /// Get config for a specific country
  ConfigCanjePais? getConfigCanjePorPais(String paisId) {
    try {
      return configCanje.firstWhere((c) => c.pais == paisId);
    } catch (_) {
      return configCanje.isNotEmpty ? configCanje.first : null;
    }
  }
}

/// UPC Item for product validation (Retailtainment)
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
}

/// Premio (Prize) for redemption (Retailtainment)
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

/// Range of prizes based on ticket amount (Retailtainment)
class RangoPremio {
  final double montoMinimo;
  final double? montoMaximo;
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

  bool containsMonto(double monto) {
    if (monto < montoMinimo) return false;
    if (montoMaximo == null) return true;
    return monto <= montoMaximo!;
  }

  String getRangoLabel(String simbolo) {
    if (montoMaximo == null) {
      return '$simbolo${montoMinimo.toStringAsFixed(0)}+';
    }
    return '$simbolo${montoMinimo.toStringAsFixed(0)} - $simbolo${montoMaximo!.toStringAsFixed(0)}';
  }
}

/// Country-specific redemption configuration (Retailtainment)
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

  RangoPremio? getRangoForMonto(double monto) {
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

/// Dynamic activity configuration (Retailtainment)
class ConfigDinamica {
  final String nombre;
  final String descripcion;
  final String tipoRecompensa;
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
}
