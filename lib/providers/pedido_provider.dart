import 'package:flutter/foundation.dart';
import '../models/venta_pedido_model.dart';
import '../models/detalle_pedido_model.dart';
import '../models/estado_model.dart';
import '../services/pedido_service.dart';
import '../services/auth_service.dart';
import '../services/producto_service.dart';
import '../models/usuario_model.dart';

/// Provider de pedidos
class PedidoProvider extends ChangeNotifier {
  List<VentaPedido> _pedidos = [];
  List<Estado> _estados = [];
  final Map<int, List<DetallePedido>> _detallesCache = {};
  bool _isLoading = false;
  String? _error;

  List<VentaPedido> get pedidos => List.unmodifiable(_pedidos);
  List<Estado> get estados => List.unmodifiable(_estados);
  Map<int, List<DetallePedido>> get detallesCache =>
      Map.unmodifiable(_detallesCache);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Cargar pedidos
  Future<void> cargarPedidos({int? usuarioId}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      var pedidos = await PedidoService.getPedidos(usuarioId: usuarioId);

      // Si el backend no devuelve el objeto usuario, lo resolvemos manualmente
      final idsFaltantes = pedidos
          .where((p) => p.usuario == null && p.usuarioId != null)
          .map((p) => p.usuarioId!)
          .toSet();

      final Map<int, Usuario> usuariosCargados = {};
      if (idsFaltantes.isNotEmpty) {
        await Future.wait(idsFaltantes.map((id) async {
          try {
            usuariosCargados[id] = await AuthService.getUsuarioById(id);
          } catch (e) {
            debugPrint(
              '❌ PedidoProvider: No se pudo obtener el usuario $id: $e',
            );
          }
        }));
      }

      // Filtrar localmente por usuarioId si se especificó
      // Esto es necesario si el backend ignora el parámetro de consulta
      if (usuarioId != null) {
        pedidos = pedidos.where((p) => p.usuarioId == usuarioId).toList();
      }

      _pedidos = pedidos.map((pedido) {
        final usuario = pedido.usuario ??
            (pedido.usuarioId != null
                ? usuariosCargados[pedido.usuarioId!]
                : null);
        return usuario != null ? pedido.copyWith(usuario: usuario) : pedido;
      }).toList();

      // Limpiar caché de detalles para evitar inconsistencias
      _detallesCache.clear();

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
      debugPrint('🔵 PedidoProvider: Cargando estados...');
      _estados = await PedidoService.getEstados();
      debugPrint('✅ PedidoProvider: ${_estados.length} estados cargados');
      for (var estado in _estados) {
        debugPrint('  - Estado: ${estado.nombre} (ID: ${estado.id})');
      }
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('❌ PedidoProvider: Error al cargar estados: $e');
      debugPrint('❌ PedidoProvider: Stack trace: $stackTrace');
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
      debugPrint('🔵 PedidoProvider: Iniciando creación de pedido...');
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Crear pedido
      debugPrint('🔵 PedidoProvider: Creando pedido principal...');
      final nuevoPedido = await PedidoService.crearPedido(pedido);
      debugPrint('🔵 PedidoProvider: Pedido creado con ID: ${nuevoPedido.id}');

      if (nuevoPedido.id == null) {
        throw Exception('El pedido se creó pero no tiene ID');
      }

      // Crear detalles
      debugPrint('🔵 PedidoProvider: Creando ${detalles.length} detalles...');
      for (int i = 0; i < detalles.length; i++) {
        final detalle = detalles[i];
        debugPrint('🔵 PedidoProvider: Creando detalle ${i + 1}/${detalles.length}...');
        await PedidoService.crearDetallePedido(
          detalle.copyWith(ventaPedidoId: nuevoPedido.id),
        );
      }
      debugPrint('✅ PedidoProvider: Todos los detalles creados');

      // Recargar pedidos
      debugPrint('🔵 PedidoProvider: Recargando lista de pedidos...');
      await cargarPedidos(usuarioId: pedido.usuarioId);

      _isLoading = false;
      notifyListeners();
      debugPrint('✅ PedidoProvider: Pedido creado exitosamente');
      return nuevoPedido;
    } catch (e, stackTrace) {
      debugPrint('❌ PedidoProvider: Error al crear pedido: $e');
      debugPrint('❌ PedidoProvider: Stack trace: $stackTrace');
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Actualizar estado de pedido
  Future<bool> actualizarEstado(int pedidoId, int estadoId) async {
    try {
      debugPrint('🔵 PedidoProvider: Iniciando actualización de estado');
      debugPrint('🔵 PedidoProvider: PedidoId: $pedidoId, Nuevo EstadoId: $estadoId');
      
      _isLoading = true;
      _error = null;
      notifyListeners();

      final pedido = _pedidos.firstWhere((p) => p.id == pedidoId);
      debugPrint('🔵 PedidoProvider: Pedido encontrado - EstadoId actual: ${pedido.estadoId}');
      
      final pedidoActualizado = pedido.copyWith(estadoId: estadoId);
      debugPrint('🔵 PedidoProvider: Pedido actualizado - EstadoId nuevo: ${pedidoActualizado.estadoId}');

      final pedidoRespuesta = await PedidoService.actualizarPedido(pedidoActualizado);
      debugPrint('🔵 PedidoProvider: Pedido actualizado en API - EstadoId respuesta: ${pedidoRespuesta.estadoId}');

      // Recargar pedidos
      debugPrint('🔵 PedidoProvider: Recargando lista de pedidos...');
      await cargarPedidos();

      _isLoading = false;
      notifyListeners();
      debugPrint('✅ PedidoProvider: Estado actualizado exitosamente');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ PedidoProvider: Error al actualizar estado: $e');
      debugPrint('❌ PedidoProvider: Stack trace: $stackTrace');
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
      // Retornar desde caché si ya existe
      if (_detallesCache.containsKey(pedidoId)) {
        return _detallesCache[pedidoId]!;
      }

      final detalles = await PedidoService.getDetallesPedido(pedidoId);
      
      // FILTRADO DE SEGURIDAD:
      // Filtrar solo los detalles que corresponden a este pedidoId.
      // Esto es necesario porque a veces la API devuelve detalles de otros pedidos
      // si el filtrado en backend no funciona correctamente.
      final detallesFiltrados = detalles.where((d) => d.ventaPedidoId == pedidoId).toList();
      
      // Enriquecer detalles con información del producto
      final List<DetallePedido> detallesEnriquecidos = [];
      
      // Obtener IDs únicos de productos
      final productoIds = detallesFiltrados
          .map((d) => d.productoId)
          .where((id) => id != null)
          .toSet()
          .cast<int>();
          
      final Map<int, dynamic> productosMap = {};
      
      if (productoIds.isNotEmpty) {
        debugPrint('🔵 PedidoProvider: Cargando información para ${productoIds.length} productos...');
        await Future.wait(productoIds.map((id) async {
           try {
            // Importar ProductoService si no está (asumimos que está importado o lo añadiremos)
             final producto = await ProductoService.getProductoById(id);
             productosMap[id] = producto;
           } catch (e) {
             debugPrint('⚠️ PedidoProvider: Error cargando producto $id: $e');
           }
        }));
      }

      // Asignar productos a detalles
      for (var detalle in detallesFiltrados) {
        if (detalle.productoId != null && productosMap.containsKey(detalle.productoId)) {
           detallesEnriquecidos.add(detalle.copyWith(
             producto: productosMap[detalle.productoId]
           ));
        } else {
           detallesEnriquecidos.add(detalle);
        }
      }

      _detallesCache[pedidoId] = detallesEnriquecidos;
      return detallesEnriquecidos;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  /// Obtener ID del estado "Pendiente"
  /// Si no está cargado, lo carga primero
  Future<int?> obtenerEstadoPendienteId() async {
    try {
      // Si los estados no están cargados, cargarlos
      if (_estados.isEmpty) {
        await cargarEstados();
      }

      // Buscar el estado "Pendiente" (case-insensitive)
      final estadoPendiente = _estados.firstWhere(
        (estado) => estado.nombre.toLowerCase().trim() == 'pendiente',
        orElse: () => _estados.firstWhere(
          (estado) => estado.nombre.toLowerCase().contains('pendiente'),
          orElse: () => throw Exception('No se encontró el estado "Pendiente"'),
        ),
      );

      return estadoPendiente.id;
    } catch (e) {
      debugPrint('❌ PedidoProvider: Error al obtener estado Pendiente: $e');
      // Si no se encuentra, retornar null para que el código que lo use pueda manejar el error
      return null;
    }
  }

  /// Limpiar error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}

