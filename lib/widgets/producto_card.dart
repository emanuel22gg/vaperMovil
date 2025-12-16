import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/producto_model.dart';
import '../services/producto_service.dart';

/// Card de producto
class ProductoCard extends StatefulWidget {
  final Producto producto;
  final Function(int quantity)? onAddToCart;
  final VoidCallback? onTap;

  const ProductoCard({
    super.key,
    required this.producto,
    this.onAddToCart,
    this.onTap,
  });

  @override
  State<ProductoCard> createState() => _ProductoCardState();
}

class _ProductoCardState extends State<ProductoCard> {
  int _quantity = 1;

  void _incrementQuantity() {
    if (_quantity < widget.producto.stock) {
      setState(() {
        _quantity++;
      });
    }
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() {
        _quantity--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    
    // Obtener URL de imagen usando idImagen o imagenUrl como fallback
    String? urlImagen;
    if (widget.producto.idImagen != null) {
      urlImagen = ProductoService.getUrlImagen(widget.producto.idImagen);
    }
    // Si no se encontró por idImagen, usar imagenUrl como fallback
    if (urlImagen == null || urlImagen.isEmpty) {
      urlImagen = widget.producto.imagenUrl;
    }

    // Determinar estado del stock
    final bool estaAgotado = widget.producto.stock == 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final imageHeight = (constraints.maxWidth * 0.75).clamp(140.0, 220.0);

        return Card(
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.08),
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Imagen con altura adaptable al ancho de la card
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Container(
                    height: imageHeight.toDouble(),
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: urlImagen != null && urlImagen.isNotEmpty
                        ? Image.network(
                            urlImagen,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: imageHeight.toDouble(),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) {
                                return child;
                              }
                              return Container(
                                color: Colors.grey[200],
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[300],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),
                  ),
                ),
                // Contenido
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Nombre del producto - 2 líneas máximo
                      Text(
                        widget.producto.nombre.isNotEmpty ? widget.producto.nombre : 'Sin nombre',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Precio - Grande, bold, color azul
                      Text(
                        currencyFormat.format(widget.producto.precio),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Stock - Solo mostrar si stock > 0
                      const SizedBox(height: 4),
                      // Stock -> Eliminado por solicitud del usuario
                      const SizedBox(height: 8),
                      
                      // Controles de cantidad
                      if (!estaAgotado) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildQuantityButton(
                              icon: Icons.remove,
                              onPressed: _quantity > 1 ? _decrementQuantity : null,
                            ),
                            Text(
                              '$_quantity',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            _buildQuantityButton(
                              icon: Icons.add,
                              onPressed: _quantity < widget.producto.stock 
                                  ? _incrementQuantity 
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Botón Agregar o Agotado - Altura fija 40px
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: estaAgotado
                            ? OutlinedButton(
                                onPressed: null,
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  side: const BorderSide(color: Color(0xFFBDBDBD)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Agotado',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF757575),
                                  ),
                                ),
                              )
                            : widget.onAddToCart != null
                                ? ElevatedButton(
                                    onPressed: () => widget.onAddToCart!(_quantity),
                                    style: ElevatedButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      backgroundColor: const Color(0xFF2196F3),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Agregar',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    VoidCallback? onPressed,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: onPressed != null ? Colors.grey[200] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(icon, size: 16),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        color: onPressed != null ? Colors.black : Colors.grey,
      ),
    );
  }
}

