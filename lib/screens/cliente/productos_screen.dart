import 'package:flutter/material.dart';
import '../../models/producto_model.dart';
import '../../services/producto_service.dart';
import '../../widgets/producto_card.dart';
import '../../providers/carrito_provider.dart';
import 'package:provider/provider.dart';

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

  void _agregarAlCarrito(Producto producto) {
    final carritoProvider = context.read<CarritoProvider>();

    try {
      carritoProvider.agregarProducto(producto);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${producto.nombre} agregado al carrito'),
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

  // Función para determinar el número de columnas según el ancho de pantalla
  int _getCrossAxisCount(double width) {
    if (width > 1200) {
      return 4; // Desktop
    } else if (width > 600) {
      return 3; // Tablet
    } else {
      return 2; // Móvil
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = _getCrossAxisCount(screenWidth);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nombreCategoria),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                padding: const EdgeInsets.all(16),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent: 320, // Altura fija de 320px por card
                                ),
                                itemCount: _productosFiltrados.length,
                                itemBuilder: (context, index) {
                                  final producto = _productosFiltrados[index];
                                  return ProductoCard(
                                    producto: producto,
                                    onAddToCart: producto.disponible
                                        ? () => _agregarAlCarrito(producto)
                                        : null,
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

