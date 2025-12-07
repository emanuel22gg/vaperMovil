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
  }

  @override
  void dispose() {
    _searchController.dispose();
    _direccionController.dispose();
    _telefonoController.dispose();
    _observacionesController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    await Future.wait([
      _cargarClientes(),
      _cargarProductos(),
    ]);
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

  void _agregarProducto(Producto producto) {
    setState(() {
      _productosAgregados[producto.id!] =
          (_productosAgregados[producto.id!] ?? 0) + 1;
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

      // Crear pedido
      final pedido = VentaPedido(
        usuarioId: _clienteSeleccionado!.id,
        estadoId: 1, // En Revisión
        fechaPedido: DateTime.now(),
        total: _calcularTotal(),
        direccionEntrega: _direccionController.text.trim().isNotEmpty
            ? _direccionController.text.trim()
            : _clienteSeleccionado!.direccion,
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
    final productosAgregadosList = _productosAgregados.entries
        .map((entry) => _productos.firstWhere((p) => p.id == entry.key))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Pedido'),
        backgroundColor: const Color(0xFF9C27B0),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selección de Cliente
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cliente',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _isLoadingClientes
                        ? const Center(child: CircularProgressIndicator())
                        : DropdownButtonFormField<Usuario>(
                            initialValue: _clienteSeleccionado,
                            decoration: const InputDecoration(
                              labelText: 'Seleccionar cliente',
                              border: OutlineInputBorder(),
                            ),
                            items: _clientes.map((cliente) {
                              return DropdownMenuItem(
                                value: cliente,
                                child: Text('${cliente.nombre} - ${cliente.email}'),
                              );
                            }).toList(),
                            onChanged: (cliente) {
                              setState(() {
                                _clienteSeleccionado = cliente;
                                if (cliente != null) {
                                  _direccionController.text =
                                      cliente.direccion ?? '';
                                  _telefonoController.text = cliente.telefono ?? '';
                                }
                              });
                            },
                          ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Información adicional
            if (_clienteSeleccionado != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Información de Entrega',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _direccionController,
                        decoration: const InputDecoration(
                          labelText: 'Dirección de entrega',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _telefonoController,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono de contacto',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _observacionesController,
                        decoration: const InputDecoration(
                          labelText: 'Observaciones (opcional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Búsqueda de productos
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Productos Disponibles',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar productos...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Lista de productos disponibles
            _isLoadingProductos
                ? const Center(child: CircularProgressIndicator())
                : _productosFiltrados.isEmpty
                    ? const Center(
                        child: Text('No hay productos disponibles'),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.7,
                        ),
                        itemCount: _productosFiltrados.length,
                        itemBuilder: (context, index) {
                          final producto = _productosFiltrados[index];
                          final cantidadAgregada =
                              _productosAgregados[producto.id] ?? 0;
                          return ProductoCard(
                            producto: producto,
                            onAddToCart: producto.disponible
                                ? () => _agregarProducto(producto)
                                : null,
                            onTap: producto.disponible
                                ? () {
                                    if (cantidadAgregada == 0) {
                                      _agregarProducto(producto);
                                    }
                                  }
                                : null,
                          );
                        },
                      ),

            const SizedBox(height: 24),

            // Productos agregados
            if (_productosAgregados.isNotEmpty) ...[
              Card(
                color: Colors.purple[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Productos Agregados',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...productosAgregadosList.map((producto) {
                        final cantidad = _productosAgregados[producto.id]!;
                        final subtotal = producto.precio * cantidad;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: producto.imagenUrl != null
                                ? Image.network(
                                    producto.imagenUrl!,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.image_not_supported),
                                  )
                                : const Icon(Icons.image_not_supported),
                            title: Text(producto.nombre),
                            subtitle: Text(
                              '${currencyFormat.format(producto.precio)} x $cantidad = ${currencyFormat.format(subtotal)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () {
                                    _actualizarCantidad(producto.id!, cantidad - 1);
                                  },
                                ),
                                Text('$cantidad'),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () {
                                    _actualizarCantidad(producto.id!, cantidad + 1);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () {
                                    _eliminarProducto(producto.id!);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const Divider(),
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
                            currencyFormat.format(_calcularTotal()),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Botón crear pedido
            if (_productosAgregados.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isCreando ? null : _crearPedido,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9C27B0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isCreando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Crear Pedido',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

