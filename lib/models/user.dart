/// Roles específicos para Retailtainment
enum RolRetailtainment {
  impulsador, // Linked to ONE store only per project
  supervisor_retailtainment, // Can supervise MULTIPLE stores
}

/// Agencia model for Retailtainment
class Agencia {
  final String id;
  final String nombre;
  final String? codigo;
  final bool isActive;

  Agencia({
    required this.id,
    required this.nombre,
    this.codigo,
    this.isActive = true,
  });

  factory Agencia.fromJson(Map<String, dynamic> json) {
    return Agencia(
      id: json['_id'] ?? json['id'] ?? '',
      nombre: json['nombre'] ?? '',
      codigo: json['codigo'],
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'codigo': codigo,
    'isActive': isActive,
  };
}

class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final bool isActive;
  final String? phone;
  final String? agenciaId;
  final DateTime? lastLogin;

  // Retailtainment-specific fields
  final RolRetailtainment? rolRetailtainment;
  final Agencia? agenciaRetailtainment;
  final List<String> tiendasAsignadas; // Store IDs assigned to this user

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    this.phone,
    this.agenciaId,
    this.lastLogin,
    this.rolRetailtainment,
    this.agenciaRetailtainment,
    this.tiendasAsignadas = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Parse Retailtainment role - can come from 'role' or 'rolRetailtainment'
    RolRetailtainment? rolRt;
    final role = json['role'] ?? '';
    final rolRtStr = json['rolRetailtainment'] ?? role;
    if (rolRtStr == 'impulsador') {
      rolRt = RolRetailtainment.impulsador;
    } else if (rolRtStr == 'supervisor_retailtainment') {
      rolRt = RolRetailtainment.supervisor_retailtainment;
    }

    // Parse agencia retailtainment
    Agencia? agenciaRt;
    final agenciaRtData = json['agenciaRetailtainment'];
    if (agenciaRtData is Map<String, dynamic>) {
      agenciaRt = Agencia.fromJson(agenciaRtData);
    } else if (agenciaRtData is String && agenciaRtData.isNotEmpty) {
      agenciaRt = Agencia(id: agenciaRtData, nombre: '');
    }

    // Parse tiendas asignadas
    List<String> tiendas = [];
    final tiendasData = json['tiendasAsignadas'];
    if (tiendasData is List) {
      tiendas = tiendasData.map((t) {
        if (t is Map<String, dynamic>) {
          return (t['_id'] ?? t['id'] ?? '').toString();
        }
        return t.toString();
      }).where((id) => id.isNotEmpty).toList();
    }

    return User(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
      isActive: json['isActive'] ?? true,
      phone: json['phone'],
      agenciaId: json['agencia'],
      lastLogin: json['lastLogin'] != null
          ? DateTime.tryParse(json['lastLogin'])
          : null,
      rolRetailtainment: rolRt,
      agenciaRetailtainment: agenciaRt,
      tiendasAsignadas: tiendas,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'isActive': isActive,
      'phone': phone,
      'agencia': agenciaId,
      'lastLogin': lastLogin?.toIso8601String(),
      'rolRetailtainment': rolRetailtainment?.name,
      'agenciaRetailtainment': agenciaRetailtainment?.toJson(),
      'tiendasAsignadas': tiendasAsignadas,
    };
  }

  bool get isSuperAdmin => role == 'super_admin';
  bool get isOperativo => role == 'operativo';
  bool get isAgenciaAdmin => role == 'agencia_admin';
  bool get isInstalador => role == 'instalador';

  // Retailtainment role helpers
  bool get isImpulsador => rolRetailtainment == RolRetailtainment.impulsador;
  bool get isSupervisorRetailtainment => rolRetailtainment == RolRetailtainment.supervisor_retailtainment;
  bool get hasRetailtainmentRole => rolRetailtainment != null;

  // Navigation helpers - role-based menu visibility
  /// User should ONLY see Retailtainment (impulsador or supervisor_retailtainment)
  bool get isRetailtainmentOnly => isImpulsador || isSupervisorRetailtainment;

  /// User can access Retailtainment section
  bool get canSeeRetailtainment => isRetailtainmentOnly || isSuperAdmin || isOperativo;

  /// User can see regular campaigns (instalaciones, etc.)
  bool get canSeeCampaniasRegulares => !isRetailtainmentOnly;

  /// Check if user can access a specific store for Retailtainment
  bool canAccessTienda(String tiendaId) {
    // Super admins and operativos can access all stores
    if (isSuperAdmin || isOperativo) return true;

    // If no Retailtainment role, can access all (regular behavior)
    if (!hasRetailtainmentRole) return true;

    // Impulsador/Supervisor can only access assigned stores
    return tiendasAsignadas.contains(tiendaId);
  }

  /// Get the single assigned store ID for impulsador
  String? get tiendaAsignadaImpulsador {
    if (!isImpulsador || tiendasAsignadas.isEmpty) return null;
    return tiendasAsignadas.first;
  }
}
