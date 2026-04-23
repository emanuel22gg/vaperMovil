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
import 'package:url_launcher/url_launcher.dart';

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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Pedido #${pedido.id}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: _eliminarPedido,
            tooltip: 'Eliminar pedido',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.scaleWidth(context, 16),
                vertical: 16,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: Responsive.maxWidthConstraint(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Header Card
                      _buildStatusCard(pedido, pedidoProvider),
                      
                      const SizedBox(height: 20),
                      
                      // Client & Logistics Info
                      _buildInfoSection(pedido),
                      
                      const SizedBox(height: 24),
                      
                      const Text(
                        ' PRODUCTOS',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Product List
                      ..._detalles.map((detalle) => _buildProductItem(detalle, currencyFormat)),
                      
                      const SizedBox(height: 24),
                      
                      // Order Total Section
                      _buildOrderSummary(pedido, currencyFormat),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStatusCard(VentaPedido pedido, PedidoProvider pedidoProvider) {
    final nombreEstado = _obtenerNombreEstado(pedido, pedidoProvider);
    final colorEstado = _getEstadoColor(nombreEstado);
    final esBloqueado = _esEstadoEntregado(pedido, pedidoProvider) || _esEstadoCancelado(pedido, pedidoProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ESTADO ACTUAL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.black38,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorEstado.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      nombreEstado.toUpperCase(),
                      style: TextStyle(
                        color: colorEstado,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: esBloqueado ? null : _cambiarEstado,
                icon: const Icon(Icons.sync_alt, size: 18),
                label: const Text('ACTUALIZAR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[200],
                  disabledForegroundColor: Colors.grey[400],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          if (esBloqueado) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber[800]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Este pedido está finalizado y no permite más cambios.',
                      style: TextStyle(fontSize: 11, color: Colors.amber[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoSection(VentaPedido pedido) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSectionHeader(Icons.person_outline, 'Detalles del Cliente'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                if (pedido.usuario != null) ...[
                  _buildDetailRow(Icons.account_circle_outlined, 'Nombre', pedido.usuario!.nombre),
                  _buildDetailRow(Icons.email_outlined, 'Email', pedido.usuario!.email),
                  if (pedido.usuario!.telefono != null)
                    _buildDetailRow(Icons.phone_outlined, 'Teléfono', pedido.usuario!.telefono!),
                ],
                const Divider(height: 32),
                _buildDetailRow(Icons.calendar_today_outlined, 'Fecha', 
                  pedido.fechaCreacion != null ? dateFormat.format(pedido.fechaCreacion!) : 'N/A'),
                _buildDetailRow(Icons.payments_outlined, 'Pago', 
                  pedido.metodoPago != null && pedido.metodoPago!.isNotEmpty ? _mapMetodoPago(pedido.metodoPago!) : 'No especificado'),
                _buildDetailRow(Icons.local_shipping_outlined, 'Entrega', 
                  (pedido.tipoEntrega != null && pedido.tipoEntrega!.isNotEmpty)
                      ? _mapTipoEntrega(pedido.tipoEntrega!)
                      : ((pedido.direccionEntrega == null || pedido.direccionEntrega!.isEmpty) ? 'Recoger en tienda' : 'Domicilio')),
                
                if (pedido.direccionEntrega != null && pedido.direccionEntrega!.isNotEmpty)
                  _buildDetailRow(Icons.map_outlined, 'Dirección', pedido.direccionEntrega!),
                
                if (pedido.telefonoContacto != null && pedido.telefonoContacto!.isNotEmpty)
                  _buildDetailRow(Icons.contact_phone_outlined, 'Tel. Contacto', pedido.telefonoContacto!),
                  
                if (pedido.observaciones != null && pedido.observaciones!.isNotEmpty)
                  _buildDetailRow(Icons.notes_outlined, 'Notas', pedido.observaciones!),
                
                if (pedido.comprobanteUrl != null && pedido.comprobanteUrl!.isNotEmpty)
                  _buildComprobanteLink(pedido.comprobanteUrl!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.black87),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[400]),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(DetallePedido detalle, NumberFormat currencyFormat) {
    String? urlImagen;
    if (detalle.producto?.idImagen != null) {
      urlImagen = ProductoService.getUrlImagen(detalle.producto!.idImagen);
    }
    if (urlImagen == null || urlImagen.isEmpty) {
      urlImagen = detalle.producto?.imagenUrl;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 64,
                height: 64,
                color: Colors.grey[50],
                child: urlImagen != null && urlImagen.isNotEmpty
                    ? Image.network(
                        urlImagen,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.image_not_supported, color: Colors.grey),
                      )
                    : const Icon(Icons.image_not_supported, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detalle.producto?.nombre ?? 'Producto',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${detalle.cantidad} unidades x ${currencyFormat.format(detalle.precioUnitario)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              currencyFormat.format(detalle.subtotal),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(VentaPedido pedido, NumberFormat currencyFormat) {
    final totalCalculado = _detalles.fold(0.0, (sum, item) => sum + item.subtotal);
    final totalMostrar = totalCalculado > 0 ? totalCalculado : pedido.total;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.black87, Colors.black],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TOTAL DE VENTA',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'IVA Incluido',
                style: TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ],
          ),
          Text(
            currencyFormat.format(totalMostrar),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComprobanteLink(String url) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: () async {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  InteractiveViewer(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(20),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image, size: 50, color: Colors.grey),
                              SizedBox(height: 10),
                              Text('No se pudo cargar la imagen'),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[100]!),
          ),
          child: Row(
            children: [
              Icon(Icons.receipt_outlined, size: 18, color: Colors.blue[700]),
              const SizedBox(width: 10),
              Text(
                'Ver Comprobante de Pago',
                style: TextStyle(
                  color: Colors.blue[800],
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Icon(Icons.open_in_new, size: 16, color: Colors.blue[700]),
            ],
          ),
        ),
      ),
    );
  }

  // Mapear método de pago técnico a texto legible
  String _mapMetodoPago(String metodo) {
    switch (metodo.toLowerCase()) {
      case 'efectivo':
        return 'Efectivo';
      case 'transferencia':
        return 'Transferencia';
      case 'tarjeta':
      case 'card':
        return 'Tarjeta';
      default:
        return metodo;
    }
  }

  // Mapear tipo de entrega a texto legible
  String _mapTipoEntrega(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'recoger':
      case 'recoger en tienda':
      case 'pickup':
        return 'Recoger en tienda';
      case 'domicilio':
      case 'delivery':
        return 'Domicilio';
      default:
        return tipo;
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
}
