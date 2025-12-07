/// Modelo de Usuario adaptado a la API real del backend.
///
/// La API expone campos como:
/// - nombres, apellidos
/// - correo
/// - contrasena
/// - rolId (1 = Cliente, 2 = Admin, etc.)
class Usuario {
  final int? id;
  final String nombre; // Nombre completo
  final String email; // correo
  final String? password; // contrasena
  final String rol; // 'Admin' | 'Cliente' mapeado desde rolId
  final int? rolId;
  final String? telefono;
  final String? direccion;

  Usuario({
    this.id,
    required this.nombre,
    required this.email,
    this.password,
    required this.rol,
    this.rolId,
    this.telefono,
    this.direccion,
  });

  /// Mapea tanto el esquema genérico (nombre, email, password, rol)
  /// como el esquema real de la API (nombres, apellidos, correo, contrasena, rolId).
  factory Usuario.fromJson(Map<String, dynamic> json) {
    // Construir nombre completo a partir de nombres/apellidos si existen
    final nombres = (json['nombres'] as String?) ?? '';
    final apellidos = (json['apellidos'] as String?) ?? '';
    final nombreCompletoApi = '$nombres $apellidos'.trim();

    // Si la API ya trae un campo "nombre" lo usamos como fallback
    final nombre = (json['nombre'] as String?) ?? nombreCompletoApi;

    // Email puede venir como "email" o "correo"
    final email = (json['email'] as String?) ?? (json['correo'] as String?) ?? '';

    // Password puede venir como "password", "contrasena" o "contraseña"
    final password = (json['password'] as String?) ??
        (json['contrasena'] as String?) ??
        (json['contraseña'] as String?);

    // Rol puede venir como string o como rolId numérico
    final int? rolId = json['rolId'] as int?;
    String rolTexto;
    if (json['rol'] is String) {
      rolTexto = json['rol'] as String;
    } else {
      // Mapear rolId a texto
      if (rolId == 2) {
        rolTexto = 'Admin';
      } else {
        // Por defecto todos los demás son Cliente
        rolTexto = 'Cliente';
      }
    }

    return Usuario(
      id: json['id'] as int?,
      nombre: nombre,
      email: email,
      password: password,
      rol: rolTexto,
      rolId: rolId,
      telefono: json['telefono'] as String?,
      direccion: json['direccion'] as String?,
    );
  }

  /// Al serializar, enviamos tanto los campos genéricos como los de la API
  /// para mayor compatibilidad.
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      // Campos genéricos
      'nombre': nombre,
      'email': email,
      if (password != null) 'password': password,
      'rol': rol,
      if (telefono != null) 'telefono': telefono,
      if (direccion != null) 'direccion': direccion,
      // Campos esperados por la API
      'nombres': nombre, // no separamos nombre/apellido aquí
      'correo': email,
      if (password != null) 'contrasena': password,
      if (rolId != null) 'rolId': rolId,
    };
  }

  Usuario copyWith({
    int? id,
    String? nombre,
    String? email,
    String? password,
    String? rol,
    int? rolId,
    String? telefono,
    String? direccion,
  }) {
    return Usuario(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      password: password ?? this.password,
      rol: rol ?? this.rol,
      rolId: rolId ?? this.rolId,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
    );
  }
}

