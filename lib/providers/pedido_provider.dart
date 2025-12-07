import 'package:flutter/foundation.dart';
import '../models/venta_pedido_model.dart';
import '../models/detalle_pedido_model.dart';
import '../models/estado_model.dart';
import '../services/pedido_service.dart';

/// Provider de pedidos
class PedidoProvider extends ChangeNotifier {
  List<VentaPedido> _pedidos = [];
  List<Estado> _estados = [];
  bool _isLoading = false;
  String? _error;

  List<VentaPedido> get pedidos => List.unmodifiable(_pedidos);
  List<Estado> get estados => List.unmodifiable(_estados);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Cargar pedidos
  Future<void> cargarPedidos({int? usuarioId}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _pedidos = await PedidoService.getPedidos(usuarioId: usuarioId);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cargar estados
  Future<void> cargarEstados() async {
    try {
      _estados = await PedidoService.getEstados();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  /// Crear pedido
  Future<VentaPedido?> crearPedido(
    VentaPedido pedido,
    List<DetallePedido> detalles,
  ) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Crear pedido
      final nuevoPedido = await PedidoService.crearPedido(pedido);

      // Crear detalles
      for (final detalle in detalles) {
        await PedidoService.crearDetallePedido(
          detalle.copyWith(ventaPedidoId: nuevoPedido.id),
        );
      }

      // Recargar pedidos
      await cargarPedidos(usuarioId: pedido.usuarioId);

      _isLoading = false;
      notifyListeners();
      return nuevoPedido;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Actualizar estado de pedido
  Future<bool> actualizarEstado(int pedidoId, int estadoId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final pedido = _pedidos.firstWhere((p) => p.id == pedidoId);
      final pedidoActualizado = pedido.copyWith(estadoId: estadoId);

      await PedidoService.actualizarPedido(pedidoActualizado);

      // Recargar pedidos
      await cargarPedidos();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Eliminar pedido
  Future<bool> eliminarPedido(int pedidoId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Eliminar detalles primero
      final detalles = await PedidoService.getDetallesPedido(pedidoId);
      for (final detalle in detalles) {
        if (detalle.id != null) {
          await PedidoService.eliminarDetallePedido(detalle.id!);
        }
      }

      // Eliminar pedido
      await PedidoService.eliminarPedido(pedidoId);

      // Recargar pedidos
      await cargarPedidos();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Obtener detalles de un pedido
  Future<List<DetallePedido>> getDetallesPedido(int pedidoId) async {
    try {
      return await PedidoService.getDetallesPedido(pedidoId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  /// Limpiar error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}

