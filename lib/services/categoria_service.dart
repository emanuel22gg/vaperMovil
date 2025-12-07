import 'dart:convert';
import '../config/api_config.dart';
import '../models/categoria_model.dart';
import 'api_service.dart';

/// Servicio de Categorías
class CategoriaService {
  /// Obtener todas las categorías
  static Future<List<Categoria>> getCategorias() async {
    try {
      final response = await ApiService.get(ApiConfig.categoriasEndpoint);

      if (response.statusCode == 200) {
        final List<dynamic> categoriasJson = jsonDecode(response.body);
        return categoriasJson
            .map((json) => Categoria.fromJson(json as Map<String, dynamic>))
            .toList();
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

