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
    // Mapear ventaPedidoId desde diferentes posibles campos
    final ventaPedidoId = (json['ventaPedidoId'] as int?) ??
                          (json['VentaPedidoId'] as int?) ??
                          (json['idVentaPedido'] as int?) ??
                          (json['IdVentaPedido'] as int?) ??
                          (json['ventaPedidoID'] as int?) ??
                          (json['VentaPedidoID'] as int?) ??
                          (json['pedidoId'] as int?) ??
                          (json['PedidoId'] as int?) ??
                          (json['idVenta'] as int?) ??
                          (json['IdVenta'] as int?);

    // Mapear productoId desde diferentes posibles campos
    final productoId = (json['productoId'] as int?) ??
                        (json['ProductoId'] as int?) ??
                        (json['idProducto'] as int?) ??
                        (json['IdProducto'] as int?) ??
                        (json['productoID'] as int?) ??
                        (json['ProductoID'] as int?);

    // Mapear cantidad desde diferentes posibles campos
    final cantidad = (json['cantidad'] as int?) ??
                      (json['Cantidad'] as int?) ??
                      (json['cant'] as int?) ??
                      (json['Cant'] as int?) ??
                      0;

    // Mapear precioUnitario desde diferentes posibles campos
    final precioUnitario = (json['precioUnitario'] as num?)?.toDouble() ??
                            (json['PrecioUnitario'] as num?)?.toDouble() ??
                            (json['precio'] as num?)?.toDouble() ??
                            (json['Precio'] as num?)?.toDouble() ??
                            (json['valorUnitario'] as num?)?.toDouble() ??
                            (json['ValorUnitario'] as num?)?.toDouble() ??
                            0.0;

    // Mapear subtotal desde diferentes posibles campos
    final subtotal = (json['subtotal'] as num?)?.toDouble() ??
                      (json['Subtotal'] as num?)?.toDouble() ??
                      (json['total'] as num?)?.toDouble() ??
                      (json['Total'] as num?)?.toDouble() ??
                      0.0;

    return DetallePedido(
      id: json['id'] as int? ?? json['Id'] as int?,
      ventaPedidoId: ventaPedidoId,
      ventaPedido: (json['ventaPedido'] != null)
          ? VentaPedido.fromJson(json['ventaPedido'] as Map<String, dynamic>)
          : (json['VentaPedido'] != null
              ? VentaPedido.fromJson(json['VentaPedido'] as Map<String, dynamic>)
              : null),
      productoId: productoId,
      producto: (json['producto'] != null)
          ? Producto.fromJson(json['producto'] as Map<String, dynamic>)
          : (json['Producto'] != null
              ? Producto.fromJson(json['Producto'] as Map<String, dynamic>)
              : null),
      cantidad: cantidad,
      precioUnitario: precioUnitario,
      subtotal: subtotal,
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

