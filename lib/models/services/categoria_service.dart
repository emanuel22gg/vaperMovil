import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/categoria_model.dart';
import '../models/imagen_model.dart';
import 'api_service.dart';

/// Servicio de Categorías
class CategoriaService {
  // Map estático para almacenar idImagen -> urlimagen
  static Map<int, String> _imagenesCache = {};
  static bool _imagenesCargadas = false;

  /// Obtener URL de imagen por idImagen
  static String? getUrlImagen(int? idImagen) {
    if (idImagen == null) {
      debugPrint('⚠️ CategoriaService.getUrlImagen: idImagen es null');
      return null;
    }
    
    final url = _imagenesCache[idImagen];
    debugPrint('🔵 CategoriaService.getUrlImagen: idImagen=$idImagen -> URL: $url');
    debugPrint('🔵 CategoriaService.getUrlImagen: Tamaño del caché: ${_imagenesCache.length}');
    
    if (url == null) {
      debugPrint('⚠️ CategoriaService.getUrlImagen: No se encontró URL para idImagen=$idImagen');
      debugPrint('🔵 CategoriaService.getUrlImagen: Keys en caché: ${_imagenesCache.keys.toList()}');
    }
    
    return url;
  }

  /// Cargar todas las imágenes y crear el Map idImagen -> urlimagen
  static Future<void> cargarImagenes() async {
    if (_imagenesCargadas && _imagenesCache.isNotEmpty) {
      debugPrint('✅ CategoriaService: Imágenes ya están en caché');
      return;
    }

    try {
      debugPrint('🔵 CategoriaService: Cargando imágenes desde ${ApiConfig.imagenesEndpoint}');
      
      final response = await ApiService.get(
        ApiConfig.imagenesEndpoint,
      );

      if (response.statusCode == 200) {
        try {
          final List<dynamic> imagenesJson = jsonDecode(response.body);
          debugPrint('🔵 CategoriaService: Imágenes JSON parseadas: ${imagenesJson.length} items');
          
          // Limpiar el caché anterior
          _imagenesCache.clear();
          
          // Crear el Map idImagen -> urlimagen
          for (var json in imagenesJson) {
            try {
              final imagen = Imagen.fromJson(json as Map<String, dynamic>);
              debugPrint('🔵 CategoriaService: Procesando imagen - idImagen: ${imagen.idImagen}, urlimagen: ${imagen.urlimagen}');
              
              if (imagen.idImagen != null && 
                  imagen.urlimagen != null && 
                  imagen.urlimagen!.isNotEmpty) {
                _imagenesCache[imagen.idImagen!] = imagen.urlimagen!;
                debugPrint('✅ CategoriaService: Imagen agregada al caché - idImagen: ${imagen.idImagen}, URL: ${imagen.urlimagen}');
              } else {
                debugPrint('⚠️ CategoriaService: Imagen omitida - idImagen: ${imagen.idImagen}, urlimagen: ${imagen.urlimagen}');
              }
            } catch (e) {
              debugPrint('❌ CategoriaService: Error al parsear imagen: $e');
              debugPrint('❌ CategoriaService: JSON de la imagen: $json');
            }
          }

          _imagenesCargadas = true;
          debugPrint('✅ CategoriaService: ${_imagenesCache.length} imágenes cargadas en caché');
          debugPrint('🔵 CategoriaService: IDs de imágenes en caché: ${_imagenesCache.keys.toList()}');
        } catch (e) {
          debugPrint('❌ CategoriaService: Error al parsear imágenes JSON: $e');
          _imagenesCargadas = false;
        }
      } else {
        debugPrint('⚠️ CategoriaService: Error al cargar imágenes: ${response.statusCode}');
        _imagenesCargadas = false;
      }
    } catch (e) {
      debugPrint('⚠️ CategoriaService: Error al obtener imágenes: $e');
      _imagenesCargadas = false;
    }
  }

  /// Obtener todas las categorías
  static Future<List<Categoria>> getCategorias() async {
    try {
      final response = await ApiService.get(ApiConfig.categoriasEndpoint);

      if (response.statusCode == 200) {
        final List<dynamic> categoriasJson = jsonDecode(response.body);
        debugPrint('🔵 CategoriaService: JSON recibido: ${categoriasJson.length} categorías');
        debugPrint('🔵 CategoriaService: Primer elemento JSON: ${categoriasJson.isNotEmpty ? categoriasJson[0] : "vacío"}');
        
        final categorias = categoriasJson
            .map((json) {
              debugPrint('🔵 CategoriaService: Parseando categoría: $json');
              return Categoria.fromJson(json as Map<String, dynamic>);
            })
            .toList();
        
        debugPrint('✅ CategoriaService: ${categorias.length} categorías parseadas exitosamente');
        for (var cat in categorias) {
          debugPrint('  - ${cat.nombre} (id: ${cat.id}, idImagen: ${cat.idImagen})');
        }
        
        // Cargar imágenes una sola vez si no están cargadas
        try {
          await cargarImagenes();
        } catch (e) {
          debugPrint('⚠️ CategoriaService: Error al cargar imágenes, continuando sin imágenes: $e');
        }
        
        return categorias;
      } else {
        throw Exception(ApiService.handleError(response));
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// Obtener categoría por ID
  static Future<Categoria> getCategoriaById(int id) async {
    try {
      final response =
          await ApiService.get('${ApiConfig.categoriasEndpoint}/$id');

      if (response.statusCode == 200) {
        final categoriaJson = jsonDecode(response.body);
        return Categoria.fromJson(categoriaJson as Map<String, dynamic>);
      } else {
        throw Exception(ApiService.handleError(response));
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}

