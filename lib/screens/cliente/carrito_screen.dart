import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/carrito_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pedido_provider.dart';
import '../../models/detalle_pedido_model.dart';
import '../../models/venta_pedido_model.dart';
import '../../models/departamento_model.dart';
import '../../models/ciudad_model.dart';
import '../../services/producto_service.dart';
import '../../services/ubicacion_service.dart';
import '../../config/api_config.dart';
import '../../widgets/custom_button.dart';
import '../../utils/responsive.dart';

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
  
  // Para los dropdowns de ubicación
  List<Departamento> _departamentos = [];
  List<Ciudad> _ciudades = [];
  Departamento? _departamentoSeleccionado;
  Ciudad? _ciudadSeleccionada;
  bool _isCargandoDepartamentos = false;
  bool _isCargandoCiudades = false;

  @override
  void dispose() {
    _direccionController.dispose();
    _telefonoController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  /// Cargar departamentos
  Future<void> _cargarDepartamentos() async {
    setState(() {
      _isCargandoDepartamentos = true;
    });

    try {
      final departamentos = await UbicacionService.getDepartamentos();
      setState(() {
        _departamentos = departamentos;
        _isCargandoDepartamentos = false;
      });
    } catch (e) {
      debugPrint('❌ Carrito: Error al cargar departamentos: $e');
      setState(() {
        _isCargandoDepartamentos = false;
      });
    }
  }

  /// Cargar ciudades cuando se selecciona un departamento
  Future<void> _cargarCiudades(int departamentoId) async {
    setState(() {
      _isCargandoCiudades = true;
      _ciudadSeleccionada = null; // Limpiar ciudad seleccionada
    });

    try {
      final ciudades = await UbicacionService.getCiudadesPorDepartamento(departamentoId);
      setState(() {
        _ciudades = ciudades;
        _isCargandoCiudades = false;
      });
    } catch (e) {
      debugPrint('❌ Carrito: Error al cargar ciudades: $e');
      setState(() {
        _isCargandoCiudades = false;
      });
    }
  }

  /// Mostrar diálogo para seleccionar tipo de entrega
  Future<String?> _seleccionarTipoEntrega() async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tipo de Entrega'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.store, color: Colors.blue),
              title: const Text('Recoger en Punto Físico'),
              subtitle: const Text('Retira tu pedido en nuestra tienda'),
              onTap: () => Navigator.of(context).pop('recoger'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.local_shipping, color: Colors.green),
              title: const Text('Envío a Domicilio'),
              subtitle: const Text('Recibe tu pedido en tu dirección'),
              onTap: () => Navigator.of(context).pop('domicilio'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  /// Mostrar diálogo para seleccionar método de pago
  Future<String?> _seleccionarMetodoPago() async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Método de Pago'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.money, color: Colors.green),
              title: const Text('Efectivo (Pago Contraentrega)'),
              subtitle: const Text('Paga cuando recibas tu pedido'),
              onTap: () => Navigator.of(context).pop('efectivo'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.account_balance, color: Colors.blue),
              title: const Text('Transferencia'),
              subtitle: const Text('Adjunta el comprobante de pago'),
              onTap: () => Navigator.of(context).pop('transferencia'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  /// Abrir WhatsApp para enviar comprobante
  Future<void> _abrirWhatsApp() async {
    try {
      final numero = ApiConfig.whatsappNumero;
      final mensaje = Uri.encodeComponent(ApiConfig.whatsappMensaje);
      final url = 'https://wa.me/$numero?text=$mensaje';
      
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo abrir WhatsApp'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir WhatsApp: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Mostrar diálogo para datos de envío a domicilio
  Future<Map<String, String>?> _mostrarDialogoDomicilio(String metodoPago) async {
    _direccionController.clear();
    _telefonoController.clear();
    _observacionesController.clear();
    _departamentoSeleccionado = null;
    _ciudadSeleccionada = null;
    _ciudades = [];

    // Cargar departamentos al abrir el diálogo
    await _cargarDepartamentos();

    return await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Datos de Entrega'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _direccionController,
                  decoration: const InputDecoration(
                    labelText: 'Dirección de entrega *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _telefonoController,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono de contacto *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                // Dropdown de Departamento
                _isCargandoDepartamentos
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<Departamento>(
                        value: _departamentoSeleccionado,
                        decoration: const InputDecoration(
                          labelText: 'Departamento *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.map),
                        ),
                        items: _departamentos.map((departamento) {
                          return DropdownMenuItem<Departamento>(
                            value: departamento,
                            child: Text(departamento.nombre),
                          );
                        }).toList(),
                        onChanged: (departamento) async {
                          setState(() {
                            _departamentoSeleccionado = departamento;
                            _ciudadSeleccionada = null; // Limpiar ciudad al cambiar departamento
                          });
                          setDialogState(() {});
                          
                          // Cargar ciudades del departamento seleccionado
                          if (departamento != null && departamento.id != null) {
                            await _cargarCiudades(departamento.id!);
                            setDialogState(() {});
                          }
                        },
                      ),
                const SizedBox(height: 16),
                // Dropdown de Ciudad
                _departamentoSeleccionado == null
                    ? DropdownButtonFormField<Ciudad>(
                        value: null,
                        decoration: const InputDecoration(
                          labelText: 'Ciudad *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_city),
                          hintText: 'Selecciona primero un departamento',
                        ),
                        items: const [],
                        onChanged: null,
                        hint: const Text('Selecciona primero un departamento'),
                      )
                    : _isCargandoCiudades
                        ? const Center(child: CircularProgressIndicator())
                        : DropdownButtonFormField<Ciudad>(
                            value: _ciudadSeleccionada,
                            decoration: const InputDecoration(
                              labelText: 'Ciudad *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.location_city),
                            ),
                            items: _ciudades.isEmpty
                                ? [
                                    const DropdownMenuItem<Ciudad>(
                                      value: null,
                                      enabled: false,
                                      child: Text('No hay ciudades disponibles'),
                                    )
                                  ]
                                : _ciudades.map((ciudad) {
                                    return DropdownMenuItem<Ciudad>(
                                      value: ciudad,
                                      child: Text(ciudad.nombre),
                                    );
                                  }).toList(),
                            onChanged: _ciudades.isEmpty
                                ? null
                                : (ciudad) {
                                    setState(() {
                                      _ciudadSeleccionada = ciudad;
                                    });
                                    setDialogState(() {});
                                  },
                          ),
                const SizedBox(height: 16),
                TextField(
                  controller: _observacionesController,
                  decoration: const InputDecoration(
                    labelText: 'Observaciones (opcional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 3,
                ),
                if (metodoPago == 'transferencia') ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Comprobante de Pago',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Por favor, envía el comprobante de pago a nuestro WhatsApp',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await _abrirWhatsApp();
                          },
                          icon: const Icon(Icons.chat, color: Colors.white),
                          label: const Text('Abrir WhatsApp'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366), // Color verde de WhatsApp
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_direccionController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('La dirección es obligatoria'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                if (_telefonoController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('El teléfono es obligatorio'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                if (_departamentoSeleccionado == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Debes seleccionar un departamento'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                if (_ciudadSeleccionada == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Debes seleccionar una ciudad'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop({
                  'direccion': _direccionController.text.trim(),
                  'telefono': _telefonoController.text.trim(),
                  'ciudad': _ciudadSeleccionada!.nombre,
                  'departamento': _departamentoSeleccionado!.nombre,
                  'observaciones': _observacionesController.text.trim(),
                });
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enviarPedido() async {
    print('🚀🚀🚀 CARrito: MÉTODO _enviarPedido EJECUTADO 🚀🚀🚀');
    debugPrint('🚀 Carrito: Iniciando proceso de envío de pedido...');
    
    final carritoProvider = context.read<CarritoProvider>();
    final authProvider = context.read<AuthProvider>();
    final pedidoProvider = context.read<PedidoProvider>();

    debugPrint('🔵 Carrito: Carrito vacío: ${carritoProvider.isEmpty}');
    debugPrint('🔵 Carrito: Usuario ID: ${authProvider.currentUser?.id}');
    debugPrint('🔵 Carrito: Total: ${carritoProvider.precioTotal}');

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

    // Paso 1: Seleccionar tipo de entrega
    debugPrint('🔵 Carrito: Mostrando diálogo de tipo de entrega...');
    final tipoEntrega = await _seleccionarTipoEntrega();
    debugPrint('🔵 Carrito: Tipo de entrega seleccionado: $tipoEntrega');
    if (tipoEntrega == null) {
      debugPrint('⚠️ Carrito: Usuario canceló selección de tipo de entrega');
      return;
    }

    String? metodoPago;
    Map<String, String>? datosEntrega;

    // Paso 2: Si es envío a domicilio, seleccionar método de pago
    if (tipoEntrega == 'domicilio') {
      debugPrint('🔵 Carrito: Mostrando diálogo de método de pago...');
      metodoPago = await _seleccionarMetodoPago();
      debugPrint('🔵 Carrito: Método de pago seleccionado: $metodoPago');
      if (metodoPago == null) {
        debugPrint('⚠️ Carrito: Usuario canceló selección de método de pago');
        return;
      }

      // Paso 3: Mostrar diálogo para datos de entrega
      debugPrint('🔵 Carrito: Mostrando diálogo de datos de entrega...');
      datosEntrega = await _mostrarDialogoDomicilio(metodoPago);
      debugPrint('🔵 Carrito: Datos de entrega: $datosEntrega');
      if (datosEntrega == null) {
        debugPrint('⚠️ Carrito: Usuario canceló diálogo de datos de entrega');
        return;
      }

      // Para transferencia, el comprobante se envía por WhatsApp
      // No necesitamos subir nada, solo indicar que el método de pago es transferencia
    } else if (tipoEntrega == 'recoger') {
      // Para recoger en punto físico, no necesitamos método de pago ni datos de entrega
      debugPrint('🔵 Carrito: Tipo de entrega: Recoger en punto físico');
      metodoPago = null;
      datosEntrega = null;
    }

    setState(() {
      _isEnviando = true;
    });

    try {
      // Validar que el usuario esté autenticado
      if (authProvider.currentUser == null || authProvider.currentUser!.id == null) {
        throw Exception('Usuario no autenticado. Por favor, inicia sesión nuevamente.');
      }

      // Crear pedido según el formato que espera la API
      final ahora = DateTime.now();
      final subtotal = carritoProvider.precioTotal;
      final envio = tipoEntrega == 'domicilio' ? 5000.0 : 0.0; // Costo de envío si aplica
      final total = subtotal + envio;
      
      // Asegurar que fechaEntrega siempre tenga un valor (usar fechaCreacion si no hay)
      final fechaEntregaFinal = tipoEntrega == 'domicilio' 
          ? ahora.add(const Duration(days: 3)) 
          : ahora; // Si es recoger, usar la misma fecha
      
      // Obtener el ID del estado "Pendiente"
      final estadoPendienteId = await pedidoProvider.obtenerEstadoPendienteId();
      if (estadoPendienteId == null) {
        throw Exception('No se pudo obtener el estado "Pendiente". Por favor, intenta nuevamente.');
      }

      debugPrint('🔵 Carrito: Validaciones previas:');
      debugPrint('  - UsuarioId: ${authProvider.currentUser!.id}');
      debugPrint('  - EstadoId: $estadoPendienteId (Pendiente)');
      debugPrint('  - Subtotal: $subtotal');
      debugPrint('  - Envío: $envio');
      debugPrint('  - Total: $total');
      debugPrint('  - Tipo entrega: $tipoEntrega');
      debugPrint('  - Método pago: $metodoPago');
      
      final pedido = VentaPedido(
        usuarioId: authProvider.currentUser!.id,
        estadoId: estadoPendienteId, // Pendiente
        fechaCreacion: ahora,
        fechaEntrega: fechaEntregaFinal,
        subtotal: subtotal,
        envio: envio,
        total: total,
        direccionEntrega: tipoEntrega == 'domicilio' && datosEntrega != null
            ? datosEntrega['direccion']
            : null,
        ciudadEntrega: tipoEntrega == 'domicilio' && datosEntrega != null
            ? datosEntrega['ciudad']
            : null,
        departamentoEntrega: tipoEntrega == 'domicilio' && datosEntrega != null
            ? datosEntrega['departamento']
            : null,
        metodoPago: metodoPago, // Puede ser null si es "recoger"
        // Campos adicionales para uso interno (no se envían a la API)
        tipoEntrega: tipoEntrega,
        telefonoContacto: tipoEntrega == 'domicilio' && datosEntrega != null
            ? datosEntrega['telefono']
            : authProvider.currentUser?.telefono,
        observaciones: tipoEntrega == 'domicilio' && datosEntrega != null && datosEntrega['observaciones']!.isNotEmpty
            ? datosEntrega['observaciones']
            : null,
        comprobanteUrl: null, // Ya no se sube, se envía por WhatsApp
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

      debugPrint('🔵 Carrito: Creando pedido...');
      debugPrint('🔵 Carrito: Pedido JSON: ${pedido.toJson()}');
      debugPrint('🔵 Carrito: Detalles: ${detalles.length} items');
      
      final nuevoPedido = await pedidoProvider.crearPedido(pedido, detalles);

      debugPrint('🔵 Carrito: Pedido creado: ${nuevoPedido?.id}');
      debugPrint('🔵 Carrito: Error del provider: ${pedidoProvider.error}');
      debugPrint('🔵 Carrito: IsLoading: ${pedidoProvider.isLoading}');

      // Verificar si hay error
      if (pedidoProvider.error != null) {
        debugPrint('❌ Carrito: Error del provider: ${pedidoProvider.error}');
        if (mounted) {
          throw Exception(pedidoProvider.error);
        }
        return;
      }

      // Verificar si el pedido se creó
      if (nuevoPedido == null) {
        debugPrint('❌ Carrito: nuevoPedido es null');
        if (mounted) {
          throw Exception('No se pudo crear el pedido. ${pedidoProvider.error ?? "Error desconocido"}');
        }
        return;
      }

      // Si llegamos aquí, el pedido se creó exitosamente
      debugPrint('✅ Carrito: Pedido creado exitosamente con ID: ${nuevoPedido.id}');
      
      if (mounted) {
        carritoProvider.limpiarCarrito();
        _direccionController.clear();
        _telefonoController.clear();
        _observacionesController.clear();
        _departamentoSeleccionado = null;
        _ciudadSeleccionada = null;
        _ciudades = [];

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido enviado correctamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Esperar un poco antes de cerrar para que el usuario vea el mensaje
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Carrito: Error al enviar pedido: $e');
      debugPrint('❌ Carrito: Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar pedido: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
    final width = MediaQuery.of(context).size.width;
    final paddingValue = Responsive.pagePadding(width);
    final horizontalPadding = EdgeInsets.symmetric(horizontal: paddingValue);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrito de Compras'),
        backgroundColor: Colors.black,
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
                  child: Center(
                    child: ConstrainedBox(
                      constraints: Responsive.maxWidthConstraint(),
                      child: ListView.builder(
                        padding: horizontalPadding.add(const EdgeInsets.only(top: 16, bottom: 16)),
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
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(paddingValue),
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
                        onPressed: _isEnviando ? null : () {
                          print('🔴🔴🔴 BOTÓN PRESIONADO 🔴🔴🔴');
                          _enviarPedido();
                        },
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

