import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pedido_provider.dart';
import '../../models/venta_pedido_model.dart';
import '../../models/estado_model.dart';
import '../../widgets/pedido_card.dart';
import '../../utils/responsive.dart';
import 'package:intl/intl.dart';
import '../../services/producto_service.dart';

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
        backgroundColor: Colors.black,
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
    // Cargar estados para poder mostrar los nombres correctamente
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pedidoProvider = context.read<PedidoProvider>();
      if (pedidoProvider.estados.isEmpty) {
        pedidoProvider.cargarEstados();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pedidoProvider = context.watch<PedidoProvider>();
    final pedido = pedidoProvider.pedidos
        .firstWhere((p) => p.id == widget.pedidoId, orElse: () => throw Exception('Pedido no encontrado'));
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final width = MediaQuery.of(context).size.width;
    final padding = EdgeInsets.all(Responsive.pagePadding(width));

    return Scaffold(
      appBar: AppBar(
        title: Text('Pedido #${pedido.id}'),
        backgroundColor: Colors.black, // Cambiado a negro para coincidir con estilo admin/premium
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
                    // Tarjeta de Estado
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Builder(
                              builder: (context) {
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
                            Builder(
                              builder: (context) {
                                final nombreEstado = _obtenerNombreEstado(pedido, pedidoProvider);
                                return Chip(
                                  label: Text(
                                    nombreEstado,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  backgroundColor: _getEstadoColor(nombreEstado),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Tarjeta de Información de Envío/Pedido
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Información del Pedido',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            _buildInfoRow(
                              'Fecha',
                              pedido.fechaCreacion != null
                                  ? dateFormat.format(pedido.fechaCreacion!)
                                  : 'N/A',
                            ),
                            if (pedido.direccionEntrega != null)
                              _buildInfoRow(
                                'Dirección de Entrega',
                                pedido.direccionEntrega!,
                              ),
                            if (pedido.ciudadEntrega != null)
                              _buildInfoRow(
                                'Ciudad',
                                pedido.ciudadEntrega!,
                              ),
                            if (pedido.departamentoEntrega != null)
                              _buildInfoRow(
                                'Departamento',
                                pedido.departamentoEntrega!,
                              ),
                            if (pedido.telefonoContacto != null)
                              _buildInfoRow(
                                'Teléfono de Contacto',
                                pedido.telefonoContacto!,
                              ),
                            if (pedido.observaciones != null && pedido.observaciones!.isNotEmpty)
                              _buildInfoRow(
                                'Observaciones',
                                pedido.observaciones!,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Lista de Productos
                    const Text(
                      'Productos:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...detalles.map((detalle) {
                      // Lógica de imagen mejorada (igual que admin)
                      String? urlImagen;
                      if (detalle.producto?.idImagen != null) {
                        urlImagen = ProductoService.getUrlImagen(detalle.producto!.idImagen);
                      }
                      if (urlImagen == null || urlImagen.isEmpty) {
                        urlImagen = detalle.producto?.imagenUrl;
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: urlImagen != null && urlImagen.isNotEmpty
                              ? Image.network(
                                  urlImagen,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.image_not_supported),
                                )
                              : const Icon(Icons.image_not_supported),
                          title: Text(detalle.producto?.nombre ?? 'Producto'),
                          subtitle: Text(
                            'Cantidad: ${detalle.cantidad} x ${currencyFormat.format(detalle.precioUnitario)}',
                          ),
                          trailing: Text(
                            currencyFormat.format(detalle.subtotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    
                    // Total
                    Card(
                      color: Colors.grey[50],
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
                            Builder(
                                builder: (context) {
                                  // Calcular total sumando los subtotales de los detalles si es posible
                                  final totalCalculado = detalles.fold(0.0, (sum, item) => sum + item.subtotal);
                                  
                                  return Text(
                                    currencyFormat.format(totalCalculado > 0 ? totalCalculado : pedido.total),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  );
                                },
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _obtenerNombreEstado(VentaPedido pedido, PedidoProvider provider) {
    if (pedido.estado?.nombre != null && pedido.estado!.nombre.isNotEmpty) {
      return pedido.estado!.nombre;
    }
    
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

  Color _getEstadoColor(String? estadoNombre) {
    switch (estadoNombre?.toLowerCase()) {
      case 'en revisión':
      case 'pendiente':
        return Colors.orange;
      case 'aprobado':
      case 'en proceso':
        return Colors.blue;
      case 'completado':
      case 'entregado':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

