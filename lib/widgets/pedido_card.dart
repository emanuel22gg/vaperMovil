import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/venta_pedido_model.dart';
import '../models/estado_model.dart';
import '../providers/pedido_provider.dart';
import '../utils/responsive.dart';

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
                        initialValue: estadoSeleccionado,
                        decoration: const InputDecoration(
                          labelText: 'Selecciona un estado',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.flag),
                        ),
                        items: provider.estados.where((estado) {
                          final name = estado.nombre.toLowerCase().trim();
                          return name == 'pendiente' || 
                                 name == 'entregado' || 
                                 name == 'anulada' || 
                                 name == 'anulado' || 
                                 name == 'cancelado';
                        }).map((estado) {
                          String label = estado.nombre;
                          final name = estado.nombre.toLowerCase().trim();
                          if (name == 'anulada' || name == 'anulado') label = 'Cancelado';
                          
                          return DropdownMenuItem<Estado>(
                            value: estado,
                            child: Text(label),
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
        orElse: () => Estado(id: null, nombre: 'Sin estado',
        ),
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
    final pedidoProvider = context.watch<PedidoProvider>();
    final nombreEstado = _obtenerNombreEstado(pedido, pedidoProvider);
    final colorEstado = _getEstadoColor(nombreEstado);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: Responsive.scaleWidth(context, 16),
        vertical: Responsive.scaleHeight(context, 8),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Lateral status bar
              Container(
                width: 6,
                color: colorEstado,
              ),
              Expanded(
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: EdgeInsets.all(Responsive.scaleWidth(context, 16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '#${pedido.id ?? 'N/A'}',
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 14),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: colorEstado.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: colorEstado.withOpacity(0.2)),
                              ),
                              child: Text(
                                nombreEstado.toUpperCase(),
                                style: TextStyle(
                                  color: colorEstado,
                                  fontSize: Responsive.fontSize(context, 10),
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: Responsive.scaleHeight(context, 16)),
                        if (showCliente && pedido.usuario != null) ...[
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.person, size: Responsive.iconSize(context, 14), color: Colors.blue[700]),
                              ),
                              SizedBox(width: Responsive.scaleWidth(context, 10)),
                              Expanded(
                                child: Text(
                                  pedido.usuario!.nombre,
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 16),
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: Responsive.scaleHeight(context, 10)),
                        ],
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded, size: Responsive.iconSize(context, 16), color: Colors.grey[500]),
                            SizedBox(width: Responsive.scaleWidth(context, 6)),
                            Text(
                              pedido.fechaCreacion != null
                                  ? dateFormat.format(pedido.fechaCreacion!)
                                  : 'Fecha no disponible',
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 13),
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: Responsive.scaleHeight(context, 16)),
                        const Divider(height: 1),
                        SizedBox(height: Responsive.scaleHeight(context, 12)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'VENTA TOTAL',
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 10),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[500],
                                    letterSpacing: 1,
                                  ),
                                ),
                                Text(
                                  currencyFormat.format(pedido.total),
                                  style: TextStyle(
                                    fontSize: Responsive.fontSize(context, 20),
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            if (allowEstadoChange)
                              Builder(
                                builder: (context) {
                                  final esEntregado = _esEstadoEntregado(pedido, pedidoProvider);
                                  final esCancelado = _esEstadoCancelado(pedido, pedidoProvider);
                                  final esBloqueado = esEntregado || esCancelado;
                                  return OutlinedButton.icon(
                                    onPressed: esBloqueado ? null : () => _cambiarEstado(context),
                                    icon: Icon(Icons.edit_note, size: Responsive.iconSize(context, 18)),
                                    label: const Text('ESTADO'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.black87,
                                      side: BorderSide(color: Colors.grey[300]!),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

