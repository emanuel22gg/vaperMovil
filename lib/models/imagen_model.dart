/// Modelo de Imagen
class Imagen {
  final int? idImagen;
  final String? urlimagen;
  final int? productoId;

  Imagen({
    this.idImagen,
    this.urlimagen,
    this.productoId,
  });

  factory Imagen.fromJson(Map<String, dynamic> json) {
    return Imagen(
      idImagen: (json['idImagen'] as int?) ??
                 (json['IdImagen'] as int?) ??
                 (json['id'] as int?),
      urlimagen: (json['urlimagen'] as String?) ??
                 (json['Urlimagen'] as String?) ??
                 (json['urlImagen'] as String?) ??
                 (json['UrlImagen'] as String?),
      productoId: (json['productoId'] as int?) ??
                  (json['ProductoId'] as int?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (idImagen != null) 'idImagen': idImagen,
      if (urlimagen != null) 'urlimagen': urlimagen,
      if (productoId != null) 'productoId': productoId,
    };
  }
}

