import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/usuario_model.dart';
import '../../models/producto_model.dart';
import '../../models/venta_pedido_model.dart';
import '../../models/detalle_pedido_model.dart';
import '../../services/auth_service.dart';
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

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Pedido'),
        content: const Text('¿Estás seguro de crear este pedido?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isCreando = true;
    });

    final pedidoProvider = context.read<PedidoProvider>();

    try {
      // Obtener el ID del estado "Pendiente"
      final estadoPendienteId = await pedidoProvider.obtenerEstadoPendienteId();
      if (estadoPendienteId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo obtener el estado "Pendiente". Por favor, intenta nuevamente.'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isCreando = false;
          });
        }
        return;
      }

      // Crear pedido según el formato que espera la API
      final ahora = DateTime.now();
      final subtotal = _calcularTotal();
      final envio = 0.0; // Para pedidos del admin, sin envío por defecto
      final total = subtotal + envio;
      
      final pedido = VentaPedido(
        usuarioId: _clienteSeleccionado!.id,
        estadoId: estadoPendienteId, // Pendiente
        fechaCreacion: ahora,
        fechaEntrega: null, // Se puede establecer después
        subtotal: subtotal,
        envio: envio,
        total: total,
        direccionEntrega: _direccionController.text.trim().isNotEmpty
            ? _direccionController.text.trim()
            : _clienteSeleccionado!.direccion,
        ciudadEntrega: null, // Se puede agregar después si es necesario
        departamentoEntrega: null, // Se puede agregar después si es necesario
        metodoPago: null, // Se puede establecer después
        // Campos adicionales para uso interno
        telefonoContacto: _telefonoController.text.trim().isNotEmpty
            ? _telefonoController.text.trim()
            : _clienteSeleccionado!.telefono,
        observaciones: _observacionesController.text.trim().isNotEmpty
            ? _observacionesController.text.trim()
            : null,
      );

      // Crear detalles
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
          if (_clienteSeleccionado != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildClientInfoRow(Icons.location_on_outlined, 'Dirección', _direccionController),
                  const Divider(height: 24),
                  _buildClientInfoRow(Icons.phone_outlined, 'Teléfono', _telefonoController),
                  const Divider(height: 24),
                  _buildClientInfoRow(Icons.note_alt_outlined, 'Observaciones', _observacionesController, maxLines: 2),
                ],
              ),
            ),
          ],
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
                  crossAxisCount: Responsive.gridCount(screenWidth, mobile: 2, tablet: 3, desktop: 4),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 260,
                ),
                itemCount: _productosFiltrados.length,
                itemBuilder: (context, index) {
                  final p = _productosFiltrados[index];
                  final isAdded = _productosAgregados.containsKey(p.id);
                  return _buildModernProductCard(p, isAdded);
                },
              ),
      ],
    );
  }

  Widget _buildModernProductCard(Producto p, bool isAdded) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: p.imagenUrl != null && p.imagenUrl!.isNotEmpty
                    ? Image.network(p.imagenUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined, color: Colors.grey))
                    : const Icon(Icons.image_outlined, color: Colors.grey),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  NumberFormat.currency(symbol: '\$', decimalDigits: 0).format(p.precio),
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.blue[800]),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: p.disponible && p.stock > 0 ? () => _agregarProducto(p) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAdded ? Colors.green : Colors.black,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 0),
                      minimumSize: const Size(0, 32),
                    ),
                    child: Text(
                      isAdded ? 'AÑADIDO ✓' : 'AÑADIR',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
}