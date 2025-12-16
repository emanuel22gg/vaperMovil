import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/pedido_provider.dart';
import '../../models/venta_pedido_model.dart';
import '../../models/detalle_pedido_model.dart';
import '../../models/estado_model.dart';
import '../../services/producto_service.dart';
import '../../widgets/custom_button.dart';
import '../../utils/responsive.dart';

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
    // Cargar estados para poder mostrar los nombres
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pedidoProvider = context.read<PedidoProvider>();
      if (pedidoProvider.estados.isEmpty) {
        pedidoProvider.cargarEstados();
      }
    });
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

  bool _esEstadoEntregado(VentaPedido pedido, PedidoProvider provider) {
    // Verificar si el pedido está en estado "entregado"
    final nombreEstado = _obtenerNombreEstado(pedido, provider);
    return nombreEstado.toLowerCase().trim() == 'entregado';
  }

  bool _esEstadoCancelado(VentaPedido pedido, PedidoProvider provider) {
    // Verificar si el pedido está en estado "cancelado"
    final nombreEstado = _obtenerNombreEstado(pedido, provider);
    return nombreEstado.toLowerCase().trim() == 'cancelado';
  }

  Future<void> _cambiarEstado() async {
    final pedidoProvider = context.read<PedidoProvider>();
    final pedido = pedidoProvider.pedidos
        .firstWhere((p) => p.id == widget.pedidoId);

    // Verificar si el pedido está entregado o cancelado
    if (_esEstadoEntregado(pedido, pedidoProvider)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se puede cambiar el estado de un pedido entregado.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (_esEstadoCancelado(pedido, pedidoProvider)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se puede cambiar el estado de un pedido cancelado.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    debugPrint('🔵 PedidoDetalleAdmin: Iniciando cambio de estado');
    debugPrint('🔵 PedidoDetalleAdmin: Estados actuales: ${pedidoProvider.estados.length}');
    
    // Siempre recargar estados para asegurar que estén actualizados
    await pedidoProvider.cargarEstados();
    
    debugPrint('🔵 PedidoDetalleAdmin: Estados después de cargar: ${pedidoProvider.estados.length}');

    if (!mounted) return;
    
    if (pedidoProvider.estados.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudieron cargar los estados. Por favor, intenta nuevamente.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    Estado? estadoSeleccionado = pedidoProvider.estados
        .firstWhere((e) => e.id == pedido.estadoId, orElse: () => pedidoProvider.estados.first);

    final nuevoEstado = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        // Usar watch dentro del diálogo para obtener estados actualizados
        final provider = dialogContext.watch<PedidoProvider>();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Actualizar estado seleccionado si los estados cambiaron
            if (provider.estados.isNotEmpty && estadoSeleccionado == null) {
              estadoSeleccionado = provider.estados.firstWhere(
                (e) => e.id == pedido.estadoId,
                orElse: () => provider.estados.first,
              );
            }
            
            return AlertDialog(
              title: const Text('Cambiar Estado del Pedido'),
              content: SizedBox(
                width: double.maxFinite,
                child: provider.estados.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : DropdownButtonFormField<Estado>(
                        value: estadoSeleccionado,
                        decoration: const InputDecoration(
                          labelText: 'Selecciona un estado',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.flag),
                        ),
                        items: provider.estados.where((estado) {
                          // Si el pedido está entregado, no permitir cambiar a pendiente
                          final nombreEstadoActual = _obtenerNombreEstado(pedido, provider);
                          final esEntregado = nombreEstadoActual.toLowerCase().trim() == 'entregado';
                          if (esEntregado) {
                            // Si está entregado, no permitir cambiar a pendiente
                            return estado.nombre.toLowerCase().trim() != 'pendiente';
                          }
                          return true; // Permitir todos los estados si no está entregado
                        }).map((estado) {
                          return DropdownMenuItem<Estado>(
                            value: estado,
                            child: Text(estado.nombre),
                          );
                        }).toList(),
                        onChanged: (estado) {
                          setDialogState(() {
                            estadoSeleccionado = estado;
                          });
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: estadoSeleccionado != null && provider.estados.isNotEmpty
                      ? () => Navigator.of(context).pop(estadoSeleccionado!.id)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (nuevoEstado != null && nuevoEstado != pedido.estadoId && mounted) {
      // Validar que no se intente cambiar a pendiente si el pedido está entregado
      final estadoSeleccionado = pedidoProvider.estados.firstWhere(
        (e) => e.id == nuevoEstado,
        orElse: () => Estado(id: null, nombre: ''),
      );
      
      if (_esEstadoEntregado(pedido, pedidoProvider) && 
          estadoSeleccionado.nombre.toLowerCase().trim() == 'pendiente') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se puede cambiar un pedido entregado a pendiente.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

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
          // Recargar los detalles para actualizar la UI
          _cargarDetalles();
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
    final width = MediaQuery.of(context).size.width;
    final padding = EdgeInsets.all(Responsive.pagePadding(width));

    return Scaffold(
      appBar: AppBar(
        title: Text('Pedido #${pedido.id}'),
        backgroundColor: Colors.black,
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
                              Row(
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
                              const SizedBox(height: 16),
                              Builder(
                                builder: (context) {
                                  final pedidoProvider = context.watch<PedidoProvider>();
                                  final esEntregado = _esEstadoEntregado(pedido, pedidoProvider);
                                  final esCancelado = _esEstadoCancelado(pedido, pedidoProvider);
                                  final esBloqueado = esEntregado || esCancelado;
                                  
                                  return CustomButton(
                                    text: 'Cambiar Estado',
                                    onPressed: esBloqueado ? null : _cambiarEstado,
                                    backgroundColor: esBloqueado ? Colors.grey : const Color(0xFFFF9800),
                                    icon: Icons.edit,
                                  );
                                },
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
                                pedido.fechaCreacion != null
                                    ? dateFormat.format(pedido.fechaCreacion!)
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
                                  // Calcular total sumando los subtotales de los detalles
                                  final totalCalculado = _detalles.fold(0.0, (sum, item) => sum + item.subtotal);
                                  
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

