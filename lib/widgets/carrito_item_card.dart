import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/carrito_item_model.dart';
import '../services/producto_service.dart';
import '../utils/responsive.dart';

class CarritoItemCard extends StatelessWidget {
  final CarritoItem item;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onDelete;

  const CarritoItemCard({
    super.key,
    required this.item,
    required this.onIncrement,
    required this.onDecrement,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
    
    // Obtener URL de imagen
    String? urlImagen;
    if (item.producto.idImagen != null) {
      urlImagen = ProductoService.getUrlImagen(item.producto.idImagen);
    }
    if (urlImagen == null || urlImagen.isEmpty) {
      urlImagen = item.producto.imagenUrl;
    }

    return Container(
      margin: EdgeInsets.only(bottom: Responsive.scaleHeight(context, 16)),
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
              // Imagen del producto
              Container(
                width: Responsive.scaleWidth(context, 100),
                color: Colors.grey.shade100,
                child: urlImagen != null && urlImagen.isNotEmpty
                    ? Image.network(
                        urlImagen,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => 
                          const Icon(Icons.image_not_supported, color: Colors.grey),
                      )
                    : const Icon(Icons.image_not_supported, color: Colors.grey),
              ),
              
              // Información y controles
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(Responsive.scaleWidth(context, 12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item.producto.nombre,
                              style: TextStyle(
                                fontSize: Responsive.fontSize(context, 16),
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: onDelete,
                            child: Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.red.shade400,
                              size: Responsive.iconSize(context, 22),
                            ),
                          ),
                        ],
                      ),
                      
                      const Spacer(),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currencyFormat.format(item.producto.precio),
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 14),
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              SizedBox(height: Responsive.scaleHeight(context, 4)),
                              Text(
                                currencyFormat.format(item.subtotal),
                                style: TextStyle(
                                  fontSize: Responsive.fontSize(context, 17),
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ],
                          ),
                          
                          // Controles de cantidad
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                _QuantityButton(
                                  icon: Icons.remove,
                                  onPressed: onDecrement,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(
                                    '${item.cantidad}',
                                    style: TextStyle(
                                      fontSize: Responsive.fontSize(context, 15),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                _QuantityButton(
                                  icon: Icons.add,
                                  onPressed: onIncrement,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
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

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _QuantityButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(
            icon,
            size: 18,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
