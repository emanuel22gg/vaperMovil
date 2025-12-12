import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/producto_model.dart';
import '../services/producto_service.dart';

/// Card de producto
class ProductoCard extends StatelessWidget {
  final Producto producto;
  final VoidCallback? onAddToCart;
  final VoidCallback? onTap;

  const ProductoCard({
    super.key,
    required this.producto,
    this.onAddToCart,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    
    // Obtener URL de imagen usando idImagen o imagenUrl como fallback
    String? urlImagen;
    if (producto.idImagen != null) {
      urlImagen = ProductoService.getUrlImagen(producto.idImagen);
    }
    // Si no se encontró por idImagen, usar imagenUrl como fallback
    if (urlImagen == null || urlImagen.isEmpty) {
      urlImagen = producto.imagenUrl;
    }

    // Determinar estado del stock
    final bool estaAgotado = producto.stock == 0;

    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Imagen - Altura fija 160px
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Container(
                height: 160,
                width: double.infinity,
                color: Colors.grey[200],
                child: urlImagen != null && urlImagen.isNotEmpty
                    ? Image.network(
                        urlImagen,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 160,
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
            // Contenido - Debe caber en 160px (320px total - 160px imagen)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nombre del producto - 2 líneas máximo
                  Text(
                    producto.nombre.isNotEmpty ? producto.nombre : 'Sin nombre',
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
                    currencyFormat.format(producto.precio),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2196F3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Stock - Solo mostrar si stock > 0
                  if (producto.stock > 0)
                    Text(
                      'Stock: ${producto.stock}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF757575),
                      ),
                    ),
                  const SizedBox(height: 8),
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
                        : onAddToCart != null
                            ? ElevatedButton(
                                onPressed: onAddToCart,
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
  }
}

