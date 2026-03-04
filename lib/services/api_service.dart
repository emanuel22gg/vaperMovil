import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// Servicio base para llamadas HTTP a la API
class ApiService {
  static final http.Client _client = http.Client();

  static Future<Map<String, String>> _getHeaders(String? token) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Connection': 'keep-alive', // Sugerir mantener la conexión abierta
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
    bool retryIfSemaphoreTimeout = true, // Permitir un reintento por defecto
  }) async {
    try {
      var uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      debugPrint('🌐 ApiService GET: $uri');
      
      final headers = await _getHeaders(token);
      
      final response = await _client.get(
        uri,
        headers: headers,
      ).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw Exception('TimeoutException');
        },
      );

      debugPrint('🌐 ApiService Response Status: ${response.statusCode}');
      return response;
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      
      // Si es un error de semáforo de Windows (121) y tenemos permitido reintentar
      if (retryIfSemaphoreTimeout && (errorStr.contains('semaphore') || errorStr.contains('121'))) {
        debugPrint('⚠️ ApiService: Error de semáforo detectado. Reintentando en 1.5s...');
        await Future.delayed(const Duration(milliseconds: 1500));
        return get(endpoint, token: token, queryParams: queryParams, retryIfSemaphoreTimeout: false);
      }

      debugPrint('❌ ApiService: Error de conexión: $e');
      
      String mensajeError;
      if (errorStr.contains('timeout') || errorStr.contains('tiempo de espera')) {
        mensajeError = 'El servidor no responde (Tiempo de espera agotado). Por favor, intenta de nuevo.';
      } else if (errorStr.contains('semaphore') || errorStr.contains('121')) {
        mensajeError = 'Error de red en Windows (Semaphore timeout). Prueba reintentar en unos segundos.';
      } else if (errorStr.contains('socketexception') || errorStr.contains('connection failed')) {
        mensajeError = 'No se pudo conectar con el servidor. Verifica tu internet.';
      } else {
        mensajeError = 'Error de comunicación: $e';
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
      
      final headers = await _getHeaders(token);
      final bodyStr = jsonEncode(body);

      final response = await _client.post(
        uri,
        headers: headers,
        body: bodyStr,
      ).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw Exception('Tiempo de espera agotado.');
        },
      );

      return response;
    } catch (e) {
      debugPrint('❌ ApiService POST Error: $e');
      throw Exception('Error al enviar datos: $e');
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
      
      final headers = await _getHeaders(token);
      final bodyStr = jsonEncode(body);

      final response = await _client.put(
        uri,
        headers: headers,
        body: bodyStr,
      ).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw Exception('Tiempo de espera agotado.');
        },
      );

      return response;
    } catch (e) {
      debugPrint('❌ ApiService PUT Error: $e');
      throw Exception('Error al actualizar datos: $e');
    }
  }

  /// DELETE request
  static Future<http.Response> delete(
    String endpoint, {
    String? token,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      debugPrint('🌐 ApiService DELETE: $uri');
      
      final headers = await _getHeaders(token);

      final response = await _client.delete(
        uri,
        headers: headers,
      ).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw Exception('Tiempo de espera agotado.');
        },
      );

      return response;
    } catch (e) {
      debugPrint('❌ ApiService DELETE Error: $e');
      throw Exception('Error al eliminar datos: $e');
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

