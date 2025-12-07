/// Modelo de Producto
class Producto {
  final int? id;
  final String nombre;
  final String? descripcion;
  final double precio;
  final int stock;
  final String? imagenUrl;
  final int? categoriaId;
  final String? categoriaNombre;

  Producto({
    this.id,
    required this.nombre,
    this.descripcion,
    required this.precio,
    required this.stock,
    this.imagenUrl,
    this.categoriaId,
    this.categoriaNombre,
  });

  factory Producto.fromJson(Map<String, dynamic> json) {
    // Mapear nombre desde nombreProducto (API) o nombre (fallback)
    final nombre = (json['nombreProducto'] as String?) ??
                   (json['NombreProducto'] as String?) ??
                   (json['nombre'] as String?) ??
                   (json['Nombre'] as String?) ??
                   '';
    
    // Mapear precio desde diferentes posibles campos
    final precio = (json['precio'] as num?)?.toDouble() ??
                   (json['Precio'] as num?)?.toDouble() ??
                   0.0;
    
    // Mapear stock desde diferentes posibles campos
    final stock = (json['stock'] as int?) ??
                  (json['Stock'] as int?) ??
                  (json['cantidad'] as int?) ??
                  (json['Cantidad'] as int?) ??
                  0;
    
    // Mapear imagenUrl desde diferentes posibles campos
    final imagenUrl = (json['imagenUrl'] as String?) ??
                      (json['ImagenUrl'] as String?) ??
                      (json['imagen'] as String?) ??
                      (json['Imagen'] as String?) ??
                      (json['urlImagen'] as String?) ??
                      (json['UrlImagen'] as String?);
    
    // Mapear categoriaId desde diferentes posibles campos
    final categoriaId = (json['categoriaId'] as int?) ??
                        (json['CategoriaId'] as int?) ??
                        (json['categoriaProductoId'] as int?) ??
                        (json['CategoriaProductoId'] as int?);
    
    return Producto(
      id: json['id'] as int?,
      nombre: nombre,
      descripcion: (json['descripcion'] as String?) ??
                   (json['Descripcion'] as String?),
      precio: precio,
      stock: stock,
      imagenUrl: imagenUrl,
      categoriaId: categoriaId,
      categoriaNombre: (json['categoriaNombre'] as String?) ??
                        (json['CategoriaNombre'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      if (descripcion != null) 'descripcion': descripcion,
      'precio': precio,
      'stock': stock,
      if (imagenUrl != null) 'imagenUrl': imagenUrl,
      if (categoriaId != null) 'categoriaId': categoriaId,
    };
  }

  bool get disponible => stock > 0;
}

