import 'package:flutter/material.dart';
import 'ticket_canje.dart';

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

/// Evidencia de un momento
class EvidenciaMomento {
  final String url;
  final String tipo;
  final DateTime? fecha;
  final Ubicacion? ubicacion;
  final String? descripcion;
  final String? marcaId;
  final String? marcaNombre;
  final String? productoUpc;
  final bool reportarProblema;

  EvidenciaMomento({
    required this.url,
    this.tipo = 'foto',
    this.fecha,
    this.ubicacion,
    this.descripcion,
    this.marcaId,
    this.marcaNombre,
    this.productoUpc,
    this.reportarProblema = false,
  });

  factory EvidenciaMomento.fromJson(dynamic json) {
    // Si es string (URL simple), crear evidencia básica
    if (json is String) {
      return EvidenciaMomento(url: json);
    }

    // Si es mapa, parsear todos los campos
    final map = json as Map<String, dynamic>;
    return EvidenciaMomento(
      url: map['url'] ?? '',
      tipo: map['tipo'] ?? 'foto',
      fecha: map['fecha'] != null ? DateTime.tryParse(map['fecha'].toString()) : null,
      ubicacion: map['ubicacion'] != null
          ? Ubicacion.fromJson(map['ubicacion'])
          : null,
      descripcion: map['descripcion'],
      marcaId: _parseStringField(map['marcaId']),
      marcaNombre: map['marcaNombre'],
      productoUpc: map['productoUpc'],
      reportarProblema: map['reportarProblema'] ?? false,
    );
  }

  static String? _parseStringField(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) return value['_id']?.toString() ?? value.toString();
    return value.toString();
  }

  Map<String, dynamic> toJson() => {
        'url': url,
        'tipo': tipo,
        if (fecha != null) 'fecha': fecha!.toIso8601String(),
        if (ubicacion != null) 'ubicacion': ubicacion!.toJson(),
        if (descripcion != null) 'descripcion': descripcion,
        if (marcaId != null) 'marcaId': marcaId,
        if (marcaNombre != null) 'marcaNombre': marcaNombre,
        if (productoUpc != null) 'productoUpc': productoUpc,
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
  final List<EvidenciaMomento> evidencias;

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

    // Parsear evidencias que pueden ser strings o objetos
    List<EvidenciaMomento> evidenciasList = [];
    final rawEvidencias = json['evidencias'];
    if (rawEvidencias != null && rawEvidencias is List) {
      evidenciasList = rawEvidencias
          .map((e) => EvidenciaMomento.fromJson(e))
          .toList();
    }

    return RegistroMomento(
      completada: json['completada'] ?? false,
      incidencia: json['incidencia'] ?? false,
      incidenciaSupervisor: json['incidenciaSupervisor'] ?? false,
      fecha: json['fecha'] != null ? DateTime.tryParse(json['fecha'].toString()) : null,
      ubicacion: json['ubicacion'] != null
          ? Ubicacion.fromJson(json['ubicacion'])
          : null,
      notas: json['notas'],
      evidencias: evidenciasList,
    );
  }

  Map<String, dynamic> toJson() => {
        'completada': completada,
        'incidencia': incidencia,
        'incidenciaSupervisor': incidenciaSupervisor,
        if (fecha != null) 'fecha': fecha!.toIso8601String(),
        if (ubicacion != null) 'ubicacion': ubicacion!.toJson(),
        if (notas != null) 'notas': notas,
        'evidencias': evidencias.map((e) => e.toJson()).toList(),
      };

  /// Cuenta las evidencias válidas (sin reportarProblema)
  /// NOTA: Si hay incidencia, significa que al menos una foto tiene problema
  /// y no hay suficientes fotos válidas. El campo reportarProblema puede no
  /// estar disponible en las evidencias embebidas, pero si incidencia=true
  /// sabemos que hay fotos con problema.
  int get evidenciasValidas {
    // Primero intentar contar basado en reportarProblema
    final validasContadas = evidencias.where((e) => !e.reportarProblema).length;

    // Si hay incidencia y todas las evidencias parecen válidas (porque reportarProblema
    // no vino del backend), entonces la incidencia indica que hay fotos con problema
    // En este caso, si incidencia=true y todas las evidencias tienen reportarProblema=false,
    // significa que el campo no fue enviado y debemos asumir que hay menos válidas
    if (incidencia && validasContadas == evidencias.length && evidencias.isNotEmpty) {
      // Si hay incidencia, al menos una foto tiene problema
      // Retornamos total - 1 como mínimo (al menos una tiene problema)
      return (evidencias.length - 1).clamp(0, evidencias.length);
    }

    return validasContadas;
  }

  /// Cuenta las evidencias con problema reportado
  int get evidenciasConProblema {
    final conProblema = evidencias.where((e) => e.reportarProblema).length;

    // Si hay incidencia pero ninguna evidencia tiene reportarProblema=true,
    // significa que el campo no vino del backend y al menos una tiene problema
    if (incidencia && conProblema == 0 && evidencias.isNotEmpty) {
      return 1; // Al menos una tiene problema
    }

    return conProblema;
  }
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

