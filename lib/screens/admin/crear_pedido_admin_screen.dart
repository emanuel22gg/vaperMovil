import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/usuario_model.dart';
import '../../models/producto_model.dart';
import '../../models/venta_pedido_model.dart';
import '../../models/detalle_pedido_model.dart';
import '../../models/departamento_model.dart';
import '../../models/ciudad_model.dart';
import '../../services/auth_service.dart';
import '../../services/ubicacion_service.dart';
import '../../services/imagen_service.dart';
import '../../services/producto_service.dart';
import '../../providers/pedido_provider.dart';
import '../../widgets/producto_card.dart';
import '../../utils/responsive.dart';

/// Pantalla para crear pedido manualmente (Admin)
class CrearPedidoAdminScreen extends StatefulWidget {
  const CrearPedidoAdminScreen({super.key});

  @override
  State<CrearPedidoAdminScreen> createState() => _CrearPedidoAdminScreenState();
}

class _CrearPedidoAdminScreenState extends State<CrearPedidoAdminScreen> {
  Usuario? _clienteSeleccionado;
  List<Usuario> _clientes = [];
  List<Producto> _productos = [];
  List<Producto> _productosFiltrados = [];
  final Map<int, int> _productosAgregados = {}; // productoId -> cantidad
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _clientSearchController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _observacionesController = TextEditingController();
  bool _isLoadingClientes = true;
  bool _isLoadingProductos = true;
  bool _isCreando = false;
  List<Departamento> _departamentos = [];
  List<Ciudad> _ciudades = [];
  Departamento? _departamentoSeleccionado;
  Ciudad? _ciudadSeleccionada;
  bool _isCargandoDepartamentos = false;
  bool _isCargandoCiudades = false;
  XFile? _comprobanteSeleccionado;


  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _searchController.addListener(_filtrarProductos);
    _clientSearchController.addListener(_filtrarClientes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _clientSearchController.dispose();
    _direccionController.dispose();
    _telefonoController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    // Cargamos secuencialmente para evitar el error de "Semaphore timeout" (Error 121) en Windows
    // al realizar múltiples peticiones simultáneas al servidor de Somee (que es limitado).
    await _cargarClientes();
    
    // Pequeña pausa para dejar respirar al servidor/red
    await Future.delayed(const Duration(milliseconds: 800));
    
    await _cargarProductos();
  }

