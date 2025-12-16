import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/venta_pedido_model.dart';
import '../models/estado_model.dart';
import '../providers/pedido_provider.dart';

/// Card de pedido
class PedidoCard extends StatelessWidget {
  final VentaPedido pedido;
  final VoidCallback? onTap;
  final bool showCliente;
  final bool allowEstadoChange;

  const PedidoCard({
    super.key,
    required this.pedido,
    this.onTap,
    this.showCliente = false,
    this.allowEstadoChange = false,
  });

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

  void _cambiarEstado(BuildContext context) async {
    final pedidoProvider = context.read<PedidoProvider>();
    
    // Verificar si el pedido está entregado o cancelado
    if (_esEstadoEntregado(pedido, pedidoProvider)) {
      if (context.mounted) {
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
      if (context.mounted) {
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
    
    debugPrint('🔵 PedidoCard: Iniciando cambio de estado');
    debugPrint('🔵 PedidoCard: Estados actuales: ${pedidoProvider.estados.length}');
    
    // Siempre recargar estados para asegurar que estén actualizados
    await pedidoProvider.cargarEstados();
    
    debugPrint('🔵 PedidoCard: Estados después de cargar: ${pedidoProvider.estados.length}');

    if (!context.mounted) return;
    
    if (pedidoProvider.estados.isEmpty) {
      if (context.mounted) {
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
        .firstWhere(
          (e) => e.id == pedido.estadoId,
          orElse: () => pedidoProvider.estados.first,
        );

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
              title: Text('Cambiar Estado - Pedido #${pedido.id}'),
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

    if (nuevoEstado != null && nuevoEstado != pedido.estadoId && context.mounted) {
      // Validar que no se intente cambiar a pendiente si el pedido está entregado
      final estadoSeleccionado = pedidoProvider.estados.firstWhere(
        (e) => e.id == nuevoEstado,
        orElse: () => Estado(id: null, nombre: ''),
      );
      
      if (_esEstadoEntregado(pedido, pedidoProvider) && 
          estadoSeleccionado.nombre.toLowerCase().trim() == 'pendiente') {
        if (context.mounted) {
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
        pedido.id!,
        nuevoEstado,
      );

      if (context.mounted) {
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

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pedido #${pedido.id ?? 'N/A'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      if (allowEstadoChange)
                        Builder(
                          builder: (context) {
                            final pedidoProvider = context.watch<PedidoProvider>();
                            final esEntregado = _esEstadoEntregado(pedido, pedidoProvider);
                            final esCancelado = _esEstadoCancelado(pedido, pedidoProvider);
                            final esBloqueado = esEntregado || esCancelado;
                            return IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              color: esBloqueado ? Colors.grey[400] : Colors.grey[600],
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: esBloqueado ? null : () => _cambiarEstado(context),
                              tooltip: esBloqueado ? 'No se puede cambiar el estado de un pedido finalizado o cancelado' : 'Cambiar estado',
                            );
                          },
                        ),
                      if (allowEstadoChange) const SizedBox(width: 8),
                  Builder(
                    builder: (context) {
                      final pedidoProvider = context.watch<PedidoProvider>();
                      final nombreEstado = _obtenerNombreEstado(pedido, pedidoProvider);
                      return Chip(
                        label: Text(
                          nombreEstado,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: _getEstadoColor(nombreEstado),
                      );
                    },
                  ),
                    ],
                  ),
                ],
              ),
              if (showCliente && pedido.usuario != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      pedido.usuario!.nombre,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    pedido.fechaCreacion != null
                        ? dateFormat.format(pedido.fechaCreacion!)
                        : 'Fecha no disponible',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    currencyFormat.format(pedido.total),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