/// Marca de campaña
class MarcaCampania {
  final String? id;
  final String nombre;
  final String? icono;

  MarcaCampania({
    this.id,
    required this.nombre,
    this.icono,
  });

  factory MarcaCampania.fromJson(Map<String, dynamic> json) {
    return MarcaCampania(
      id: _parseId(json['marcaId'] ?? json['_id'] ?? json['id']),
      nombre: json['nombre'] ?? '',
      icono: json['icono'],
    );
  }

  static String? _parseId(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) return value['\$oid']?.toString() ?? value['_id']?.toString() ?? value.toString();
    return value.toString();
  }
}

/// Campaña en asignacion RTMT
class CampAsignacion {
  final String? campId;
  final String uuid;
  final String nombre;
  final bool canjeTicket;
  final bool activacionRetail;
  final String? tipoRetailtainment; // 'demostracion' | 'canje_compra' | 'canje_dinamica'
  final int cantidadMomentos;
  final String? medioNombre;
  final String? medioIcono;
  final String? anuncianteNombre;
  final String? marcaNombre;
  final List<MarcaCampania> marcas;
  final List<ConfigCanje> configCanje;
  final List<ConfigDinamica> configDinamica;

  CampAsignacion({
    this.campId,
    required this.uuid,
    required this.nombre,
    this.canjeTicket = false,
    this.activacionRetail = false,
    this.tipoRetailtainment,
    this.cantidadMomentos = 1,
    this.medioNombre,
    this.medioIcono,
    this.anuncianteNombre,
    this.marcaNombre,
    this.marcas = const [],
    this.configCanje = const [],
    this.configDinamica = const [],
  });

  factory CampAsignacion.fromJson(Map<String, dynamic> json) {
    final medio = json['medio'] as Map<String, dynamic>?;
    final anunciante = json['anunciante'] as Map<String, dynamic>?;
    final marca = anunciante?['marca'] as Map<String, dynamic>?;

    // Parsear array de marcas
    List<MarcaCampania> marcasList = [];
    if (json['marcas'] != null && json['marcas'] is List) {
      marcasList = (json['marcas'] as List)
          .map((m) => MarcaCampania.fromJson(m as Map<String, dynamic>))
          .toList();
    }

    // Parsear array de configCanje
    List<ConfigCanje> configCanjeList = [];
    if (json['configCanje'] != null && json['configCanje'] is List) {
      configCanjeList = (json['configCanje'] as List)
          .map((c) => ConfigCanje.fromJson(c as Map<String, dynamic>))
          .toList();
    }

    // Parsear array de configDinamica
    List<ConfigDinamica> configDinamicaList = [];
    if (json['configDinamica'] != null && json['configDinamica'] is List) {
      configDinamicaList = (json['configDinamica'] as List)
          .map((d) => ConfigDinamica.fromJson(d as Map<String, dynamic>))
          .toList();
    }

    return CampAsignacion(
      campId: json['campId'],
      uuid: json['uuid'] ?? '',
      nombre: json['nombre'] ?? '',
      canjeTicket: json['canjeTicket'] ?? false,
      activacionRetail: json['activacionRetail'] ?? false,
      tipoRetailtainment: json['tipoRetailtainment'],
      cantidadMomentos: json['cantidadMomentos'] ?? 1,
      medioNombre: medio?['nombre'],
      medioIcono: medio?['icono'],
      anuncianteNombre: anunciante?['nombre'],
      marcaNombre: marca?['nombre'],
      marcas: marcasList,
      configCanje: configCanjeList,
      configDinamica: configDinamicaList,
    );
  }