  Future<void> _cargarClientes() async {
    setState(() {
      _isLoadingClientes = true;
    });

    try {
      final usuarios = await AuthService.getAllUsuarios();
      setState(() {
        // Filtrar solo clientes (rolId != 2, o rol != 'Admin')
        _clientes = usuarios
            .where((u) => (u.rolId != null && u.rolId != 2) || 
                         (u.rolId == null && u.rol != 'Admin'))
            .toList();
        _clientesFiltrados = _clientes;
        _isLoadingClientes = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingClientes = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar clientes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cargarProductos() async {
    setState(() {
      _isLoadingProductos = true;
    });

    try {
      debugPrint('🟢 CrearPedidoAdmin: Iniciando carga de productos...');
      final productos = await ProductoService.getProductos();
      debugPrint('🟢 CrearPedidoAdmin: Productos recibidos: ${productos.length}');
      
      setState(() {
        _productos = productos;
        _productosFiltrados = productos;
        _isLoadingProductos = false;
      });
      
      debugPrint('✅ CrearPedidoAdmin: Productos cargados exitosamente');
    } catch (e, stackTrace) {
      debugPrint('❌ CrearPedidoAdmin: Error al cargar productos: $e');
      debugPrint('❌ CrearPedidoAdmin: Stack trace: $stackTrace');
      
      setState(() {
        _isLoadingProductos = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar productos: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _filtrarProductos() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _productosFiltrados = _productos;
      } else {
        _productosFiltrados = _productos
            .where((p) =>
                p.nombre.toLowerCase().contains(query) ||
                (p.descripcion?.toLowerCase().contains(query) ?? false))
            .toList();
      }
    });
  }

  List<Usuario> _clientesFiltrados = [];
  void _filtrarClientes() {
    final query = _clientSearchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _clientesFiltrados = _clientes;
      } else {
        _clientesFiltrados = _clientes
            .where((c) =>
                c.nombre.toLowerCase().contains(query) ||
                c.email.toLowerCase().contains(query))
            .toList();
            
        // Si el cliente seleccionado ya no está en el filtro, NO lo deseleccionamos 
        // para evitar que el dropdown explote (Flutter requiere que el valor esté en la lista),
        // así que lo agregamos manualmente si es necesario.
        if (_clienteSeleccionado != null && !_clientesFiltrados.contains(_clienteSeleccionado)) {
          _clientesFiltrados.insert(0, _clienteSeleccionado!);
        }
      }
    });
  }

  void _agregarProducto(Producto producto, {int cantidad = 1}) {
    setState(() {
      _productosAgregados[producto.id!] =
          (_productosAgregados[producto.id!] ?? 0) + cantidad;
    });
  }

  void _eliminarProducto(int productoId) {
    setState(() {
      _productosAgregados.remove(productoId);
    });
  }

  void _actualizarCantidad(int productoId, int nuevaCantidad) {
    if (nuevaCantidad <= 0) {
      _eliminarProducto(productoId);
      return;
    }

    final producto = _productos.firstWhere((p) => p.id == productoId);
    if (nuevaCantidad > producto.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay suficiente stock. Disponible: ${producto.stock}'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _productosAgregados[productoId] = nuevaCantidad;
    });
  }

