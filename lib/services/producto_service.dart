import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/producto_model.dart';
import '../models/imagen_model.dart';
import 'api_service.dart';

/// Servicio de Productos
class ProductoService {
  // Map estático para almacenar idImagen -> urlimagen
  static Map<int, String> _imagenesCache = {};
  static bool _imagenesCargadas = false;

  /// Obtener URL de imagen por idImagen
  static String? getUrlImagen(int? idImagen) {
    if (idImagen == null) return null;
    return _imagenesCache[idImagen];
  }

  /// Cargar todas las imágenes y crear el Map idImagen -> urlimagen
  static Future<void> cargarImagenes() async {
    if (_imagenesCargadas && _imagenesCache.isNotEmpty) {
      debugPrint('✅ ProductoService: Imágenes ya están en caché');
      return;
    }

    try {
      debugPrint('🔵 ProductoService: Cargando imágenes desde ${ApiConfig.imagenesEndpoint}');
      
      final response = await ApiService.get(
        ApiConfig.imagenesEndpoint,
      );

      if (response.statusCode == 200) {
        try {
          final List<dynamic> imagenesJson = jsonDecode(response.body);
          debugPrint('🔵 ProductoService: Imágenes JSON parseadas: ${imagenesJson.length} items');
          
          // Limpiar el caché anterior
          _imagenesCache.clear();
          
          // Crear el Map idImagen -> urlimagen
          for (var json in imagenesJson) {
            try {
              final imagen = Imagen.fromJson(json as Map<String, dynamic>);
              if (imagen.idImagen != null && 
                  imagen.urlimagen != null && 
                  imagen.urlimagen!.isNotEmpty) {
                _imagenesCache[imagen.idImagen!] = imagen.urlimagen!;
              }
            } catch (e) {
              debugPrint('❌ ProductoService: Error al parsear imagen: $e');
            }
          }

          _imagenesCargadas = true;
          debugPrint('✅ ProductoService: ${_imagenesCache.length} imágenes cargadas en caché');
        } catch (e) {
          debugPrint('❌ ProductoService: Error al parsear imágenes JSON: $e');
          _imagenesCargadas = false;
        }
      } else {
        debugPrint('⚠️ ProductoService: Error al cargar imágenes: ${response.statusCode}');
        _imagenesCargadas = false;
      }
    } catch (e) {
      debugPrint('⚠️ ProductoService: Error al obtener imágenes: $e');
      _imagenesCargadas = false;
    }
  }

  /// Obtener todas las imágenes (método legacy, mantener por compatibilidad)
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
          
          // Cargar imágenes una sola vez si no están cargadas
          try {
            await cargarImagenes();
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
        
        // Cargar imágenes una sola vez si no están cargadas
        try {
          await cargarImagenes();
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

