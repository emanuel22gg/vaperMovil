import 'producto_model.dart';
import 'venta_pedido_model.dart';

/// Modelo de Detalle de Pedido
class DetallePedido {
  final int? id;
  final int? ventaPedidoId;
  final VentaPedido? ventaPedido;
  final int? productoId;
  final Producto? producto;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;

  DetallePedido({
    this.id,
    this.ventaPedidoId,
    this.ventaPedido,
    this.productoId,
    this.producto,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory DetallePedido.fromJson(Map<String, dynamic> json) {
    return DetallePedido(
      id: json['id'] as int?,
      ventaPedidoId: json['ventaPedidoId'] as int?,
      ventaPedido: json['ventaPedido'] != null
          ? VentaPedido.fromJson(json['ventaPedido'] as Map<String, dynamic>)
          : null,
      productoId: json['productoId'] as int?,
      producto: json['producto'] != null
          ? Producto.fromJson(json['producto'] as Map<String, dynamic>)
          : null,
      cantidad: json['cantidad'] as int? ?? 0,
      precioUnitario:
          (json['precioUnitario'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (ventaPedidoId != null) 'ventaPedidoId': ventaPedidoId,
      if (productoId != null) 'productoId': productoId,
      'cantidad': cantidad,
      'precioUnitario': precioUnitario,
      'subtotal': subtotal,
    };
  }

  DetallePedido copyWith({
    int? id,
    int? ventaPedidoId,
    VentaPedido? ventaPedido,
    int? productoId,
    Producto? producto,
    int? cantidad,
    double? precioUnitario,
    double? subtotal,
  }) {
    return DetallePedido(
      id: id ?? this.id,
      ventaPedidoId: ventaPedidoId ?? this.ventaPedidoId,
      ventaPedido: ventaPedido ?? this.ventaPedido,
      productoId: productoId ?? this.productoId,
      producto: producto ?? this.producto,
      cantidad: cantidad ?? this.cantidad,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      subtotal: subtotal ?? this.subtotal,
    );
  }
}