  double _calcularTotal() {
    double total = 0;
    _productosAgregados.forEach((productoId, cantidad) {
      final producto = _productos.firstWhere((p) => p.id == productoId);
      total += producto.precio * cantidad;
    });
    return total;
  }

Future<void> _crearPedido() async {
    if (_clienteSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona un cliente'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_productosAgregados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor agrega al menos un producto'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Paso 1: Seleccionar tipo de entrega
    final tipoEntrega = await _seleccionarTipoEntrega();
    if (tipoEntrega == null) return;

    String? metodoPago;
    Map<String, String>? datosEntrega;

    // Paso 2: Si es envío a domicilio, seleccionar método de pago
    if (tipoEntrega == 'domicilio') {
      metodoPago = await _seleccionarMetodoPago();
      if (metodoPago == null) return;

      // Paso 3: Mostrar diálogo para datos de entrega
      datosEntrega = await _mostrarDialogoDomicilio(metodoPago);
      if (datosEntrega == null) return;
    } else if (tipoEntrega == 'recoger') {
      metodoPago = null;
      datosEntrega = null;
    }

    setState(() {
      _isCreando = true;
    });

    final pedidoProvider = context.read<PedidoProvider>();

    try {
      final estadoPendienteId = await pedidoProvider.obtenerEstadoPendienteId();
      if (estadoPendienteId == null) {
        throw Exception('No se pudo obtener el estado "Pendiente". Por favor, intenta nuevamente.');
      }

      final ahora = DateTime.now();
      final subtotal = _calcularTotal();
      final envio = tipoEntrega == 'domicilio' ? 5000.0 : 0.0;
      final total = subtotal + envio;
      
      final fechaEntregaFinal = tipoEntrega == 'domicilio' 
          ? ahora.add(const Duration(days: 3)) 
          : ahora;
          
      var pedido = VentaPedido(
        usuarioId: _clienteSeleccionado!.id,
        estadoId: estadoPendienteId,
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
        metodoPago: metodoPago,
        tipoEntrega: tipoEntrega,
        telefonoContacto: tipoEntrega == 'domicilio' && datosEntrega != null
            ? datosEntrega['telefono']
            : _clienteSeleccionado?.telefono,
        observaciones: tipoEntrega == 'domicilio' && datosEntrega != null && datosEntrega['observaciones']!.isNotEmpty
            ? datosEntrega['observaciones']
            : null,
        comprobanteUrl: null,
      );

      if (metodoPago == 'transferencia' && _comprobanteSeleccionado != null) {
        final urlImagen = await ImagenService.subirImagenMultipart(_comprobanteSeleccionado!.path);
        if (urlImagen != null && urlImagen.isNotEmpty) {
          pedido = pedido.copyWith(comprobanteUrl: urlImagen);
        } else {
          throw Exception('No se pudo subir el comprobante. Por favor intenta de nuevo.');
        }
      }

      final detalles = _productosAgregados.entries.map((entry) {
        final producto = _productos.firstWhere((p) => p.id == entry.key);
        return DetallePedido(
          productoId: producto.id,
          cantidad: entry.value,
          precioUnitario: producto.precio,
          subtotal: producto.precio * entry.value,
        );
      }).toList();

      final nuevoPedido = await pedidoProvider.crearPedido(pedido, detalles);

      if (nuevoPedido != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pedido creado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear pedido: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    final width = MediaQuery.of(context).size.width;
    final paddingValue = Responsive.pagePadding(width);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Crear Nuevo Pedido',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        centerTitle: false,
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: paddingValue, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('1', 'Selección de Cliente'),
                      _buildClientSelectionCard(),
                      if (_clienteSeleccionado != null) ...[
                        const SizedBox(height: 24),
                        _buildSectionHeader('2', 'Catálogo de Productos'),
                        _buildProductSearchAndCatalog(width),
                      ],
                      const SizedBox(height: 100), // Espacio para el panel inferior
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_productosAgregados.isNotEmpty)
            _buildBottomSummary(currencyFormat),
          if (_isCreando)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator(color: Colors.black)),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String number, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildClientSelectionCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoadingClientes)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else
            Autocomplete<Usuario>(
              displayStringForOption: (Usuario u) => '${u.nombre} (${u.email})',
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) return _clientes;
                return _clientes.where((u) =>
                    u.nombre.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                    u.email.toLowerCase().contains(textEditingValue.text.toLowerCase()));
              },
              onSelected: (Usuario u) {
                setState(() {
                  _clienteSeleccionado = u;
                  _direccionController.text = u.direccion ?? '';
                  _telefonoController.text = u.telefono ?? '';
                });
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                if (_clienteSeleccionado != null && controller.text.isEmpty) {
                  controller.text = '${_clienteSeleccionado!.nombre} (${_clienteSeleccionado!.email})';
                }
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o correo...',
                    prefixIcon: const Icon(Icons.person_search_rounded),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.black),
                    ),
                    suffixIcon: _clienteSeleccionado != null
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              controller.clear();
                              setState(() {
                                _clienteSeleccionado = null;
                                _productosAgregados.clear();
                              });
                            },
                          )
                        : null,
                  ),
                );
              },
            ),

        ],
      ),
    );
  }

  Widget _buildClientInfoRow(IconData icon, String label, TextEditingController controller, {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.bold)),
              TextField(
                controller: controller,
                maxLines: maxLines,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                  hintText: 'Completar información...',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductSearchAndCatalog(double screenWidth) {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Buscar productos...',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _isLoadingProductos
            ? const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: Responsive.gridCount(screenWidth),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: screenWidth >= Responsive.desktopBreakpoint
                      ? 380.0
                      : (screenWidth >= Responsive.tabletBreakpoint ? 360.0 : 340.0),
                ),
                itemCount: _productosFiltrados.length,
                itemBuilder: (context, index) {
                  final p = _productosFiltrados[index];
                  return ProductoCard(
                    producto: p,
                    onAddToCart: p.disponible && p.stock > 0
                        ? (cantidad) {
                            _agregarProducto(p, cantidad: cantidad);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$cantidad x ${p.nombre} agregado al pedido'),
                                backgroundColor: Colors.green,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        : null,
                  );
                },
              ),
      ],
    );
  }



  Widget _buildBottomSummary(NumberFormat currencyFormat) {
    final total = _calcularTotal();
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 20,
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_productosAgregados.length} productos agregados',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Venta Total',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      currencyFormat.format(total),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -1),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showProductsDetail(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: const Text('VER DETALLE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isCreando ? null : _crearPedido,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('CREAR PEDIDO', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showProductsDetail() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
          final items = _productosAgregados.entries.map((e) {
            final p = _productos.firstWhere((prod) => prod.id == e.key);
            return {'producto': p, 'cantidad': e.value};
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      const Text('Detalle del Pedido', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      const Spacer(),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final p = item['producto'] as Producto;
                      final cant = item['cantidad'] as int;

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: p.imagenUrl != null ? Image.network(p.imagenUrl!, fit: BoxFit.cover) : const Icon(Icons.image),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text(currencyFormat.format(p.precio), style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () {
                                    _actualizarCantidad(p.id!, cant - 1);
                                    setModalState(() {});
                                    setState(() {});
                                    if (_productosAgregados.isEmpty) Navigator.pop(context);
                                  },
                                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                                ),
                                Text('$cant', style: const TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(
                                  onPressed: () {
                                    _actualizarCantidad(p.id!, cant + 1);
                                    setModalState(() {});
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.add_circle_outline, size: 20),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
                  child: Row(
                    children: [
                      const Text('Venta Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text(currencyFormat.format(_calcularTotal()), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

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

  Future<String?> _seleccionarTipoEntrega() async {
    return await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Método de Entrega',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 20),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '¿Cómo prefieres recibir tus productos?',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 14),
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            _OptionTile(
              icon: Icons.store_rounded,
              title: 'Recoger en Punto Físico',
              subtitle: 'Retira tu pedido en nuestra tienda',
              color: Colors.blue,
              onTap: () => Navigator.of(context).pop('recoger'),
            ),
            const SizedBox(height: 12),
            _OptionTile(
              icon: Icons.local_shipping_rounded,
              title: 'Envío a Domicilio',
              subtitle: 'Recibe tu pedido en tu dirección',
              color: Colors.green,
              onTap: () => Navigator.of(context).pop('domicilio'),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Future<String?> _seleccionarMetodoPago() async {
    return await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Método de Pago',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 20),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Selecciona cómo deseas realizar el pago',
              style: TextStyle(
                fontSize: Responsive.fontSize(context, 14),
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            _OptionTile(
              icon: Icons.payments_rounded,
              title: 'Efectivo (Contraentrega)',
              subtitle: 'Paga cuando recibas tu pedido',
              color: Colors.green,
              onTap: () => Navigator.of(context).pop('efectivo'),
            ),
            const SizedBox(height: 12),
            _OptionTile(
              icon: Icons.account_balance_rounded,
              title: 'Transferencia Bancaria',
              subtitle: 'Adjunta el comprobante vía WhatsApp',
              color: Colors.blue,
              onTap: () => Navigator.of(context).pop('transferencia'),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Future<Map<String, String>?> _mostrarDialogoDomicilio(String metodoPago) async {
    
    final usuario = _clienteSeleccionado;
    
    bool tieneDireccionRegistrada = usuario != null && 
                                    usuario.direccion != null && 
                                    usuario.direccion!.isNotEmpty && 
                                    usuario.telefono != null && 
                                    usuario.telefono!.isNotEmpty;
                                    
    bool usarDireccionAlternativa = !tieneDireccionRegistrada;

    _direccionController.clear();
    _telefonoController.clear();
    _observacionesController.clear();
    
    if (tieneDireccionRegistrada) {
      _direccionController.text = usuario.direccion!;
      _telefonoController.text = usuario.telefono!;
    }
    
    _departamentoSeleccionado = null;
    _ciudadSeleccionada = null;
    _ciudades = [];
    _comprobanteSeleccionado = null;

    await _cargarDepartamentos();

    if (!mounted) return null;

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          
          return Container(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + keyboardHeight),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on_rounded, color: Colors.green),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Datos de Entrega',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, 20),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle(context, 'Información del Receptor'),
                  
                  if (tieneDireccionRegistrada) ...[
                    // Selector de direcciones
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  usarDireccionAlternativa = false;
                                  _direccionController.text = usuario.direccion!;
                                  _telefonoController.text = usuario.telefono!;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: !usarDireccionAlternativa ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: !usarDireccionAlternativa ? [
                                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                                  ] : null,
                                ),
                                alignment: Alignment.center,
                                child: Text('Dirección 1', style: TextStyle(
                                  fontWeight: !usarDireccionAlternativa ? FontWeight.bold : FontWeight.normal,
                                  color: !usarDireccionAlternativa ? Theme.of(context).primaryColor : Colors.grey.shade600,
                                )),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  usarDireccionAlternativa = true;
                                  _direccionController.clear();
                                  _telefonoController.clear();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: usarDireccionAlternativa ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: usarDireccionAlternativa ? [
                                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                                  ] : null,
                                ),
                                alignment: Alignment.center,
                                child: Text('Dirección 2', style: TextStyle(
                                  fontWeight: usarDireccionAlternativa ? FontWeight.bold : FontWeight.normal,
                                  color: usarDireccionAlternativa ? Theme.of(context).primaryColor : Colors.grey.shade600,
                                )),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (!tieneDireccionRegistrada || usarDireccionAlternativa) ...[
                    _buildPremiumTextField(
                      context: context,
                      controller: _direccionController,
                      label: 'Dirección de entrega *',
                      icon: Icons.home_rounded,
                      hint: 'Ej: Calle 123 #45-67',
                    ),
                    const SizedBox(height: 16),
                    _buildPremiumTextField(
                      context: context,
                      controller: _telefonoController,
                      label: 'Teléfono de contacto *',
                      icon: Icons.phone_android_rounded,
                      hint: 'Tu número de celular',
                      keyboardType: TextInputType.phone,
                    ),
                  ] else ...[
                    // Tarjeta de Dirección 1 predeterminada
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.home_rounded, color: Theme.of(context).primaryColor, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  usuario!.direccion!,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.phone_android_rounded, color: Colors.grey.shade600, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                usuario.telefono!,
                                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  if (!tieneDireccionRegistrada || usarDireccionAlternativa) ...[
                    const SizedBox(height: 24),
                    _buildSectionTitle(context, 'Ubicación'),
                    _isCargandoDepartamentos
                        ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                        : _buildPremiumDropdown<Departamento>(
                            context: context,
                            label: 'Departamento *',
                            icon: Icons.map_rounded,
                            value: _departamentoSeleccionado,
                            items: _departamentos.map((d) => 
                              DropdownMenuItem(value: d, child: Text(d.nombre))
                            ).toList(),
                            onChanged: (d) async {
                              setDialogState(() {
                                _departamentoSeleccionado = d;
                                _ciudadSeleccionada = null;
                              });
                              if (d != null && d.id != null) {
                                await _cargarCiudades(d.id!);
                                setDialogState(() {});
                              }
                            },
                          ),
                    const SizedBox(height: 16),
                    _departamentoSeleccionado == null
                        ? _buildDisabledDropdown(context, 'Ciudad *', Icons.location_city_rounded, 'Selecciona un dpto. primero')
                        : _isCargandoCiudades
                            ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                            : _buildPremiumDropdown<Ciudad>(
                                context: context,
                                label: 'Ciudad *',
                                icon: Icons.location_city_rounded,
                                value: _ciudadSeleccionada,
                                items: _ciudades.map((c) => 
                                  DropdownMenuItem(value: c, child: Text(c.nombre))
                                ).toList(),
                                onChanged: (c) {
                                  setDialogState(() => _ciudadSeleccionada = c);
                                },
                              ),
                  ] else if (usuario?.departamento != null && usuario?.ciudad != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_city_rounded, color: Colors.grey.shade600, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '${usuario!.ciudad}, ${usuario.departamento}',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, 'Detalles Adicionales'),
                  _buildPremiumTextField(
                    context: context,
                    controller: _observacionesController,
                    label: 'Observaciones (opcional)',
                    icon: Icons.notes_rounded,
                    hint: 'Indicaciones para el repartidor...',
                    maxLines: 2,
                  ),
                  
                  if (metodoPago == 'transferencia') ...[
                    const SizedBox(height: 24),
                    _buildTransferenciaInfo(context),
                  ],
                  
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_validarCampos(context, metodoPago, usarDireccionAlternativa)) {
                          Navigator.of(context).pop({
                            'direccion': _direccionController.text.trim(),
                            'telefono': _telefonoController.text.trim(),
                            'ciudad': usarDireccionAlternativa || !tieneDireccionRegistrada 
                                ? _ciudadSeleccionada!.nombre 
                                : (usuario?.ciudad ?? ''),
                            'departamento': usarDireccionAlternativa || !tieneDireccionRegistrada 
                                ? _departamentoSeleccionado!.nombre 
                                : (usuario?.departamento ?? ''),
                            'observaciones': _observacionesController.text.trim(),
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('Confirmar Pedido', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    return result;
  }

  bool _validarCampos(BuildContext context, String metodoPago, bool usarDireccionAlternativa) {
    if (_direccionController.text.trim().isEmpty) {
      _showSnackBar(context, 'La dirección es obligatoria');
      return false;
    }
    if (_telefonoController.text.trim().isEmpty) {
      _showSnackBar(context, 'El teléfono es obligatorio');
      return false;
    }
    
    if (usarDireccionAlternativa) {
      if (_departamentoSeleccionado == null) {
        _showSnackBar(context, 'Selecciona un departamento');
        return false;
      }
      if (_ciudadSeleccionada == null) {
        _showSnackBar(context, 'Selecciona una ciudad');
        return false;
      }
    }
    
    if (metodoPago == 'transferencia' && _comprobanteSeleccionado == null) {
      _showSnackBar(context, 'Debes adjuntar el comprobante de transferencia');
      return false;
    }
    return true;
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildPremiumTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.5)),
        ),
      ),
    );
  }

  Widget _buildPremiumDropdown<T>({
    required BuildContext context,
    required String label,
    required IconData icon,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Theme.of(context).primaryColor),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildDisabledDropdown(BuildContext context, String label, IconData icon, String hint) {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade100)),
      ),
      items: const [],
      onChanged: null,
      hint: Text(hint, style: const TextStyle(fontSize: 14)),
    );
  }

  Widget _buildTransferenciaInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              const Text('Pago por Transferencia', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Por favor, adjunta el comprobante de tu transferencia para poder procesar tu pedido.',
            style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
          ),
          const SizedBox(height: 16),
          if (_comprobanteSeleccionado != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.image, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _comprobanteSeleccionado!.name,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                    onPressed: () {
                      if (context.mounted) {
                        (context as Element).markNeedsBuild();
                      }
                      _comprobanteSeleccionado = null;
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final imagen = await ImagenService.seleccionarImagen();
                if (imagen != null) {
                  if (context.mounted) {
                    (context as Element).markNeedsBuild();
                  }
                  _comprobanteSeleccionado = imagen;
                }
              },
              icon: Icon(_comprobanteSeleccionado == null ? Icons.upload_file : Icons.edit, color: Colors.white, size: 20),
              label: Text(_comprobanteSeleccionado == null ? 'Seleccionar Comprobante' : 'Cambiar Imagen', style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}