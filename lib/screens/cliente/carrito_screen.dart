import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/carrito_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pedido_provider.dart';
import '../../models/detalle_pedido_model.dart';
import '../../models/venta_pedido_model.dart';
import '../../services/producto_service.dart';
import '../../widgets/custom_button.dart';

/// Pantalla del carrito de compras
class CarritoScreen extends StatefulWidget {
  const CarritoScreen({super.key});

  @override
  State<CarritoScreen> createState() => _CarritoScreenState();
}

class _CarritoScreenState extends State<CarritoScreen> {
  final _direccionController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _observacionesController = TextEditingController();
  bool _isEnviando = false;

  @override
  void dispose() {
    _direccionController.dispose();
    _telefonoController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _enviarPedido() async {
    final carritoProvider = context.read<CarritoProvider>();
    final authProvider = context.read<AuthProvider>();
    final pedidoProvider = context.read<PedidoProvider>();

    if (carritoProvider.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El carrito está vacío'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (authProvider.currentUser?.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuario no autenticado'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Mostrar diálogo para datos adicionales
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Pedido'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _direccionController,
                decoration: const InputDecoration(
                  labelText: 'Dirección de entrega',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _telefonoController,
                decoration: const InputDecoration(
                  labelText: 'Teléfono de contacto',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _observacionesController,
                decoration: const InputDecoration(
                  labelText: 'Observaciones (opcional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isEnviando = true;
    });

    try {
      // Crear pedido
      final pedido = VentaPedido(
        usuarioId: authProvider.currentUser!.id,
        estadoId: 1, // En Revisión
        fechaPedido: DateTime.now(),
        total: carritoProvider.precioTotal,
        direccionEntrega: _direccionController.text.trim().isNotEmpty
            ? _direccionController.text.trim()
            : authProvider.currentUser?.direccion,
        telefonoContacto: _telefonoController.text.trim().isNotEmpty
            ? _telefonoController.text.trim()
            : authProvider.currentUser?.telefono,
        observaciones: _observacionesController.text.trim().isNotEmpty
            ? _observacionesController.text.trim()
            : null,
      );

      // Crear detalles
      final detalles = carritoProvider.items.map((item) {
        return DetallePedido(
          productoId: item.producto.id,
          cantidad: item.cantidad,
          precioUnitario: item.producto.precio,
          subtotal: item.subtotal,
        );
      }).toList();

      final nuevoPedido = await pedidoProvider.crearPedido(pedido, detalles);

      if (nuevoPedido != null && mounted) {
        carritoProvider.limpiarCarrito();
        _direccionController.clear();
        _telefonoController.clear();
        _observacionesController.clear();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido enviado correctamente'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar pedido: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEnviando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final carritoProvider = context.watch<CarritoProvider>();
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrito de Compras'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      body: carritoProvider.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Tu carrito está vacío',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: carritoProvider.items.length,
                    itemBuilder: (context, index) {
                      final item = carritoProvider.items[index];
                      // Obtener URL de imagen usando idImagen o imagenUrl como fallback
                      String? urlImagen;
                      if (item.producto.idImagen != null) {
                        urlImagen = ProductoService.getUrlImagen(item.producto.idImagen);
                      }
                      if (urlImagen == null || urlImagen.isEmpty) {
                        urlImagen = item.producto.imagenUrl;
                      }
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: urlImagen != null && urlImagen.isNotEmpty
                              ? Image.network(
                                  urlImagen,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.image_not_supported),
                                )
                              : const Icon(Icons.image_not_supported),
                          title: Text(item.producto.nombre),
                          subtitle: Text(
                            '${currencyFormat.format(item.producto.precio)} x ${item.cantidad}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () {
                                  if (item.cantidad > 1) {
                                    carritoProvider.actualizarCantidad(
                                      item.producto.id!,
                                      item.cantidad - 1,
                                    );
                                  } else {
                                    carritoProvider.eliminarProducto(
                                      item.producto.id!,
                                    );
                                  }
                                },
                              ),
                              Text('${item.cantidad}'),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  try {
                                    carritoProvider.actualizarCantidad(
                                      item.producto.id!,
                                      item.cantidad + 1,
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(e.toString()),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  carritoProvider.eliminarProducto(
                                    item.producto.id!,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.3),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            currencyFormat.format(carritoProvider.precioTotal),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      CustomButton(
                        text: _isEnviando ? 'Enviando...' : 'Enviar Pedido',
                        onPressed: _isEnviando ? null : _enviarPedido,
                        backgroundColor: const Color(0xFF4CAF50),
                        isLoading: _isEnviando,
                        icon: Icons.send,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

