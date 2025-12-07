import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/producto_model.dart';
import '../models/imagen_model.dart';
import 'api_service.dart';

/// Servicio de Productos
class ProductoService {
  /// Obtener todas las imágenes
  static Future<List<Imagen>> getImagenes() async {
    try {
      debugPrint('🔵 ProductoService: Cargando imágenes desde ${ApiConfig.imagenesEndpoint}');
      
      final response = await ApiService.get(
        ApiConfig.imagenesEndpoint,
      );

      if (response.statusCode == 200) {
        try {
          final List<dynamic> imagenesJson = jsonDecode(response.body);
          debugPrint('🔵 ProductoService: Imágenes JSON parseadas: ${imagenesJson.length} items');
          
          final imagenes = imagenesJson
              .map((json) {
                try {
                  return Imagen.fromJson(json as Map<String, dynamic>);
                } catch (e) {
                  debugPrint('❌ ProductoService: Error al parsear imagen: $e');
                  return null;
                }
              })
              .whereType<Imagen>()
              .toList();

          debugPrint('✅ ProductoService: Imágenes cargadas exitosamente: ${imagenes.length}');
          return imagenes;
        } catch (e) {
          debugPrint('❌ ProductoService: Error al parsear imágenes JSON: $e');
          return [];
        }
      } else {
        debugPrint('⚠️ ProductoService: Error al cargar imágenes: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('⚠️ ProductoService: Error al obtener imágenes: $e');
      return [];
    }
  }

  /// Asignar imágenes a productos y retornar lista actualizada
  static List<Producto> _asignarImagenesAProductos(
    List<Producto> productos,
    List<Imagen> imagenes,
  ) {
    // Crear un mapa de productoId -> lista de imágenes
    final Map<int, List<Imagen>> imagenesPorProducto = {};
    
    for (var imagen in imagenes) {
      if (imagen.productoId != null && imagen.urlimagen != null && imagen.urlimagen!.isNotEmpty) {
        imagenesPorProducto.putIfAbsent(imagen.productoId!, () => []).add(imagen);
      }
    }

    // Crear nueva lista de productos con imágenes asignadas
    return productos.map((producto) {
      if (producto.id != null && imagenesPorProducto.containsKey(producto.id)) {
        final imagenesProducto = imagenesPorProducto[producto.id]!;
        if (imagenesProducto.isNotEmpty) {
          // Usar la primera imagen disponible
          final primeraImagen = imagenesProducto.first.urlimagen;
          if (primeraImagen != null && primeraImagen.isNotEmpty) {
            debugPrint('✅ ProductoService: Imagen asignada a producto ${producto.id}: $primeraImagen');
            // Retornar producto actualizado con la imagen
            return Producto(
              id: producto.id,
              nombre: producto.nombre,
              descripcion: producto.descripcion,
              precio: producto.precio,
              stock: producto.stock,
              imagenUrl: primeraImagen,
              categoriaId: producto.categoriaId,
              categoriaNombre: producto.categoriaNombre,
            );
          }
        }
      }
      // Retornar producto sin cambios si no tiene imagen
      return producto;
    }).toList();
  }

  /// Obtener todos los productos
  static Future<List<Producto>> getProductos({int? categoriaId}) async {
    try {
      Map<String, String>? queryParams;
      if (categoriaId != null) {
        queryParams = {'categoriaId': categoriaId.toString()};
      }

      final url = '${ApiConfig.baseUrl}${ApiConfig.productosEndpoint}';
      debugPrint('🔵 ProductoService: Llamando a GET $url');
      if (queryParams != null) {
        debugPrint('🔵 ProductoService: Query params: $queryParams');
      }

      final response = await ApiService.get(
        ApiConfig.productosEndpoint,
        queryParams: queryParams,
      );

      debugPrint('🔵 ProductoService: Status Code: ${response.statusCode}');
      debugPrint('🔵 ProductoService: Response Body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final List<dynamic> productosJson = jsonDecode(response.body);
          debugPrint('🔵 ProductoService: Productos JSON parseados: ${productosJson.length} items');
          
          if (productosJson.isEmpty) {
            debugPrint('⚠️ ProductoService: La API devolvió una lista vacía');
            return [];
          }

          // Mostrar el primer producto como ejemplo para depuración
          if (productosJson.isNotEmpty) {
            debugPrint('🔵 ProductoService: Primer producto ejemplo: ${productosJson[0]}');
          }

          final productos = productosJson
              .map((json) {
                try {
                  return Producto.fromJson(json as Map<String, dynamic>);
                } catch (e) {
                  debugPrint('❌ ProductoService: Error al parsear producto: $e');
                  debugPrint('❌ ProductoService: JSON del producto: $json');
                  rethrow;
                }
              })
              .toList();

          debugPrint('✅ ProductoService: Productos cargados exitosamente: ${productos.length}');
          
          // Cargar imágenes y asignarlas a los productos
          try {
            final imagenes = await getImagenes();
            if (imagenes.isNotEmpty) {
              final productosConImagenes = _asignarImagenesAProductos(productos, imagenes);
              return productosConImagenes;
            }
          } catch (e) {
            debugPrint('⚠️ ProductoService: Error al cargar imágenes, continuando sin imágenes: $e');
          }
          
          return productos;
        } catch (e) {
          debugPrint('❌ ProductoService: Error al parsear JSON: $e');
          debugPrint('❌ ProductoService: Response body completo: ${response.body}');
          throw Exception('Error al parsear productos: $e');
        }
      } else {
        final errorMsg = ApiService.handleError(response);
        debugPrint('❌ ProductoService: Error HTTP ${response.statusCode}: $errorMsg');
        debugPrint('❌ ProductoService: Response body: ${response.body}');
        throw Exception(errorMsg);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ ProductoService: Excepción capturada: $e');
      debugPrint('❌ ProductoService: Stack trace: $stackTrace');
      throw Exception('Error al obtener productos: $e');
    }
  }

  /// Obtener producto por ID
  static Future<Producto> getProductoById(int id) async {
    try {
      final response = await ApiService.get('${ApiConfig.productosEndpoint}/$id');

      if (response.statusCode == 200) {
        final productoJson = jsonDecode(response.body);
        final producto = Producto.fromJson(productoJson as Map<String, dynamic>);
        
        // Cargar imágenes y asignar al producto
        try {
          final imagenes = await getImagenes();
          if (imagenes.isNotEmpty) {
            final imagenesProducto = imagenes
                .where((img) => img.productoId == id && img.urlimagen != null && img.urlimagen!.isNotEmpty)
                .toList();
            
            if (imagenesProducto.isNotEmpty) {
              final primeraImagen = imagenesProducto.first.urlimagen;
              return Producto(
                id: producto.id,
                nombre: producto.nombre,
                descripcion: producto.descripcion,
                precio: producto.precio,
                stock: producto.stock,
                imagenUrl: primeraImagen,
                categoriaId: producto.categoriaId,
                categoriaNombre: producto.categoriaNombre,
              );
            }
          }
        } catch (e) {
          debugPrint('⚠️ ProductoService: Error al cargar imágenes para producto $id: $e');
        }
        
        return producto;
      } else {
        throw Exception(ApiService.handleError(response));
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// Buscar productos por nombre
  static Future<List<Producto>> buscarProductos(String query) async {
    try {
      final productos = await getProductos();
      return productos
          .where((p) =>
              p.nombre.toLowerCase().contains(query.toLowerCase()) ||
              (p.descripcion?.toLowerCase().contains(query.toLowerCase()) ??
                  false))
          .toList();
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}

