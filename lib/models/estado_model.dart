/// Modelo de Estado
class Estado {
  final int? id;
  final String nombre;
  final String? descripcion;

  Estado({
    this.id,
    required this.nombre,
    this.descripcion,
  });

  factory Estado.fromJson(Map<String, dynamic> json) {
    // La API puede devolver 'nombre' o 'nombreEstado'
    final nombre = json['nombre'] as String? ?? 
                   json['nombreEstado'] as String? ?? 
                   '';
    
    return Estado(
      id: json['id'] as int?,
      nombre: nombre,
      descripcion: json['descripcion'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      if (descripcion != null) 'descripcion': descripcion,
    };
  }
}

