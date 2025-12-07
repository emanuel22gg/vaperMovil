/// Modelo de Categoría de Producto
class Categoria {
  final int? id;
  final String nombre;
  final String? descripcion;
  final String? imagenUrl;

  Categoria({
    this.id,
    required this.nombre,
    this.descripcion,
    this.imagenUrl,
  });

  factory Categoria.fromJson(Map<String, dynamic> json) {
    return Categoria(
      id: json['id'] as int?,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      imagenUrl: json['imagenUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      if (descripcion != null) 'descripcion': descripcion,
      if (imagenUrl != null) 'imagenUrl': imagenUrl,
    };
  }
}

