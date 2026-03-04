import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Servicio base para llamadas HTTP a la API
class ApiService {
  static Future<Map<String, String>> _getHeaders(String? token) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// GET request
  static Future<http.Response> get(
    String endpoint, {
    String? token,
    Map<String, String>? queryParams,
  }) async {
    try {
      var uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      debugPrint('🌐 ApiService GET: $uri');
      debugPrint('🌐 ApiService Headers: ${await _getHeaders(token)}');

      final response = await http.get(
        uri,
        headers: await _getHeaders(token),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          debugPrint('❌ ApiService: Timeout al llamar a $uri');
          throw Exception('Tiempo de espera agotado. Verifica tu conexión a internet.');
        },
      );

      debugPrint('🌐 ApiService Response Status: ${response.statusCode}');
      debugPrint('🌐 ApiService Response Body (primeros 500 chars): ${response.body.length > 500 ? response.body.substring(0, 500) + "..." : response.body}');

      return response;
    } catch (e, stackTrace) {
      debugPrint('❌ ApiService: Error de conexión: $e');
      debugPrint('❌ ApiService: Stack trace: $stackTrace');
      
      // Manejar diferentes tipos de errores de conexión
      String mensajeError;
      if (e.toString().contains('TimeoutException') || 
          e.toString().contains('timeout') ||
          e.toString().contains('Se agotó el tiempo de espera')) {
        mensajeError = 'Tiempo de espera agotado. El servidor no responde. Verifica tu conexión a internet.';
      } else if (e.toString().contains('SocketException') || 
                 e.toString().contains('Failed host lookup')) {
        mensajeError = 'Error de conexión. Verifica tu conexión a internet y que el servidor esté disponible.';
      } else {
        mensajeError = 'Error de conexión: ${e.toString()}';
      }
      
      throw Exception(mensajeError);
    }
  }

  /// POST request
  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    try {
      var uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      
      debugPrint('🌐 ApiService POST: $uri');
      debugPrint('🌐 ApiService Body: ${jsonEncode(body)}');
      debugPrint('🌐 ApiService Headers: ${await _getHeaders(token)}');

      final response = await http.post(
        uri,
        headers: await _getHeaders(token),
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          debugPrint('❌ ApiService: Timeout al llamar a $uri');
          throw Exception('Tiempo de espera agotado. Verifica tu conexión a internet.');
        },
      );

      debugPrint('🌐 ApiService Response Status: ${response.statusCode}');
      debugPrint('🌐 ApiService Response Body (primeros 500 chars): ${response.body.length > 500 ? response.body.substring(0, 500) + "..." : response.body}');

      return response;
    } catch (e, stackTrace) {
      debugPrint('❌ ApiService POST: Error de conexión: $e');
      debugPrint('❌ ApiService POST: Stack trace: $stackTrace');
      
      // Manejar diferentes tipos de errores de conexión
      String mensajeError;
      if (e.toString().contains('TimeoutException') || 
          e.toString().contains('timeout') ||
          e.toString().contains('Se agotó el tiempo de espera')) {
        mensajeError = 'Tiempo de espera agotado. El servidor no responde. Verifica tu conexión a internet.';
      } else if (e.toString().contains('SocketException') || 
                 e.toString().contains('Failed host lookup')) {
        mensajeError = 'Error de conexión. Verifica tu conexión a internet y que el servidor esté disponible.';
      } else {
        mensajeError = 'Error de conexión: ${e.toString()}';
      }
      
      throw Exception(mensajeError);
    }
  }

  /// PUT request
  static Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      debugPrint('🌐 ApiService PUT: $uri');
      debugPrint('🌐 ApiService Body: ${jsonEncode(body)}');
      debugPrint('🌐 ApiService Headers: ${await _getHeaders(token)}');

      final response = await http.put(
        uri,
        headers: await _getHeaders(token),
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          debugPrint('❌ ApiService: Timeout al llamar a $uri');
          throw Exception('Tiempo de espera agotado. Verifica tu conexión a internet.');
        },
      );

      debugPrint('🌐 ApiService Response Status: ${response.statusCode}');
      debugPrint('🌐 ApiService Response Body (primeros 500 chars): ${response.body.length > 500 ? response.body.substring(0, 500) + "..." : response.body}');

      return response;
    } catch (e, stackTrace) {
      debugPrint('❌ ApiService PUT: Error de conexión: $e');
      debugPrint('❌ ApiService PUT: Stack trace: $stackTrace');
      
      // Manejar diferentes tipos de errores de conexión
      String mensajeError;
      if (e.toString().contains('TimeoutException') || 
          e.toString().contains('timeout') ||
          e.toString().contains('Se agotó el tiempo de espera')) {
        mensajeError = 'Tiempo de espera agotado. El servidor no responde. Verifica tu conexión a internet.';
      } else if (e.toString().contains('SocketException') || 
                 e.toString().contains('Failed host lookup')) {
        mensajeError = 'Error de conexión. Verifica tu conexión a internet y que el servidor esté disponible.';
      } else {
        mensajeError = 'Error de conexión: ${e.toString()}';
      }
      
      throw Exception(mensajeError);
    }
  }

  /// DELETE request
  static Future<http.Response> delete(
    String endpoint, {
    String? token,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: await _getHeaders(token),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Tiempo de espera agotado. Verifica tu conexión a internet.');
        },
      );

      return response;
    } catch (e) {
      throw Exception('Error de conexión: ${e.toString()}');
    }
  }

  /// Manejar errores HTTP
  static String handleError(http.Response response) {
    switch (response.statusCode) {
      case 200:
      case 201:
        return '';
      case 400:
        return 'Solicitud incorrecta. Verifica los datos ingresados.';
      case 401:
        return 'No autorizado. Por favor, inicia sesión nuevamente.';
      case 404:
        return 'Recurso no encontrado.';
      case 500:
        return 'Error del servidor. Intenta más tarde.';
      default:
        return 'Error desconocido (${response.statusCode}).';
    }
  }
}

