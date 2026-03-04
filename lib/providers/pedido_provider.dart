import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../models/venta_pedido_model.dart';
import '../models/detalle_pedido_model.dart';
import '../models/estado_model.dart';
import '../services/pedido_service.dart';
import '../services/auth_service.dart';
import '../services/producto_service.dart';
import '../models/usuario_model.dart';

class PedidoProvider extends ChangeNotifier {
  List<VentaPedido> _pedidos = [];
  List<Estado> _estados = [];
  final Map<int, List<DetallePedido>> _detallesCache = {};
  bool _isLoading = false;
  String? _error;

  List<VentaPedido> get pedidos => List.unmodifiable(_pedidos);
  List<Estado> get estados => List.unmodifiable(_estados);
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ===================== CARGA DE PEDIDOS =====================
  Future<void> cargarPedidos({int? usuarioId, Usuario? currentUser}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      debugPrint('📦 PedidoProvider: Cargando pedidos para usuarioId: $usuarioId');
      var pedidos = await PedidoService.getPedidos(usuarioId: usuarioId);

      // Si el servidor no filtró correctamente (devolvió todos por error)
      // o por seguridad, filtramos localmente si se solicitó un usuario específico.
      if (usuarioId != null) {
        pedidos = pedidos.where((p) => p.usuarioId == usuarioId).toList();
      }

      final Map<int, Usuario> usuariosLocal = {};
      
      // Si tenemos el usuario actual, lo guardamos para no volverlo a pedir
      if (currentUser != null && currentUser.id != null) {
        usuariosLocal[currentUser.id!] = currentUser;
      } else if (_currentUserLocal != null && _currentUserLocal?.id != null) {
        usuariosLocal[_currentUserLocal!.id!] = _currentUserLocal!;
      }

      final idsUsuariosFaltantes = pedidos
          .where((p) => p.usuario == null && p.usuarioId != null && !usuariosLocal.containsKey(p.usuarioId))
          .map((p) => p.usuarioId!)
          .toSet();

      if (idsUsuariosFaltantes.isNotEmpty) {
        debugPrint('📦 PedidoProvider: Cargando info de ${idsUsuariosFaltantes.length} usuarios faltantes');
        for (final id in idsUsuariosFaltantes) {
          try {
            // Carga secuencial para no saturar al servidor (como en el admin)
            final u = await AuthService.getUsuarioById(id);
            usuariosLocal[id] = u;
          } catch (_) {
            debugPrint('⚠️ PedidoProvider: No se pudo cargar info del usuario $id');
          }
        }
      }

      _pedidos = pedidos.map((p) {
        final usuario = p.usuario ?? usuariosLocal[p.usuarioId];
        return usuario != null ? p.copyWith(usuario: usuario) : p;
      }).toList();

      _detallesCache.clear();
      debugPrint('✅ PedidoProvider: ${_pedidos.length} pedidos cargados');
    } catch (e) {
      // Limpiar el mensaje de "Exception: " si existe
      _error = e.toString().replaceAll('Exception: ', '');
      debugPrint('❌ PedidoProvider: Error cargando pedidos: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Helper para mantener referencia al usuario actual
  Usuario? _currentUserLocal;
  void setCurrentUser(Usuario? user) {
    _currentUserLocal = user;
  }

  // ===================== ESTADOS =====================
  Future<void> cargarEstados() async {
    try {
      _estados = await PedidoService.getEstados();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  int? obtenerEstadoPendienteId() {
    if (_estados.isEmpty) return null;
    
    try {
      final estado = _estados.firstWhere(
        (e) => e.nombre.toLowerCase().contains('pendiente'),
        orElse: () => _estados.first,
      );
      return estado.id;
    } catch (_) {
      return null;
    }
  }

  // ===================== CREAR PEDIDO =====================
  Future<VentaPedido?> crearPedido(
      VentaPedido pedido, List<DetallePedido> detalles) async {
    try {
      _isLoading = true;
      notifyListeners();

      final nuevoPedido = await PedidoService.crearPedido(pedido);
      if (nuevoPedido.id == null) throw Exception('Pedido sin ID');

      for (final d in detalles) {
        await PedidoService.crearDetallePedido(
          d.copyWith(ventaPedidoId: nuevoPedido.id),
        );
      }

      await cargarPedidos(usuarioId: pedido.usuarioId);
      return nuevoPedido;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error creando pedido: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===================== ACUALIZAR ESTADO =====================
  Future<bool> actualizarEstado(int pedidoId, int nuevoEstadoId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final pedidoIndex = _pedidos.indexWhere((p) => p.id == pedidoId);
      if (pedidoIndex == -1) {
        // Si no está en la lista local, intentar obtenerlo de la API (aunque es raro en este flujo)
        // Por ahora lanzamos error
        throw Exception('Pedido no encontrado en la lista local');
      }

      final pedido = _pedidos[pedidoIndex];
      // Crear copia del pedido con el nuevo estado
      final pedidoActualizado = pedido.copyWith(estadoId: nuevoEstadoId);
      
      // Llamar al servicio para actualizar
      final resultado = await PedidoService.actualizarPedido(pedidoActualizado);
      
      // Actualizar la lista local con el resultado
      _pedidos[pedidoIndex] = resultado;
      
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===================== ELIMINAR PEDIDO =====================
  Future<bool> eliminarPedido(int pedidoId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await PedidoService.eliminarPedido(pedidoId);
      _pedidos.removeWhere((p) => p.id == pedidoId);

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===================== DETALLES =====================
  Future<List<DetallePedido>> getDetallesPedido(int pedidoId) async {
    if (_detallesCache.containsKey(pedidoId)) {
      return _detallesCache[pedidoId]!;
    }

    try {
      final detallesTodos = await PedidoService.getDetallesPedido(pedidoId);
      
      // Filtrar por ID del pedido. Si d.ventaPedidoId es null, confiamos en que 
      // PedidoService.getDetallesPedido(pedidoId) ya filtró por nosotros en la API.
      final detalles = detallesTodos
          .where((d) => d.ventaPedidoId == null || d.ventaPedidoId == pedidoId)
          .toList();

      if (detalles.isEmpty && detallesTodos.isNotEmpty) {
        // Si el filtrado estricto dejó la lista vacía pero la API devolvió datos,
        // es probable que d.ventaPedidoId sea null por un error de mapeo.
        // En este caso, usamos los datos que devolvió la API (que ya deberían estar filtrados).
        detalles.addAll(detallesTodos);
      }

      final productosIds =
          detalles.map((d) => d.productoId).whereType<int>().toSet();

      final productos = <int, dynamic>{};
      for (final id in productosIds) {
        try {
          productos[id] = await ProductoService.getProductoById(id);
        } catch (_) {}
      }

      final resultado = detalles.map((d) {
        return d.productoId != null && productos.containsKey(d.productoId)
            ? d.copyWith(producto: productos[d.productoId])
            : d;
      }).toList();

      _detallesCache[pedidoId] = resultado;
      return resultado;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  // ===================== WHATSAPP =====================
  Future<void> enviarComprobantePorWhatsApp(
      VentaPedido pedido, List<DetallePedido> detalles) async {
    final numero = '573052359631';
    final format = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    final productos = detalles.map((d) {
      final nombre = d.producto?.nombre ?? 'Producto';
      return '- $nombre x${d.cantidad}: ${format.format(d.precioUnitario * d.cantidad)}';
    }).join('\n');

    final mensaje = '''
*NUEVO PEDIDO*
ID: #${pedido.id}
Cliente: ${pedido.usuario?.nombre ?? 'N/A'}

PRODUCTOS:
$productos

TOTAL: ${format.format(pedido.total)}
''';

    final url =
        'https://wa.me/$numero?text=${Uri.encodeComponent(mensaje)}';

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
