import 'package:flutter/material.dart';

/// Estado de la asignacion RTMT
enum EstadoAsignacion {
  pendiente,
  enProgreso,
  completada,
  incidencia,
  cancelada,
}

extension EstadoAsignacionExtension on EstadoAsignacion {
  String get value {
    switch (this) {
      case EstadoAsignacion.pendiente:
        return 'pendiente';
      case EstadoAsignacion.enProgreso:
        return 'en_progreso';
      case EstadoAsignacion.completada:
        return 'completada';
      case EstadoAsignacion.incidencia:
        return 'incidencia';
      case EstadoAsignacion.cancelada:
        return 'cancelada';
    }
  }

  String get label {
    switch (this) {
      case EstadoAsignacion.pendiente:
        return 'Pendiente';
      case EstadoAsignacion.enProgreso:
        return 'En Progreso';
      case EstadoAsignacion.completada:
        return 'Completada';
      case EstadoAsignacion.incidencia:
        return 'Incidencia';
      case EstadoAsignacion.cancelada:
        return 'Cancelada';
    }
  }

  Color get color {
    switch (this) {
      case EstadoAsignacion.pendiente:
        return Colors.grey;
      case EstadoAsignacion.enProgreso:
        return Colors.blue;
      case EstadoAsignacion.completada:
        return Colors.green;
      case EstadoAsignacion.incidencia:
        return Colors.orange;
      case EstadoAsignacion.cancelada:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case EstadoAsignacion.pendiente:
        return Icons.schedule;
      case EstadoAsignacion.enProgreso:
        return Icons.play_circle_outline;
      case EstadoAsignacion.completada:
        return Icons.check_circle;
      case EstadoAsignacion.incidencia:
        return Icons.warning_amber;
      case EstadoAsignacion.cancelada:
        return Icons.cancel;
    }
  }

  static EstadoAsignacion fromString(String value) {
    switch (value) {
      case 'pendiente':
        return EstadoAsignacion.pendiente;
      case 'en_progreso':
        return EstadoAsignacion.enProgreso;
      case 'completada':
        return EstadoAsignacion.completada;
      case 'incidencia':
        return EstadoAsignacion.incidencia;
      case 'cancelada':
        return EstadoAsignacion.cancelada;
      default:
        return EstadoAsignacion.pendiente;
    }
  }
}

/// Momento RTMT
enum MomentoRTMT {
  inicioActividades,
  laborVenta,
  cierreActividades,
}

extension MomentoRTMTExtension on MomentoRTMT {
  String get value {
    switch (this) {
      case MomentoRTMT.inicioActividades:
        return 'inicio_actividades';
      case MomentoRTMT.laborVenta:
        return 'labor_venta';
      case MomentoRTMT.cierreActividades:
        return 'cierre_actividades';
    }
  }

  String get label {
    switch (this) {
      case MomentoRTMT.inicioActividades:
        return 'Inicio de Actividades';
      case MomentoRTMT.laborVenta:
        return 'Labor de Venta';
      case MomentoRTMT.cierreActividades:
        return 'Cierre de Actividades';
    }
  }

  String get shortLabel {
    switch (this) {
      case MomentoRTMT.inicioActividades:
        return 'Inicio';
      case MomentoRTMT.laborVenta:
        return 'Labor';
      case MomentoRTMT.cierreActividades:
        return 'Cierre';
    }
  }

  IconData get icon {
    switch (this) {
      case MomentoRTMT.inicioActividades:
        return Icons.login;
      case MomentoRTMT.laborVenta:
        return Icons.storefront;
      case MomentoRTMT.cierreActividades:
        return Icons.logout;
    }
  }

  Color get color {
    switch (this) {
      case MomentoRTMT.inicioActividades:
        return Colors.blue;
      case MomentoRTMT.laborVenta:
        return Colors.orange;
      case MomentoRTMT.cierreActividades:
        return Colors.green;
    }
  }

  static MomentoRTMT fromString(String value) {
    switch (value) {
      case 'inicio_actividades':
        return MomentoRTMT.inicioActividades;
      case 'labor_venta':
        return MomentoRTMT.laborVenta;
      case 'cierre_actividades':
        return MomentoRTMT.cierreActividades;
      default:
        return MomentoRTMT.inicioActividades;
    }
  }
}

/// Ubicacion GPS
class Ubicacion {
  final double lat;
  final double lng;
  final String? direccion;

  Ubicacion({
    required this.lat,
    required this.lng,
    this.direccion,
  });

  factory Ubicacion.fromJson(Map<String, dynamic> json) {
    return Ubicacion(
      lat: (json['lat'] ?? 0).toDouble(),
      lng: (json['lng'] ?? 0).toDouble(),
      direccion: json['direccion'],
    );
  }

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        if (direccion != null) 'direccion': direccion,
      };
}

