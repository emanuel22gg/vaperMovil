import '../models/producto_model.dart';

/// Modelo de Item del Carrito
class CarritoItem {
  final Producto producto;
  int cantidad;

  CarritoItem({
    required this.producto,
    this.cantidad = 1,
  });

  double get subtotal => producto.precio * cantidad;

  CarritoItem copyWith({
    Producto? producto,
    int? cantidad,
  }) {
    return CarritoItem(
      producto: producto ?? this.producto,
      cantidad: cantidad ?? this.cantidad,
    );
  }
}

