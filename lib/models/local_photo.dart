class LocalPhoto {
  final String id;
  final String filePath;
  final String fileName;
  final String tiendaId; // 'desconocido' si no hay tienda cercana
  final String tiendaNombre;
  final double? latitud;
  final double? longitud;
  final String? userId;      // ID del usuario que tomó la foto
  final String? userName;    // Nombre del usuario
  final DateTime createdAt;

  LocalPhoto({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.tiendaId,
    required this.tiendaNombre,
    this.latitud,
    this.longitud,
    this.userId,
    this.userName,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'filePath': filePath,
    'fileName': fileName,
    'tiendaId': tiendaId,
    'tiendaNombre': tiendaNombre,
    'latitud': latitud,
    'longitud': longitud,
    'userId': userId,
    'userName': userName,
    'createdAt': createdAt.toIso8601String(),
  };

  factory LocalPhoto.fromJson(Map<String, dynamic> json) => LocalPhoto(
    id: json['id'],
    filePath: json['filePath'],
    fileName: json['fileName'],
    tiendaId: json['tiendaId'],
    tiendaNombre: json['tiendaNombre'],
    latitud: json['latitud']?.toDouble(),
    longitud: json['longitud']?.toDouble(),
    userId: json['userId'],
    userName: json['userName'],
    createdAt: DateTime.parse(json['createdAt']),
  );

  bool get isUnknownStore => tiendaId == 'desconocido';
}

class NearbyStore {
  final String id;
  final String nombre;
  final String determinante;
  final double distanceMeters;

  NearbyStore({
    required this.id,
    required this.nombre,
    required this.determinante,
    required this.distanceMeters,
  });
}
