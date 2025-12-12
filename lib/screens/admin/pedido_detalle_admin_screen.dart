import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/pedido_provider.dart';
import '../../models/detalle_pedido_model.dart';
import '../../services/producto_service.dart';
import '../../widgets/custom_button.dart';

/// Pantalla de detalle de pedido (Administrador)
class PedidoDetalleAdminScreen extends StatefulWidget {
  final int pedidoId;

  const PedidoDetalleAdminScreen({
    super.key,
    required this.pedidoId,
  });

  @override
  State<PedidoDetalleAdminScreen> createState() =>
      _PedidoDetalleAdminScreenState();
}

class _PedidoDetalleAdminScreenState
    extends State<PedidoDetalleAdminScreen> {
  List<DetallePedido> _detalles = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cargarDetalles();
  }

  Future<void> _cargarDetalles() async {
    setState(() {
      _isLoading = true;
    });

    final pedidoProvider = context.read<PedidoProvider>();
    final detalles = await pedidoProvider.getDetallesPedido(widget.pedidoId);

    setState(() {
      _detalles = detalles;
      _isLoading = false;
    });
  }

  Future<void> _cambiarEstado() async {
    final pedidoProvider = context.read<PedidoProvider>();
    final pedido = pedidoProvider.pedidos
        .firstWhere((p) => p.id == widget.pedidoId);

    if (pedidoProvider.estados.isEmpty) {
      await pedidoProvider.cargarEstados();
    }

    if (!mounted) return;

    final nuevoEstado = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar Estado'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: pedidoProvider.estados.length,
            itemBuilder: (context, index) {
              final estado = pedidoProvider.estados[index];
              return ListTile(
                title: Text(estado.nombre),
                selected: estado.id == pedido.estadoId,
                onTap: () {
                  Navigator.of(context).pop(estado.id);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );

    if (nuevoEstado != null && mounted) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar Cambio'),
          content: const Text('¿Estás seguro de cambiar el estado del pedido?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        final success = await pedidoProvider.actualizarEstado(
          widget.pedidoId,
          nuevoEstado,
        );

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Estado actualizado correctamente'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  pedidoProvider.error ?? 'Error al actualizar estado',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _eliminarPedido() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Pedido'),
        content: const Text(
          '¿Estás seguro de eliminar este pedido? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final pedidoProvider = context.read<PedidoProvider>();
      final success = await pedidoProvider.eliminarPedido(widget.pedidoId);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pedido eliminado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                pedidoProvider.error ?? 'Error al eliminar pedido',
              ),
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

    return Scaffold(
      appBar: AppBar(
        title: Text('Pedido #${pedido.id}'),
        backgroundColor: const Color(0xFF9C27B0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _eliminarPedido,
            tooltip: 'Eliminar pedido',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Estado: ${pedido.estado?.nombre ?? "Sin estado"}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Chip(
                                label: Text(
                                  pedido.estado?.nombre ?? 'Sin estado',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                backgroundColor: _getEstadoColor(
                                  pedido.estado?.nombre,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          CustomButton(
                            text: 'Cambiar Estado',
                            onPressed: _cambiarEstado,
                            backgroundColor: const Color(0xFFFF9800),
                            icon: Icons.edit,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Información del Cliente',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (pedido.usuario != null) ...[
                            _buildInfoRow('Nombre', pedido.usuario!.nombre),
                            _buildInfoRow('Email', pedido.usuario!.email),
                            if (pedido.usuario!.telefono != null)
                              _buildInfoRow(
                                'Teléfono',
                                pedido.usuario!.telefono!,
                              ),
                            if (pedido.usuario!.direccion != null)
                              _buildInfoRow(
                                'Dirección',
                                pedido.usuario!.direccion!,
                              ),
                          ],
                          const Divider(),
                          _buildInfoRow(
                            'Fecha del Pedido',
                            pedido.fechaPedido != null
                                ? dateFormat.format(pedido.fechaPedido!)
                                : 'N/A',
                          ),
                          if (pedido.direccionEntrega != null)
                            _buildInfoRow(
                              'Dirección de Entrega',
                              pedido.direccionEntrega!,
                            ),
                          if (pedido.telefonoContacto != null)
                            _buildInfoRow(
                              'Teléfono de Contacto',
                              pedido.telefonoContacto!,
                            ),
                          if (pedido.observaciones != null)
                            _buildInfoRow(
                              'Observaciones',
                              pedido.observaciones!,
                            ),
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
                  ..._detalles.map((detalle) {
                    // Obtener URL de imagen usando idImagen o imagenUrl como fallback
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
                  Card(
                    color: Colors.purple[50],
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
                            currencyFormat.format(pedido.total),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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

  Color _getEstadoColor(String? estadoNombre) {
    switch (estadoNombre?.toLowerCase()) {
      case 'en revisión':
      case 'pendiente':
        return Colors.orange;
      case 'aprobado':
      case 'en proceso':
        return Colors.blue;
      case 'completado':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

