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
    return Categoria(
      id: json['id'] as int? ?? json['Id'] as int?,
      nombre: (json['nombreCategoria'] as String?) ??
              (json['NombreCategoria'] as String?) ??
              (json['nombre'] as String?) ??
              (json['Nombre'] as String?) ??
              'Sin nombre',
      descripcion: json['descripcion'] as String? ?? json['Descripcion'] as String?,
      estado: json['estado'] as bool? ?? json['Estado'] as bool?,
      idImagen: json['idImagen'] as int? ?? json['IdImagen'] as int?,
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

