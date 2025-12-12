import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/categoria_model.dart';
import '../services/categoria_service.dart';

/// Card de categoría
class CategoriaCard extends StatelessWidget {
  final Categoria categoria;
  final VoidCallback onTap;

  const CategoriaCard({
    super.key,
    required this.categoria,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Obtener URL de imagen usando idImagen
    String? urlImagen;
    
    // Debug: Log de la categoría
    debugPrint('🔵 CategoriaCard: Categoría "${categoria.nombre}" - idImagen: ${categoria.idImagen}');
    
    if (categoria.idImagen != null) {
      urlImagen = CategoriaService.getUrlImagen(categoria.idImagen);
      debugPrint('🔵 CategoriaCard: Buscando imagen con idImagen ${categoria.idImagen} -> URL: $urlImagen');
    }
    
    debugPrint('🔵 CategoriaCard: URL final de imagen: $urlImagen');

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Imagen - Ocupa 60% de la card
            Expanded(
              flex: 6,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: urlImagen != null && urlImagen.isNotEmpty
                    ? Image.network(
                        urlImagen,
                        fit: BoxFit.cover,
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
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('❌ CategoriaCard: Error al cargar imagen: $error');
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.category,
                              size: 50,
                              color: Colors.grey,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.category,
                          size: 50,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
            // Texto - Ocupa 40% de la card
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // NOMBRE - Primero, grande y bold
                    Text(
                      categoria.nombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // DESCRIPCIÓN - Después, más pequeña y gris
                    if (categoria.descripcion != null &&
                        categoria.descripcion!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        categoria.descripcion!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

