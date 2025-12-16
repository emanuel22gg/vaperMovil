import 'package:flutter/material.dart';
import '../../models/producto_model.dart';
import '../../services/producto_service.dart';
import '../../widgets/producto_card.dart';
import '../../providers/carrito_provider.dart';
import 'package:provider/provider.dart';
import '../../utils/responsive.dart';
import 'carrito_screen.dart';

/// Pantalla de productos por categoría
class ProductosScreen extends StatefulWidget {
  final int categoriaId;
  final String nombreCategoria;

  const ProductosScreen({
    super.key,
    required this.categoriaId,
    required this.nombreCategoria,
  });

  @override
  State<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends State<ProductosScreen> {
  List<Producto> _productos = [];
  List<Producto> _productosFiltrados = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarProductos();
    _searchController.addListener(_filtrarProductos);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarProductos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Cargar todos los productos
      final todosLosProductos = await ProductoService.getProductos();
      
      // Filtrar productos para mostrar SOLO los de esta categoría
      final productosFiltrados = todosLosProductos
          .where((p) => p.categoriaId == widget.categoriaId)
          .toList();
      
      setState(() {
        _productos = productosFiltrados;
        _productosFiltrados = productosFiltrados;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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

  void _agregarAlCarrito(Producto producto, {int cantidad = 1}) {
    final carritoProvider = context.read<CarritoProvider>();

    try {
      carritoProvider.agregarProducto(producto, cantidad: cantidad);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$cantidad x ${producto.nombre} agregado al carrito'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _navegarACarrito() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CarritoScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final carritoProvider = context.watch<CarritoProvider>();
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = Responsive.gridCount(screenWidth);
    final horizontalPadding = Responsive.pagePadding(screenWidth);
    // Aumentar altura de la tarjeta para acomodar los controles de cantidad
    final cardHeight = screenWidth >= Responsive.desktopBreakpoint
        ? 380.0
        : (screenWidth >= Responsive.tabletBreakpoint ? 360.0 : 340.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nombreCategoria),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 12,
            ),
            child: TextField(
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
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (_) => _filtrarProductos(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error: $_error',
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _cargarProductos,
                              child: const Text('Reintentar'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _cargarProductos,
                        child: _productosFiltrados.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 80,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No hay productos en esta categoría',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Intenta buscar con otro término',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : GridView.builder(
                                padding: EdgeInsets.all(horizontalPadding),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent: cardHeight,
                                ),
                                itemCount: _productosFiltrados.length,
                                itemBuilder: (context, index) {
                                  final producto = _productosFiltrados[index];
                                  return ProductoCard(
                                    producto: producto,
                                    onAddToCart: producto.disponible
                                        ? (cantidad) => _agregarAlCarrito(producto, cantidad: cantidad)
                                        : null,
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navegarACarrito,
        backgroundColor: const Color(0xFF4CAF50),
        icon: Stack(
          children: [
            const Icon(Icons.shopping_cart, color: Colors.white),
            if (carritoProvider.cantidadTotal > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 14,
                    minHeight: 14,
                  ),
                  child: Text(
                    '${carritoProvider.cantidadTotal}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        label: Text(
          'Total: \$${carritoProvider.precioTotal.toStringAsFixed(0)}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