/// Registro de momento
class RegistroMomento {
  final bool completada;
  final bool incidencia;
  final bool incidenciaSupervisor;
  final DateTime? fecha;
  final Ubicacion? ubicacion;
  final String? notas;
  final List<String> evidencias;

  RegistroMomento({
    this.completada = false,
    this.incidencia = false,
    this.incidenciaSupervisor = false,
    this.fecha,
    this.ubicacion,
    this.notas,
    this.evidencias = const [],
  });

  factory RegistroMomento.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return RegistroMomento();
    }
    return RegistroMomento(
      completada: json['completada'] ?? false,
      incidencia: json['incidencia'] ?? false,
      incidenciaSupervisor: json['incidenciaSupervisor'] ?? false,
      fecha: json['fecha'] != null ? DateTime.parse(json['fecha']) : null,
      ubicacion: json['ubicacion'] != null
          ? Ubicacion.fromJson(json['ubicacion'])
          : null,
      notas: json['notas'],
      evidencias: List<String>.from(json['evidencias'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'completada': completada,
        'incidencia': incidencia,
        'incidenciaSupervisor': incidenciaSupervisor,
        if (fecha != null) 'fecha': fecha!.toIso8601String(),
        if (ubicacion != null) 'ubicacion': ubicacion!.toJson(),
        if (notas != null) 'notas': notas,
        'evidencias': evidencias,
      };
}

/// Tienda en asignacion
class TiendaAsignacion {
  final String tiendaId;
  final String determinante;
  final String nombre;
  final String? estado;
  final String? municipio;
  final String? calle;
  final String? cp;
  final String? formatoNombre;
  final String? formatoAbreviacion;
  final double? latitud;
  final double? longitud;

  TiendaAsignacion({
    required this.tiendaId,
    required this.determinante,
    required this.nombre,
    this.estado,
    this.municipio,
    this.calle,
    this.cp,
    this.formatoNombre,
    this.formatoAbreviacion,
    this.latitud,
    this.longitud,
  });

  factory TiendaAsignacion.fromJson(Map<String, dynamic> json) {
    final direccion = json['direccion'] as Map<String, dynamic>?;
    final formato = json['formato'] as Map<String, dynamic>?;
    final ubicacion = json['ubicacion'] as Map<String, dynamic>?;

    return TiendaAsignacion(
      tiendaId: json['tiendaId'] ?? '',
      determinante: json['determinante'] ?? '',
      nombre: json['nombre'] ?? '',
      estado: direccion?['estado'],
      municipio: direccion?['municipio'],
      calle: direccion?['calle'],
      cp: direccion?['cp'],
      formatoNombre: formato?['nombre'],
      formatoAbreviacion: formato?['abreviacion'],
      latitud: ubicacion?['latitud']?.toDouble(),
      longitud: ubicacion?['longitud']?.toDouble(),
    );
  }

  String get direccionCompleta {
    final parts = <String>[];
    if (calle != null && calle!.isNotEmpty) parts.add(calle!);
    if (municipio != null && municipio!.isNotEmpty) parts.add(municipio!);
    if (estado != null && estado!.isNotEmpty) parts.add(estado!);
    if (cp != null && cp!.isNotEmpty) parts.add('CP $cp');
    return parts.join(', ');
  }
}

/// Agencia en asignacion
class AgenciaAsignacion {
  final String agenciaId;
  final String? clave;
  final String? nombre;

  AgenciaAsignacion({
    required this.agenciaId,
    this.clave,
    this.nombre,
  });

  factory AgenciaAsignacion.fromJson(Map<String, dynamic> json) {
    return AgenciaAsignacion(
      agenciaId: json['agenciaId'] ?? '',
      clave: json['clave'],
      nombre: json['nombre'],
    );
  }
}

/// Campaña en asignacion RTMT
class CampAsignacion {
  final String? campId;
  final String uuid;
  final String nombre;
  final bool canjeTicket;
  final bool activacionRetail;
  final int cantidadMomentos;
  final String? medioNombre;
  final String? medioIcono;
  final String? anuncianteNombre;
  final String? marcaNombre;

  CampAsignacion({
    this.campId,
    required this.uuid,
    required this.nombre,
    this.canjeTicket = false,
    this.activacionRetail = false,
    this.cantidadMomentos = 1,
    this.medioNombre,
    this.medioIcono,
    this.anuncianteNombre,
    this.marcaNombre,
  });

  factory CampAsignacion.fromJson(Map<String, dynamic> json) {
    final medio = json['medio'] as Map<String, dynamic>?;
    final anunciante = json['anunciante'] as Map<String, dynamic>?;
    final marca = anunciante?['marca'] as Map<String, dynamic>?;

    return CampAsignacion(
      campId: json['campId'],
      uuid: json['uuid'] ?? '',
      nombre: json['nombre'] ?? '',
      canjeTicket: json['canjeTicket'] ?? false,
      activacionRetail: json['activacionRetail'] ?? false,
      cantidadMomentos: json['cantidadMomentos'] ?? 1,
      medioNombre: medio?['nombre'],
      medioIcono: medio?['icono'],
      anuncianteNombre: anunciante?['nombre'],
      marcaNombre: marca?['nombre'],
    );
  }
}

/// Actividad RTMT
class ActividadRTMT {
  final String? semana;
  final String? anio;
  final String? fecha;
  final String? hora;
  final String? tiempoDinamica;
  final DateTime? fechaDate;

  ActividadRTMT({
    this.semana,
    this.anio,
    this.fecha,
    this.hora,
    this.tiempoDinamica,
    this.fechaDate,
  });

  factory ActividadRTMT.fromJson(Map<String, dynamic> json) {
    DateTime? fechaDate;
    if (json['fechaDate'] != null) {
      fechaDate = DateTime.parse(json['fechaDate']);
    } else if (json['fecha'] != null) {
      // Parse dd/mm/yyyy format
      final parts = json['fecha'].toString().split('/');
      if (parts.length == 3) {
        fechaDate = DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      }
    }

    return ActividadRTMT(
      semana: json['semana'],
      anio: json['anio'],
      fecha: json['fecha'],
      hora: json['hora'],
      tiempoDinamica: json['tiempoDinamica'],
      fechaDate: fechaDate,
    );
  }

  String get fechaFormateada {
    if (fechaDate != null) {
      return '${fechaDate!.day.toString().padLeft(2, '0')}/${fechaDate!.month.toString().padLeft(2, '0')}/${fechaDate!.year}';
    }
    return fecha ?? '';
  }

  String get horaFormateada {
    if (hora != null && hora!.length >= 5) {
      return hora!.substring(0, 5);
    }
    return hora ?? '';
  }
}

/// Producto en asignacion
class ProductoAsignacion {
  final String? upc;
  final String? nombre;
  int intencionesCompra;

  ProductoAsignacion({
    this.upc,
    this.nombre,
    this.intencionesCompra = 0,
  });

  factory ProductoAsignacion.fromJson(Map<String, dynamic> json) {
    return ProductoAsignacion(
      upc: json['upc'],
      nombre: json['nombre'],
      intencionesCompra: json['intencionesCompra'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        if (upc != null) 'upc': upc,
        if (nombre != null) 'nombre': nombre,
        'intencionesCompra': intencionesCompra,
      };
}

/// Premio entregado
class PremioEntregado {
  final String? nombre;
  final String? descripcion;
  int cantidad;

  PremioEntregado({
    this.nombre,
    this.descripcion,
    this.cantidad = 0,
  });

  factory PremioEntregado.fromJson(Map<String, dynamic> json) {
    return PremioEntregado(
      nombre: json['nombre'],
      descripcion: json['descripcion'],
      cantidad: json['cantidad'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        if (nombre != null) 'nombre': nombre,
        if (descripcion != null) 'descripcion': descripcion,
        'cantidad': cantidad,
      };
}

/// Cuestionario RTMT
class CuestionarioRTMT {
  int numClientes;
  int numTickets;

  CuestionarioRTMT({
    this.numClientes = 0,
    this.numTickets = 0,
  });

  factory CuestionarioRTMT.fromJson(Map<String, dynamic>? json) {
    if (json == null) return CuestionarioRTMT();
    return CuestionarioRTMT(
      numClientes: json['numClientes'] ?? 0,
      numTickets: json['numTickets'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'numClientes': numClientes,
        'numTickets': numTickets,
      };
}

/// Asignacion RTMT principal
class AsignacionRTMT {
  final String id;
  final String tipo;
  final String subtipo;
  final TiendaAsignacion tienda;
  final AgenciaAsignacion? agencia;
  final CampAsignacion? camp;
  final ActividadRTMT? actividad;
  final String? periodo;
  final EstadoAsignacion estado;
  final MomentoRTMT? momentoActual;
  final RegistroMomento inicioActividades;
  final RegistroMomento laborVenta;
  final RegistroMomento cierreActividades;
  final CuestionarioRTMT cuestionario;
  final List<ProductoAsignacion> productos;
  final List<PremioEntregado> premios;
  final bool forzarCierre;
  final String? notas;
  final DateTime? createdAt;

  AsignacionRTMT({
    required this.id,
    this.tipo = 'RTMT',
    this.subtipo = 'normal',
    required this.tienda,
    this.agencia,
    this.camp,
    this.actividad,
    this.periodo,
    this.estado = EstadoAsignacion.pendiente,
    this.momentoActual,
    required this.inicioActividades,
    required this.laborVenta,
    required this.cierreActividades,
    required this.cuestionario,
    this.productos = const [],
    this.premios = const [],
    this.forzarCierre = false,
    this.notas,
    this.createdAt,
  });

  factory AsignacionRTMT.fromJson(Map<String, dynamic> json) {
    return AsignacionRTMT(
      id: json['_id'] ?? json['id'] ?? '',
      tipo: json['tipo'] ?? 'RTMT',
      subtipo: json['subtipo'] ?? 'normal',
      tienda: TiendaAsignacion.fromJson(json['tienda'] ?? {}),
      agencia: json['agencia'] != null
          ? AgenciaAsignacion.fromJson(json['agencia'])
          : null,
      camp: json['camp'] != null ? CampAsignacion.fromJson(json['camp']) : null,
      actividad: json['actividad'] != null
          ? ActividadRTMT.fromJson(json['actividad'])
          : null,
      periodo: json['periodo'],
      estado: EstadoAsignacionExtension.fromString(json['estado'] ?? 'pendiente'),
      momentoActual: json['momentoActual'] != null
          ? MomentoRTMTExtension.fromString(json['momentoActual'])
          : null,
      inicioActividades:
          RegistroMomento.fromJson(json['inicioActividades']),
      laborVenta: RegistroMomento.fromJson(json['laborVenta']),
      cierreActividades:
          RegistroMomento.fromJson(json['cierreActividades']),
      cuestionario: CuestionarioRTMT.fromJson(json['cuestionario']),
      productos: (json['productos'] as List<dynamic>?)
              ?.map((p) => ProductoAsignacion.fromJson(p))
              .toList() ??
          [],
      premios: (json['premios'] as List<dynamic>?)
              ?.map((p) => PremioEntregado.fromJson(p))
              .toList() ??
          [],
      forzarCierre: json['forzarCierre'] ?? false,
      notas: json['notas'],
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  /// Verifica si todos los momentos estan completados
  bool get todosLosMomentosCompletados =>
      inicioActividades.completada &&
      laborVenta.completada &&
      cierreActividades.completada;

  /// Verifica si hay alguna incidencia
  bool get tieneIncidencias =>
      inicioActividades.incidencia ||
      laborVenta.incidencia ||
      cierreActividades.incidencia;

  /// Obtiene el siguiente momento a completar
  MomentoRTMT? get siguienteMomento {
    if (!inicioActividades.completada) return MomentoRTMT.inicioActividades;
    if (!laborVenta.completada) return MomentoRTMT.laborVenta;
    if (!cierreActividades.completada) return MomentoRTMT.cierreActividades;
    return null;
  }

  /// Verifica si se puede avanzar al siguiente momento
  bool puedeAvanzarA(MomentoRTMT momento) {
    switch (momento) {
      case MomentoRTMT.inicioActividades:
        return !inicioActividades.completada;
      case MomentoRTMT.laborVenta:
        return inicioActividades.completada &&
            !inicioActividades.incidencia &&
            !laborVenta.completada;
      case MomentoRTMT.cierreActividades:
        return laborVenta.completada &&
            !laborVenta.incidencia &&
            !cierreActividades.completada;
    }
  }

  /// Obtiene el registro de un momento especifico
  RegistroMomento getMomento(MomentoRTMT momento) {
    switch (momento) {
      case MomentoRTMT.inicioActividades:
        return inicioActividades;
      case MomentoRTMT.laborVenta:
        return laborVenta;
      case MomentoRTMT.cierreActividades:
        return cierreActividades;
    }
  }

  /// Progreso de la asignacion (0.0 - 1.0)
  double get progreso {
    int completados = 0;
    if (inicioActividades.completada) completados++;
    if (laborVenta.completada) completados++;
    if (cierreActividades.completada) completados++;
    return completados / 3;
  }

  /// Nombre de la campana
  String get nombreCampana => camp?.nombre ?? 'Sin campaña';

  /// Nombre de la tienda
  String get nombreTienda =>
      '${tienda.formatoAbreviacion ?? ''} ${tienda.nombre}'.trim();

  /// Fecha formateada
  String get fechaFormateada => actividad?.fechaFormateada ?? '';

  /// Hora formateada
  String get horaFormateada => actividad?.horaFormateada ?? '';
}
