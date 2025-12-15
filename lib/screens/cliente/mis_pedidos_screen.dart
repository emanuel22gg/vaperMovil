import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pedido_provider.dart';
import '../../models/venta_pedido_model.dart';
import '../../models/estado_model.dart';
import '../../widgets/pedido_card.dart';
import '../../utils/responsive.dart';

/// Pantalla de mis pedidos (Cliente)
class MisPedidosScreen extends StatefulWidget {
  const MisPedidosScreen({super.key});

  @override
  State<MisPedidosScreen> createState() => _MisPedidosScreenState();
}

class _MisPedidosScreenState extends State<MisPedidosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarPedidos();
    });
  }

  Future<void> _cargarPedidos() async {
    final authProvider = context.read<AuthProvider>();
    final pedidoProvider = context.read<PedidoProvider>();

    if (authProvider.currentUser?.id != null) {
      await Future.wait([
        pedidoProvider.cargarPedidos(
          usuarioId: authProvider.currentUser!.id,
        ),
        pedidoProvider.cargarEstados(), // Cargar estados para poder mostrar los nombres
      ]);
    }
  }

  void _verDetalle(int pedidoId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PedidoDetalleClienteScreen(pedidoId: pedidoId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pedidoProvider = context.watch<PedidoProvider>();
    final width = MediaQuery.of(context).size.width;
    final padding = EdgeInsets.all(Responsive.pagePadding(width));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Pedidos'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      body: pedidoProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : pedidoProvider.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: ${pedidoProvider.error}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _cargarPedidos,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarPedidos,
                  child: pedidoProvider.pedidos.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_bag_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No tienes pedidos aún',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: padding,
                          itemCount: pedidoProvider.pedidos.length,
                          itemBuilder: (context, index) {
                            final pedido = pedidoProvider.pedidos[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: PedidoCard(
                                pedido: pedido,
                                onTap: () => _verDetalle(pedido.id!),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}

/// Pantalla de detalle de pedido (Cliente)
class PedidoDetalleClienteScreen extends StatefulWidget {
  final int pedidoId;

  const PedidoDetalleClienteScreen({
    super.key,
    required this.pedidoId,
  });

  @override
  State<PedidoDetalleClienteScreen> createState() =>
      _PedidoDetalleClienteScreenState();
}

class _PedidoDetalleClienteScreenState
    extends State<PedidoDetalleClienteScreen> {
  @override
  void initState() {
    super.initState();
    _cargarDetalles();
  }

  Future<void> _cargarDetalles() async {
    final pedidoProvider = context.read<PedidoProvider>();
    await pedidoProvider.getDetallesPedido(widget.pedidoId);
  }

  @override
  Widget build(BuildContext context) {
    final pedidoProvider = context.watch<PedidoProvider>();
    final pedido = pedidoProvider.pedidos
        .firstWhere((p) => p.id == widget.pedidoId, orElse: () => throw Exception('Pedido no encontrado'));
    final width = MediaQuery.of(context).size.width;
    final padding = EdgeInsets.all(Responsive.pagePadding(width));

    return Scaffold(
      appBar: AppBar(
        title: Text('Pedido #${pedido.id}'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder(
        future: pedidoProvider.getDetallesPedido(widget.pedidoId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final detalles = snapshot.data ?? [];

          return SingleChildScrollView(
            padding: padding,
            child: Center(
              child: ConstrainedBox(
                constraints: Responsive.maxWidthConstraint(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final pedidoProvider = context.watch<PedidoProvider>();
                                final nombreEstado = _obtenerNombreEstado(pedido, pedidoProvider);
                                return Text(
                                  'Estado: $nombreEstado',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Fecha: ${pedido.fechaCreacion != null ? pedido.fechaCreacion!.toString().substring(0, 16) : "N/A"}',
                            ),
                            if (pedido.direccionEntrega != null) ...[
                              const SizedBox(height: 8),
                              Text('Dirección: ${pedido.direccionEntrega}'),
                            ],
                            if (pedido.telefonoContacto != null) ...[
                              const SizedBox(height: 8),
                              Text('Teléfono: ${pedido.telefonoContacto}'),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Productos:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...detalles.map((detalle) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: detalle.producto?.imagenUrl != null
                              ? Image.network(
                                  detalle.producto!.imagenUrl!,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                )
                              : const Icon(Icons.image_not_supported),
                          title: Text(detalle.producto?.nombre ?? 'Producto'),
                          subtitle: Text(
                            'Cantidad: ${detalle.cantidad} x \$${detalle.precioUnitario.toStringAsFixed(0)}',
                          ),
                          trailing: Text(
                            '\$${detalle.subtotal.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
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
                              '\$${pedido.total.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _obtenerNombreEstado(VentaPedido pedido, PedidoProvider provider) {
    // Primero intentar obtener desde el objeto estado del pedido
    if (pedido.estado?.nombre != null && pedido.estado!.nombre.isNotEmpty) {
      return pedido.estado!.nombre;
    }
    
    // Si no está disponible, buscar en la lista de estados cargados usando estadoId
    if (pedido.estadoId != null && provider.estados.isNotEmpty) {
      final estado = provider.estados.firstWhere(
        (e) => e.id == pedido.estadoId,
        orElse: () => Estado(id: null, nombre: 'Sin estado'),
      );
      if (estado.nombre.isNotEmpty) {
        return estado.nombre;
      }
    }
    
    return 'Sin estado';
  }
}

