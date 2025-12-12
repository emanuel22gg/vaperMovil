/// Modelo de Categoría de Producto
class Categoria {
  final int? id;
  final String nombre;
  final String? descripcion;
  final bool? estado;
  final int? idImagen;

  Categoria({
    this.id,
    required this.nombre,
    this.descripcion,
    this.estado,
    this.idImagen,
  });

  factory Categoria.fromJson(Map<String, dynamic> json) {
    print('📦 Categoria parseada: id=${json['id']}, nombreCategoria=${json['nombreCategoria']}');
    
    return Categoria(
      id: json['id'] as int?,
      nombre: json['nombreCategoria'] as String? ?? 'Sin nombre',
      descripcion: json['descripcion'] as String?,
      estado: json['estado'] as bool?,
      idImagen: json['idImagen'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nombreCategoria': nombre,
      if (descripcion != null) 'descripcion': descripcion,
      if (estado != null) 'estado': estado,
      if (idImagen != null) 'idImagen': idImagen,
    };
  }
}

