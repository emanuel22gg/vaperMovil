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
  String _filtroEstado = 'TODOS';

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
      await pedidoProvider.cargarPedidos(
        usuarioId: authProvider.currentUser!.id,
        currentUser: authProvider.currentUser,
      );
      await Future.delayed(const Duration(milliseconds: 600));
      await pedidoProvider.cargarEstados();
    }
  }

  List<VentaPedido> _getPedidosFiltrados(List<VentaPedido> pedidos, PedidoProvider pedidoProvider) {
    if (_filtroEstado == 'TODOS') return pedidos;

    return pedidos.where((p) {
      String nombreEstado = '';
      if (p.estado?.nombre != null) {
        nombreEstado = p.estado!.nombre;
      } else if (p.estadoId != null) {
        try {
          final estado = pedidoProvider.estados.firstWhere((e) => e.id == p.estadoId);
          nombreEstado = estado.nombre;
        } catch (_) {}
      }

      final name = nombreEstado.toLowerCase().trim();
      String normalizedState = nombreEstado;
      if (name == 'anulada' || name == 'anulado' || name == 'cancelado') {
        normalizedState = 'Anulada';
      } else if (name == 'pendiente') {
        normalizedState = 'Pendiente';
      } else if (name == 'entregado') {
        normalizedState = 'Entregado';
      }

      return normalizedState.toLowerCase() == _filtroEstado.toLowerCase();
    }).toList();
  }

  void _verDetalle(int pedidoId) {
    if (pedidoId <= 0) return;
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
    final paddingValue = Responsive.pagePadding(width);
    final pedidosFiltrados = _getPedidosFiltrados(pedidoProvider.pedidos.toList(), pedidoProvider);

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
              : Column(
                  children: [
                    // Filtro por estado
                    Container(
                      color: Colors.white,
                      padding: EdgeInsets.fromLTRB(paddingValue, 12, paddingValue, 12),
                      child: DropdownButtonFormField<String>(
                        value: _filtroEstado,
                        decoration: InputDecoration(
                          labelText: 'Filtrar por Estado',
                          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        ),
                        dropdownColor: Colors.white,
                        items: const [
                          DropdownMenuItem(value: 'TODOS', child: Text('Todos los Estados')),
                          DropdownMenuItem(value: 'Pendiente', child: Text('Pendiente')),
                          DropdownMenuItem(value: 'Entregado', child: Text('Entregado')),
                          DropdownMenuItem(value: 'Anulada', child: Text('Anulada')),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _filtroEstado = v);
                        },
                      ),
                    ),
                    // Contador de pedidos
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: paddingValue, vertical: 8),
                      child: Row(
                        children: [
                          Text(
                            '${pedidosFiltrados.length} pedidos encontrados',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Lista de pedidos
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _cargarPedidos,
                        child: pedidosFiltrados.isEmpty
                            ? SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.5,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey[300]),
                                        const SizedBox(height: 16),
                                        Text(
                                          _filtroEstado == 'TODOS'
                                              ? 'No tienes pedidos aún'
                                              : 'No hay pedidos con estado "$_filtroEstado"',
                                          style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: EdgeInsets.symmetric(
                                  horizontal: paddingValue,
                                  vertical: 8,
                                ),
                                itemCount: pedidosFiltrados.length,
                                itemBuilder: (context, index) {
                                  final pedido = pedidosFiltrados[index];
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
                    ),
                  ],
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

  Future<void> _anularPedido(VentaPedido pedido, PedidoProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anular Pedido'),
        content: const Text('¿Estás seguro de que deseas anular este pedido? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Anular Pedido'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // Find the "Anulada" or "Cancelado" state id
      final estadoCancelado = provider.estados.firstWhere(
        (e) {
          final name = e.nombre.toLowerCase().trim();
          return name == 'anulada' || name == 'cancelado' || name == 'anulado';
        },
        orElse: () => Estado(id: null, nombre: ''),
      );

      if (estadoCancelado.id == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: No se encontró el estado de anulación.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final success = await provider.actualizarEstado(pedido.id!, estadoCancelado.id!);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pedido anulado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.error ?? 'Error al anular el pedido'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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
                            const Text(
                              'Estado:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
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
                    const SizedBox(height: 16),
                    Builder(
                      builder: (context) {
                        final nombreEstado = _obtenerNombreEstado(pedido, pedidoProvider);
                        if (nombreEstado.toLowerCase().trim() == 'pendiente') {
                          return SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _anularPedido(pedido, pedidoProvider),
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('ANULAR PEDIDO'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[50],
                                foregroundColor: Colors.red[700],
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.red[200]!),
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(height: 40),
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

