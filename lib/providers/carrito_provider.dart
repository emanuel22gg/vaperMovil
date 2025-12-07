import 'package:flutter/foundation.dart';
import '../models/carrito_item_model.dart';
import '../models/producto_model.dart';

/// Provider del carrito de compras
class CarritoProvider extends ChangeNotifier {
  final List<CarritoItem> _items = [];

  List<CarritoItem> get items => List.unmodifiable(_items);
  int get cantidadTotal => _items.fold(0, (sum, item) => sum + item.cantidad);
  double get precioTotal =>
      _items.fold(0.0, (sum, item) => sum + item.subtotal);
  bool get isEmpty => _items.isEmpty;

  /// Agregar producto al carrito
  void agregarProducto(Producto producto, {int cantidad = 1}) {
    if (!producto.disponible) {
      throw Exception('El producto no está disponible');
    }

    if (cantidad > producto.stock) {
      throw Exception('No hay suficiente stock disponible');
    }

    final existingIndex = _items.indexWhere(
      (item) => item.producto.id == producto.id,
    );

    if (existingIndex >= 0) {
      final existingItem = _items[existingIndex];
      final newCantidad = existingItem.cantidad + cantidad;

      if (newCantidad > producto.stock) {
        throw Exception('No hay suficiente stock disponible');
      }

      _items[existingIndex] = existingItem.copyWith(cantidad: newCantidad);
    } else {
      _items.add(CarritoItem(producto: producto, cantidad: cantidad));
    }

    notifyListeners();
  }

  /// Eliminar producto del carrito
  void eliminarProducto(int productoId) {
    _items.removeWhere((item) => item.producto.id == productoId);
    notifyListeners();
  }

  /// Actualizar cantidad de un producto
  void actualizarCantidad(int productoId, int nuevaCantidad) {
    if (nuevaCantidad <= 0) {
      eliminarProducto(productoId);
      return;
    }

    final index = _items.indexWhere(
      (item) => item.producto.id == productoId,
    );

    if (index >= 0) {
      final item = _items[index];
      if (nuevaCantidad > item.producto.stock) {
        throw Exception('No hay suficiente stock disponible');
      }
      _items[index] = item.copyWith(cantidad: nuevaCantidad);
      notifyListeners();
    }
  }

  /// Limpiar carrito
  void limpiarCarrito() {
    _items.clear();
    notifyListeners();
  }

  /// Obtener cantidad de un producto específico
  int getCantidadProducto(int productoId) {
    try {
      final item = _items.firstWhere(
        (item) => item.producto.id == productoId,
      );
      return item.cantidad;
    } catch (e) {
      return 0;
    }
  }
}

