import 'dart:convert';
import '../config/api_config.dart';
import '../models/venta_pedido_model.dart';
import '../models/detalle_pedido_model.dart';
import '../models/estado_model.dart';
import 'api_service.dart';

/// Servicio de Pedidos
class PedidoService {
  /// Obtener todos los pedidos
  static Future<List<VentaPedido>> getPedidos({int? usuarioId}) async {
    try {
      Map<String, String>? queryParams;
      if (usuarioId != null) {
        queryParams = {'usuarioId': usuarioId.toString()};
      }

      final response = await ApiService.get(
        ApiConfig.pedidosEndpoint,
        queryParams: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> pedidosJson = jsonDecode(response.body);
        return pedidosJson
            .map((json) => VentaPedido.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(ApiService.handleError(response));
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// Obtener pedido por ID
  static Future<VentaPedido> getPedidoById(int id) async {
    try {
      final response = await ApiService.get('${ApiConfig.pedidosEndpoint}/$id');

      if (response.statusCode == 200) {
        final pedidoJson = jsonDecode(response.body);
        return VentaPedido.fromJson(pedidoJson as Map<String, dynamic>);
      } else {
        throw Exception(ApiService.handleError(response));
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// Crear nuevo pedido
  static Future<VentaPedido> crearPedido(VentaPedido pedido) async {
    try {
      final response = await ApiService.post(
        ApiConfig.pedidosEndpoint,
        pedido.toJson(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final pedidoJson = jsonDecode(response.body);
        return VentaPedido.fromJson(pedidoJson as Map<String, dynamic>);
      } else {
        throw Exception(ApiService.handleError(response));
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// Actualizar pedido
  static Future<VentaPedido> actualizarPedido(VentaPedido pedido) async {
    try {
      if (pedido.id == null) {
        throw Exception('El pedido debe tener un ID');
      }

      final response = await ApiService.put(
        '${ApiConfig.pedidosEndpoint}/${pedido.id}',
        pedido.toJson(),
      );

      if (response.statusCode == 200) {
        final pedidoJson = jsonDecode(response.body);
        return VentaPedido.fromJson(pedidoJson as Map<String, dynamic>);
      } else {
        throw Exception(ApiService.handleError(response));
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// Eliminar pedido
  static Future<bool> eliminarPedido(int id) async {
    try {
      final response =
          await ApiService.delete('${ApiConfig.pedidosEndpoint}/$id');

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        throw Exception(ApiService.handleError(response));
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// Obtener detalles de un pedido
  static Future<List<DetallePedido>> getDetallesPedido(int pedidoId) async {
    try {
      final response = await ApiService.get(
        ApiConfig.detallePedidosEndpoint,
        queryParams: {'ventaPedidoId': pedidoId.toString()},
      );

      if (response.statusCode == 200) {
        final List<dynamic> detallesJson = jsonDecode(response.body);
        return detallesJson
            .map((json) =>
                DetallePedido.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(ApiService.handleError(response));
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// Crear detalle de pedido
  static Future<DetallePedido> crearDetallePedido(
      DetallePedido detalle) async {
    try {
      final response = await ApiService.post(
        ApiConfig.detallePedidosEndpoint,
        detalle.toJson(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final detalleJson = jsonDecode(response.body);
        return DetallePedido.fromJson(detalleJson as Map<String, dynamic>);
      } else {
        throw Exception(ApiService.handleError(response));
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// Actualizar detalle de pedido
  static Future<DetallePedido> actualizarDetallePedido(
      DetallePedido detalle) async {
    try {
      if (detalle.id == null) {
        throw Exception('El detalle debe tener un ID');
      }

      final response = await ApiService.put(
        '${ApiConfig.detallePedidosEndpoint}/${detalle.id}',
        detalle.toJson(),
      );

      if (response.statusCode == 200) {
        final detalleJson = jsonDecode(response.body);
        return DetallePedido.fromJson(detalleJson as Map<String, dynamic>);
      } else {
        throw Exception(ApiService.handleError(response));
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// Eliminar detalle de pedido
  static Future<bool> eliminarDetallePedido(int id) async {
    try {
      final response = await ApiService.delete(
        '${ApiConfig.detallePedidosEndpoint}/$id',
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        throw Exception(ApiService.handleError(response));
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// Obtener todos los estados
  static Future<List<Estado>> getEstados() async {
    try {
      final response = await ApiService.get(ApiConfig.estadosEndpoint);

      if (response.statusCode == 200) {
        final List<dynamic> estadosJson = jsonDecode(response.body);
        return estadosJson
            .map((json) => Estado.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(ApiService.handleError(response));
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}

