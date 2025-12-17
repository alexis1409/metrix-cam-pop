class TiendaInfo {
  final String id;
  final String nombre;
  final String determinante;
  final String direccion;
  final String ciudad;
  final String? estado;
  final PaisInfo? pais;
  final FormatoInfo? formato;
  final double? latitud;
  final double? longitud;

  TiendaInfo({
    required this.id,
    required this.nombre,
    required this.determinante,
    required this.direccion,
    required this.ciudad,
    this.estado,
    this.pais,
    this.formato,
    this.latitud,
    this.longitud,
  });

  factory TiendaInfo.fromJson(Map<String, dynamic> json) {
    // Support both direct lat/lng and GeoJSON format
    double? lat = (json['latitud'] ?? json['lat'])?.toDouble();
    double? lng = (json['longitud'] ?? json['lng'] ?? json['lon'])?.toDouble();

    // Parse GeoJSON location format: {"type": "Point", "coordinates": [lng, lat]}
    if ((lat == null || lng == null) && json['location'] is Map) {
      final location = json['location'] as Map<String, dynamic>;
      final coordinates = location['coordinates'];
      if (coordinates is List && coordinates.length >= 2) {
        lng = (coordinates[0] as num?)?.toDouble();
        lat = (coordinates[1] as num?)?.toDouble();
      }
    }

    return TiendaInfo(
      id: json['_id'] ?? json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      determinante: json['determinante'] ?? '',
      direccion: json['direccion'] ?? '',
      ciudad: json['ciudad'] ?? '',
      estado: json['estado'],
      pais: json['pais'] is Map ? PaisInfo.fromJson(json['pais']) : null,
      formato: json['formato'] is Map ? FormatoInfo.fromJson(json['formato']) : null,
      latitud: lat,
      longitud: lng,
    );
  }

  bool get hasCoordinates => latitud != null && longitud != null;

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'nombre': nombre,
      'determinante': determinante,
      'direccion': direccion,
      'ciudad': ciudad,
      'estado': estado,
      'pais': pais?.toJson(),
      'formato': formato?.toJson(),
      'latitud': latitud,
      'longitud': longitud,
    };
  }
}

class PaisInfo {
  final String id;
  final String nombre;
  final String codigo;

  PaisInfo({
    required this.id,
    required this.nombre,
    required this.codigo,
  });

  factory PaisInfo.fromJson(Map<String, dynamic> json) {
    return PaisInfo(
      id: json['_id'] ?? json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      codigo: json['codigo'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'nombre': nombre,
      'codigo': codigo,
    };
  }
}

class FormatoInfo {
  final String id;
  final String nombre;

  FormatoInfo({
    required this.id,
    required this.nombre,
  });

  factory FormatoInfo.fromJson(Map<String, dynamic> json) {
    return FormatoInfo(
      id: json['_id'] ?? json['id'] ?? '',
      nombre: json['nombre'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'nombre': nombre,
    };
  }
}

class MedioInfo {
  final String id;
  final String nombre;
  final String codigo;
  final String tipo;
  final String categoria;

  MedioInfo({
    required this.id,
    required this.nombre,
    required this.codigo,
    required this.tipo,
    required this.categoria,
  });

  factory MedioInfo.fromJson(Map<String, dynamic> json) {
    return MedioInfo(
      id: json['_id'] ?? json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      codigo: json['codigo'] ?? '',
      tipo: json['tipo'] ?? '',
      categoria: json['categoria'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'nombre': nombre,
      'codigo': codigo,
      'tipo': tipo,
      'categoria': categoria,
    };
  }
}

class CampaniaInfo {
  final String id;
  final String codigo;
  final String nombre;
  final String estado;
  final DateTime fechaInicio;
  final DateTime fechaFin;

  CampaniaInfo({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.estado,
    required this.fechaInicio,
    required this.fechaFin,
  });

  factory CampaniaInfo.fromJson(Map<String, dynamic> json) {
    return CampaniaInfo(
      id: json['_id'] ?? json['id'] ?? '',
      codigo: json['codigo'] ?? '',
      nombre: json['nombre'] ?? '',
      estado: json['estado'] ?? '',
      fechaInicio: DateTime.tryParse(json['fechaInicio'] ?? '') ?? DateTime.now(),
      fechaFin: DateTime.tryParse(json['fechaFin'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'codigo': codigo,
      'nombre': nombre,
      'estado': estado,
      'fechaInicio': fechaInicio.toIso8601String(),
      'fechaFin': fechaFin.toIso8601String(),
    };
  }
}

class TiendaPendiente {
  final TiendaInfo tienda;
  final MedioInfo medio;
  final int cantidad;
  final CampaniaInfo campania;
  final String estadoDetalle;
  final int detalleIndex;
  final List<String> evidenciasAlta;
  final List<String> evidenciasSupervision;
  final List<String> evidenciasBaja;

  TiendaPendiente({
    required this.tienda,
    required this.medio,
    required this.cantidad,
    required this.campania,
    required this.estadoDetalle,
    required this.detalleIndex,
    required this.evidenciasAlta,
    required this.evidenciasSupervision,
    required this.evidenciasBaja,
  });

  factory TiendaPendiente.fromJson(Map<String, dynamic> json) {
    return TiendaPendiente(
      tienda: TiendaInfo.fromJson(json['tienda'] ?? {}),
      medio: MedioInfo.fromJson(json['medio'] ?? {}),
      cantidad: json['cantidad'] ?? 0,
      campania: CampaniaInfo.fromJson(json['campania'] ?? {}),
      estadoDetalle: json['faseActual'] ?? json['estadoDetalle'] ?? json['estado'] ?? 'pendiente',
      detalleIndex: json['detalleIndex'] ?? json['index'] ?? 0,
      evidenciasAlta: List<String>.from(json['evidenciasAlta'] ?? []),
      evidenciasSupervision: List<String>.from(json['evidenciasSupervision'] ?? []),
      evidenciasBaja: List<String>.from(json['evidenciasBaja'] ?? []),
    );
  }

  String get estadoLabel {
    switch (estadoDetalle) {
      case 'pendiente':
        return 'Pendiente';
      case 'alta':
        return 'Alta';
      case 'supervision':
        return 'Supervisión';
      case 'baja':
        return 'Baja';
      case 'completado':
        return 'Completado';
      default:
        return estadoDetalle;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'tienda': tienda.toJson(),
      'medio': medio.toJson(),
      'cantidad': cantidad,
      'campania': campania.toJson(),
      'estadoDetalle': estadoDetalle,
      'detalleIndex': detalleIndex,
      'evidenciasAlta': evidenciasAlta,
      'evidenciasSupervision': evidenciasSupervision,
      'evidenciasBaja': evidenciasBaja,
    };
  }
}