  /// Verifica si es tipo demostración
  bool get esDemostracion => tipoRetailtainment == 'demostracion' || tipoRetailtainment == null;

  /// Verifica si es tipo canje por compra
  bool get esCanjeCompra => tipoRetailtainment == 'canje_compra';

  /// Verifica si es tipo canje con dinámica
  bool get esCanjeDinamica => tipoRetailtainment == 'canje_dinamica';

  /// Obtiene la etiqueta del tipo de retailtainment
  String get tipoLabel {
    switch (tipoRetailtainment) {
      case 'canje_compra':
        return 'Canje por Compra';
      case 'canje_dinamica':
        return 'Canje con Dinámica';
      case 'demostracion':
      default:
        return 'Demostración';
    }
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

    // Primero intentar con fechaDate en formato ISO
    if (json['fechaDate'] != null) {
      try {
        fechaDate = DateTime.parse(json['fechaDate']);
      } catch (_) {}
    }

    // Si no hay fechaDate, parsear del campo fecha en formato dd/mm/yyyy
    if (fechaDate == null && json['fecha'] != null) {
      try {
        final parts = json['fecha'].toString().split('/');
        if (parts.length == 3) {
          fechaDate = DateTime(
            int.parse(parts[2]), // año
            int.parse(parts[1]), // mes
            int.parse(parts[0]), // día
          );
        }
      } catch (_) {}
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

  /// Obtiene la duracion del turno en horas (default 8 horas)
  int get duracionHoras {
    if (tiempoDinamica == null) return 8;
    // tiempoDinamica puede venir como "8" o "8 horas"
    final match = RegExp(r'(\d+)').firstMatch(tiempoDinamica!);
    return match != null ? int.parse(match.group(1)!) : 8;
  }

  /// Obtiene el DateTime de inicio del turno
  DateTime? get horaInicioTurno {
    if (fechaDate == null || hora == null) return null;
    try {
      final parts = hora!.split(':');
      if (parts.length >= 2) {
        return DateTime(
          fechaDate!.year,
          fechaDate!.month,
          fechaDate!.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
      }
    } catch (_) {}
    return null;
  }

  /// Obtiene el DateTime de fin del turno
  DateTime? get horaFinTurno {
    final inicio = horaInicioTurno;
    if (inicio == null) return null;
    return inicio.add(Duration(hours: duracionHoras));
  }

  /// Obtiene el DateTime cuando se habilita el cierre (1 hora antes del fin)
  DateTime? get horaHabilitaCierre {
    final fin = horaFinTurno;
    if (fin == null) return null;
    return fin.subtract(const Duration(hours: 1));
  }

  /// Verifica si ya es hora de habilitar el cierre
  bool get puedeHacerCierre {
    final habilitaCierre = horaHabilitaCierre;
    if (habilitaCierre == null) return true; // Si no hay datos, permitir
    return DateTime.now().isAfter(habilitaCierre);
  }

  /// Formato de hora para mostrar cuando se habilita el cierre
  String get horaHabilitaCierreFormateada {
    final habilitaCierre = horaHabilitaCierre;
    if (habilitaCierre == null) return '';
    return '${habilitaCierre.hour.toString().padLeft(2, '0')}:${habilitaCierre.minute.toString().padLeft(2, '0')}';
  }

  /// Formato de hora de fin del turno
  String get horaFinTurnoFormateada {
    final fin = horaFinTurno;
    if (fin == null) return '';
    return '${fin.hour.toString().padLeft(2, '0')}:${fin.minute.toString().padLeft(2, '0')}';
  }

  /// Verifica si la fecha de la actividad es hoy
  bool get esHoy {
    // Si no hay fecha, asumimos que es de hoy para mantener compatibilidad
    if (fechaDate == null) return true;
    final hoy = DateTime.now();
    return fechaDate!.year == hoy.year &&
        fechaDate!.month == hoy.month &&
        fechaDate!.day == hoy.day;
  }

  /// Verifica si la fecha de la actividad es de un dia pasado
  bool get esDiaPasado {
    // Si no hay fecha, NO es dia pasado (se asume hoy)
    if (fechaDate == null) return false;
    final hoy = DateTime.now();
    final inicioHoy = DateTime(hoy.year, hoy.month, hoy.day);
    return fechaDate!.isBefore(inicioHoy);
  }

  /// Verifica si la fecha de la actividad es de un dia futuro
  bool get esDiaFuturo {
    // Si no hay fecha, NO es dia futuro (se asume hoy)
    if (fechaDate == null) return false;
    final hoy = DateTime.now();
    final finHoy = DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59);
    return fechaDate!.isAfter(finHoy);
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
        'upc': upc ?? '',
        'nombre': nombre ?? '',
        'intenciones': intencionesCompra,
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

/// Cierre habilitado por supervisor
class CierreHabilitadoPorSupervisor {
  final bool habilitado;
  final String? supervisorId;
  final DateTime? fecha;
  final String? motivo;

  CierreHabilitadoPorSupervisor({
    this.habilitado = false,
    this.supervisorId,
    this.fecha,
    this.motivo,
  });

  factory CierreHabilitadoPorSupervisor.fromJson(Map<String, dynamic>? json) {
    if (json == null) return CierreHabilitadoPorSupervisor();
    return CierreHabilitadoPorSupervisor(
      habilitado: json['habilitado'] ?? false,
      supervisorId: json['supervisorId']?.toString(),
      fecha: json['fecha'] != null ? DateTime.tryParse(json['fecha'].toString()) : null,
      motivo: json['motivo'],
    );
  }
}

/// Ticket de canje registrado en la asignación
class TicketCanjeAsignacion {
  final String? id;
  final String marcaId;
  final String marcaNombre;
  final double monto;
  final String? fotoUrl;
  final DateTime? fecha;
  final Map<String, dynamic>? premioGanado;

  TicketCanjeAsignacion({
    this.id,
    required this.marcaId,
    required this.marcaNombre,
    required this.monto,
    this.fotoUrl,
    this.fecha,
    this.premioGanado,
  });

  factory TicketCanjeAsignacion.fromJson(Map<String, dynamic> json) {
    return TicketCanjeAsignacion(
      id: json['_id']?.toString() ?? json['id']?.toString(),
      marcaId: json['marcaId']?.toString() ?? '',
      marcaNombre: json['marcaNombre'] ?? '',
      monto: (json['monto'] ?? 0).toDouble(),
      fotoUrl: json['fotoUrl'],
      fecha: json['fecha'] != null ? DateTime.tryParse(json['fecha'].toString()) : null,
      premioGanado: json['premioGanado'] as Map<String, dynamic>?,
    );
  }

  String? get premioNombre => premioGanado?['nombre'];
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
  final List<TicketCanjeAsignacion> ticketsCanje;
  final List<ParticipacionDinamica> participacionesDinamica;
  final bool forzarCierre;
  final CierreHabilitadoPorSupervisor? cierreHabilitadoPorSupervisor;
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
    this.ticketsCanje = const [],
    this.participacionesDinamica = const [],
    this.forzarCierre = false,
    this.cierreHabilitadoPorSupervisor,
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
      ticketsCanje: (json['ticketsCanje'] as List<dynamic>?)
              ?.map((t) => TicketCanjeAsignacion.fromJson(t))
              .toList() ??
          [],
      participacionesDinamica: (json['participacionesDinamica'] as List<dynamic>?)
              ?.map((p) => ParticipacionDinamica.fromJson(p))
              .toList() ??
          [],
      forzarCierre: json['forzarCierre'] ?? false,
      cierreHabilitadoPorSupervisor: json['cierreHabilitadoPorSupervisor'] != null
          ? CierreHabilitadoPorSupervisor.fromJson(json['cierreHabilitadoPorSupervisor'])
          : null,
      notas: json['notas'],
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  /// Verifica si el cierre fue habilitado por el supervisor
  bool get cierreHabilitado =>
      forzarCierre || (cierreHabilitadoPorSupervisor?.habilitado ?? false);

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
  /// IMPORTANTE: Si hay incidencia en un momento anterior, NO se puede avanzar
  bool puedeAvanzarA(MomentoRTMT momento) {
    switch (momento) {
      case MomentoRTMT.inicioActividades:
        // Solo puede subir inicio si NO está completado
        // Si tiene incidencia, aún puede corregir (se maneja en la UI)
        return !inicioActividades.completada || inicioActividades.incidencia;
      case MomentoRTMT.laborVenta:
        // Para labor de venta:
        // 1. Inicio debe estar completado
        // 2. Inicio NO debe tener incidencia (si tiene, debe corregir primero)
        // 3. Labor de venta no debe estar completada (o tiene incidencia para corregir)
        if (inicioActividades.incidencia) return false; // BLOQUEO: incidencia en inicio
        if (!inicioActividades.completada) return false; // BLOQUEO: inicio no completado
        return !laborVenta.completada || laborVenta.incidencia;
      case MomentoRTMT.cierreActividades:
        // Para cierre:
        // 1. Inicio no debe tener incidencia
        // 2. Labor de venta debe estar completada
        // 3. Labor de venta NO debe tener incidencia
        // 4. Cierre no debe estar completado (o tiene incidencia para corregir)
        if (inicioActividades.incidencia) return false; // BLOQUEO: incidencia en inicio
        if (laborVenta.incidencia) return false; // BLOQUEO: incidencia en labor
        if (!laborVenta.completada) return false; // BLOQUEO: labor no completada
        if (cierreActividades.completada && !cierreActividades.incidencia) return false;
        // Si el supervisor habilitó el cierre, permitir avanzar
        if (cierreHabilitado) return true;
        // Verificar si ya es hora de hacer cierre (1 hora antes del fin del turno)
        return actividad?.puedeHacerCierre ?? true;
    }
  }

  /// Verifica si un momento específico tiene incidencia pendiente de corregir
  bool tieneIncidenciaPendiente(MomentoRTMT momento) {
    switch (momento) {
      case MomentoRTMT.inicioActividades:
        return inicioActividades.incidencia;
      case MomentoRTMT.laborVenta:
        return laborVenta.incidencia;
      case MomentoRTMT.cierreActividades:
        return cierreActividades.incidencia;
    }
  }

  /// Obtiene el momento que tiene la primera incidencia (para mostrar al usuario qué corregir)
  MomentoRTMT? get momentoConIncidencia {
    if (inicioActividades.incidencia) return MomentoRTMT.inicioActividades;
    if (laborVenta.incidencia) return MomentoRTMT.laborVenta;
    if (cierreActividades.incidencia) return MomentoRTMT.cierreActividades;
    return null;
  }

  /// Verifica si el cierre esta bloqueado por tiempo
  bool get cierreBloqueadoPorTiempo {
    final condicionesBasicas = laborVenta.completada &&
        !laborVenta.incidencia &&
        !cierreActividades.completada;
    if (!condicionesBasicas) return false;
    // Si el supervisor habilitó el cierre, no está bloqueado
    if (cierreHabilitado) return false;
    // Si las condiciones basicas se cumplen pero no puede hacer cierre, es por tiempo
    return !(actividad?.puedeHacerCierre ?? true);
  }

  /// Mensaje de cuando se habilita el cierre
  String get mensajeCierreHabilitacion {
    // Si el supervisor habilitó el cierre, mostrar ese mensaje
    if (cierreHabilitadoPorSupervisor?.habilitado ?? false) {
      return 'El supervisor habilitó tu cierre';
    }
    if (actividad?.horaHabilitaCierre == null) return '';
    return 'El cierre se habilita a las ${actividad!.horaHabilitaCierreFormateada}';
  }

  /// Verifica si el turno ya paso (hora actual > hora fin del turno)
  bool get turnoYaPaso {
    // Si es un día pasado, el turno ya pasó
    if (actividad?.esDiaPasado ?? false) return true;
    // Si es hoy, verificar la hora de fin
    final horaFin = actividad?.horaFinTurno;
    if (horaFin == null) return false;
    return DateTime.now().isAfter(horaFin);
  }

  /// Verifica si la asignacion es de un dia pasado
  bool get esDeDiaPasado {
    return actividad?.esDiaPasado ?? false;
  }

  /// Verifica si la asignacion debe mostrarse en "Terminadas"
  /// Solo asignaciones de dias PASADOS (no incluye las de hoy)
  bool get estaTerminada {
    // Solo las de días pasados van a terminadas
    // Si no hay actividad o fecha, NO es dia pasado
    return esDeDiaPasado;
  }

  /// Verifica si la asignacion esta activa (solo las de HOY)
  bool get estaActiva {
    if (estado == EstadoAsignacion.cancelada) return false;
    // Si no hay actividad, asumimos que es de hoy
    if (actividad == null) return true;
    // Solo las de hoy van a activas
    return actividad!.esHoy;
  }

  /// Verifica si la asignacion es proxima (dias FUTUROS)
  bool get esProxima {
    if (estado == EstadoAsignacion.cancelada) return false;
    return actividad?.esDiaFuturo ?? false;
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
