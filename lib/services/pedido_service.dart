import 'dart:convert';
import 'package:flutter/foundation.dart';
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
        // Usar UsuarioId (PascalCase) que suele ser el estándar en .NET
        queryParams = {'UsuarioId': usuarioId.toString()};
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
      final pedidoJson = pedido.toJson();
      debugPrint('🔵 PedidoService: Enviando pedido a la API');
      debugPrint('🔵 PedidoService: JSON del pedido: ${jsonEncode(pedidoJson)}');
      
      final response = await ApiService.post(
        ApiConfig.pedidosEndpoint,
        pedidoJson,
      );

      debugPrint('🔵 PedidoService: Respuesta Status: ${response.statusCode}');
      debugPrint('🔵 PedidoService: Respuesta Headers: ${response.headers}');
      debugPrint('🔵 PedidoService: Respuesta Body (completo): ${response.body}');
      debugPrint('🔵 PedidoService: Respuesta Body length: ${response.body.length}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final pedidoJsonResponse = jsonDecode(response.body);
        return VentaPedido.fromJson(pedidoJsonResponse as Map<String, dynamic>);
      } else {
        debugPrint('❌ PedidoService: Error HTTP ${response.statusCode}');
        debugPrint('❌ PedidoService: Response body completo: ${response.body}');
        debugPrint('❌ PedidoService: Response body length: ${response.body.length}');
        debugPrint('❌ PedidoService: Response headers: ${response.headers}');
        
        // Intentar parsear el error si viene en JSON
        String errorMessage = 'Error del servidor (${response.statusCode}). Intenta más tarde.';
        try {
          if (response.body.isNotEmpty) {
            debugPrint('🔍 PedidoService: Intentando parsear error JSON...');
            final errorJson = jsonDecode(response.body);
            debugPrint('🔍 PedidoService: Error JSON parseado: $errorJson');
            
            if (errorJson is Map) {
              if (errorJson.containsKey('message')) {
                errorMessage = errorJson['message'].toString();
              } else if (errorJson.containsKey('error')) {
                errorMessage = errorJson['error'].toString();
              } else if (errorJson.containsKey('title')) {
                errorMessage = errorJson['title'].toString();
              } else if (errorJson.containsKey('errors')) {
                // Manejar errores de validación
                final errors = errorJson['errors'];
                if (errors is Map) {
                  final errorList = <String>[];
                  errors.forEach((key, value) {
                    if (value is List) {
                      errorList.addAll(value.map((e) => '$key: $e'));
                    } else {
                      errorList.add('$key: $value');
                    }
                  });
                  errorMessage = errorList.join(', ');
                } else {
                  errorMessage = errors.toString();
                }
              } else {
                // Si es un Map pero no tiene campos conocidos, mostrar todo
                errorMessage = errorJson.toString();
              }
            } else {
              errorMessage = response.body;
            }
          } else {
            debugPrint('⚠️ PedidoService: Response body está vacío');
            errorMessage = 'Error del servidor (${response.statusCode}). El servidor no devolvió información adicional.';
          }
        } catch (e) {
          debugPrint('⚠️ PedidoService: Error al parsear respuesta: $e');
          if (response.body.isNotEmpty) {
            errorMessage = 'Error del servidor: ${response.body}';
          }
        }
        
        debugPrint('❌ PedidoService: Mensaje de error final: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ PedidoService: Excepción al crear pedido: $e');
      debugPrint('❌ PedidoService: Stack trace: $stackTrace');
      throw Exception(e.toString());
    }
  }

  /// Actualizar pedido
  static Future<VentaPedido> actualizarPedido(VentaPedido pedido) async {
    try {
      if (pedido.id == null) {
        throw Exception('El pedido debe tener un ID');
      }

      final pedidoJson = pedido.toJson();
      debugPrint('🔵 PedidoService: Actualizando pedido ID: ${pedido.id}');
      debugPrint('🔵 PedidoService: JSON a enviar: ${jsonEncode(pedidoJson)}');
      debugPrint('🔵 PedidoService: EstadoId a actualizar: ${pedido.estadoId}');

      final response = await ApiService.put(
        '${ApiConfig.pedidosEndpoint}/${pedido.id}',
        pedidoJson,
      );

      debugPrint('🔵 PedidoService: Respuesta Status: ${response.statusCode}');
      debugPrint('🔵 PedidoService: Respuesta Body: ${response.body}');

      // 200 = OK con contenido, 204 = No Content (éxito sin cuerpo)
      if (response.statusCode == 200 || response.statusCode == 204) {
        if (response.statusCode == 204) {
          // 204 No Content - la actualización fue exitosa pero no hay respuesta
          debugPrint('✅ PedidoService: Pedido actualizado exitosamente (204 No Content)');
          // Retornar el pedido actualizado que enviamos (ya que la API no devuelve nada)
          return pedido;
        } else {
          // 200 OK - la API devolvió el pedido actualizado
          final pedidoJsonResponse = jsonDecode(response.body);
          debugPrint('🔵 PedidoService: Pedido actualizado - EstadoId: ${pedidoJsonResponse['estadoId']}');
          return VentaPedido.fromJson(pedidoJsonResponse as Map<String, dynamic>);
        }
      } else {
        debugPrint('❌ PedidoService: Error al actualizar pedido - Status: ${response.statusCode}');
        debugPrint('❌ PedidoService: Error Body: ${response.body}');
        throw Exception(ApiService.handleError(response));
      }
    } catch (e, stackTrace) {
      debugPrint('❌ PedidoService: Excepción al actualizar pedido: $e');
      debugPrint('❌ PedidoService: Stack trace: $stackTrace');
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
      debugPrint('🔵 PedidoService: Obteniendo estados desde ${ApiConfig.estadosEndpoint}');
      final response = await ApiService.get(ApiConfig.estadosEndpoint);

      debugPrint('🔵 PedidoService: Respuesta de estados - Status: ${response.statusCode}');
      debugPrint('🔵 PedidoService: Respuesta de estados - Body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> estadosJson = jsonDecode(response.body);
        debugPrint('🔵 PedidoService: ${estadosJson.length} estados recibidos');
        
        final estados = estadosJson
            .map((json) {
              debugPrint('🔵 PedidoService: Parseando estado: $json');
              return Estado.fromJson(json as Map<String, dynamic>);
            })
            .toList();
        
        debugPrint('✅ PedidoService: ${estados.length} estados parseados correctamente');
        return estados;
      } else {
        debugPrint('❌ PedidoService: Error al obtener estados - Status: ${response.statusCode}');
        throw Exception(ApiService.handleError(response));
      }
    } catch (e, stackTrace) {
      debugPrint('❌ PedidoService: Excepción al obtener estados: $e');
      debugPrint('❌ PedidoService: Stack trace: $stackTrace');
      throw Exception(e.toString());
    }
  }
}

