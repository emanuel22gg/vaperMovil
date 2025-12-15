import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/departamento_model.dart';
import '../models/ciudad_model.dart';
import 'api_service.dart';

/// Servicio para obtener departamentos y ciudades
class UbicacionService {
  // Cache para evitar múltiples llamadas
  static List<Departamento>? _departamentosCache;
  static Map<int, List<Ciudad>> _ciudadesCache = {};

  /// Obtener todos los departamentos
  static Future<List<Departamento>> getDepartamentos() async {
    try {
      // Si ya están en caché, retornarlos
      if (_departamentosCache != null) {
        return _departamentosCache!;
      }

      debugPrint('🔵 UbicacionService: Obteniendo departamentos...');
      
      // Obtener departamentos desde la API
      final response = await ApiService.get(ApiConfig.departamentosEndpoint);

      if (response.statusCode == 200) {
        final List<dynamic> departamentosJson = jsonDecode(response.body);
        _departamentosCache = departamentosJson
            .map((json) => Departamento.fromJson(json as Map<String, dynamic>))
            .toList();
        
        debugPrint('✅ UbicacionService: ${_departamentosCache!.length} departamentos cargados');
        return _departamentosCache!;
      } else {
        // Fallback a lista estática si la API falla
        debugPrint('⚠️ UbicacionService: Error al obtener departamentos, usando lista estática');
        return _getDepartamentosEstaticos();
      }
    } catch (e) {
      debugPrint('⚠️ UbicacionService: Error al obtener departamentos: $e');
      // Fallback a lista estática
      return _getDepartamentosEstaticos();
    }
  }

  /// Obtener ciudades por departamento
  static Future<List<Ciudad>> getCiudadesPorDepartamento(int departamentoId) async {
    try {
      // Si ya están en caché, retornarlas
      if (_ciudadesCache.containsKey(departamentoId)) {
        return _ciudadesCache[departamentoId]!;
      }

      debugPrint('🔵 UbicacionService: Obteniendo ciudades para departamento $departamentoId...');
      
      // Obtener ciudades desde la API
      final response = await ApiService.get(
        ApiConfig.ciudadesEndpoint,
        queryParams: {'departamentoId': departamentoId.toString()},
      );

      if (response.statusCode == 200) {
        final List<dynamic> ciudadesJson = jsonDecode(response.body);
        final ciudades = ciudadesJson
            .map((json) => Ciudad.fromJson(json as Map<String, dynamic>))
            .toList();
        
        _ciudadesCache[departamentoId] = ciudades;
        debugPrint('✅ UbicacionService: ${ciudades.length} ciudades cargadas');
        return ciudades;
      } else {
        // Fallback a lista estática si la API falla
        debugPrint('⚠️ UbicacionService: Error al obtener ciudades, usando lista estática');
        return _getCiudadesEstaticas(departamentoId);
      }
    } catch (e) {
      debugPrint('⚠️ UbicacionService: Error al obtener ciudades: $e');
      // Fallback a lista estática
      return _getCiudadesEstaticas(departamentoId);
    }
  }

  /// Lista estática de departamentos de Colombia (fallback)
  static List<Departamento> _getDepartamentosEstaticos() {
    return [
      Departamento(id: 1, nombre: 'Antioquia', codigo: 'ANT'),
      Departamento(id: 2, nombre: 'Atlántico', codigo: 'ATL'),
      Departamento(id: 3, nombre: 'Bogotá D.C.', codigo: 'DC'),
      Departamento(id: 4, nombre: 'Bolívar', codigo: 'BOL'),
      Departamento(id: 5, nombre: 'Boyacá', codigo: 'BOY'),
      Departamento(id: 6, nombre: 'Caldas', codigo: 'CAL'),
      Departamento(id: 7, nombre: 'Caquetá', codigo: 'CAQ'),
      Departamento(id: 8, nombre: 'Cauca', codigo: 'CAU'),
      Departamento(id: 9, nombre: 'Cesar', codigo: 'CES'),
      Departamento(id: 10, nombre: 'Córdoba', codigo: 'COR'),
      Departamento(id: 11, nombre: 'Cundinamarca', codigo: 'CUN'),
      Departamento(id: 12, nombre: 'Huila', codigo: 'HUI'),
      Departamento(id: 13, nombre: 'La Guajira', codigo: 'LAG'),
      Departamento(id: 14, nombre: 'Magdalena', codigo: 'MAG'),
      Departamento(id: 15, nombre: 'Meta', codigo: 'MET'),
      Departamento(id: 16, nombre: 'Nariño', codigo: 'NAR'),
      Departamento(id: 17, nombre: 'Norte de Santander', codigo: 'NSA'),
      Departamento(id: 18, nombre: 'Quindío', codigo: 'QUI'),
      Departamento(id: 19, nombre: 'Risaralda', codigo: 'RIS'),
      Departamento(id: 20, nombre: 'Santander', codigo: 'SAN'),
      Departamento(id: 21, nombre: 'Sucre', codigo: 'SUC'),
      Departamento(id: 22, nombre: 'Tolima', codigo: 'TOL'),
      Departamento(id: 23, nombre: 'Valle del Cauca', codigo: 'VAC'),
      // Agrega más departamentos según necesites
    ];
  }

  /// Lista estática de ciudades por departamento (fallback)
  static List<Ciudad> _getCiudadesEstaticas(int departamentoId) {
    final ciudadesPorDepartamento = {
      1: [ // Antioquia
        Ciudad(id: 1, nombre: 'Medellín', departamentoId: 1),
        Ciudad(id: 2, nombre: 'Bello', departamentoId: 1),
        Ciudad(id: 3, nombre: 'Itagüí', departamentoId: 1),
        Ciudad(id: 4, nombre: 'Envigado', departamentoId: 1),
        Ciudad(id: 5, nombre: 'Rionegro', departamentoId: 1),
      ],
      3: [ // Bogotá D.C.
        Ciudad(id: 6, nombre: 'Bogotá', departamentoId: 3),
      ],
      11: [ // Cundinamarca
        Ciudad(id: 7, nombre: 'Soacha', departamentoId: 11),
        Ciudad(id: 8, nombre: 'Facatativá', departamentoId: 11),
        Ciudad(id: 9, nombre: 'Chía', departamentoId: 11),
        Ciudad(id: 10, nombre: 'Zipaquirá', departamentoId: 11),
      ],
      23: [ // Valle del Cauca
        Ciudad(id: 11, nombre: 'Cali', departamentoId: 23),
        Ciudad(id: 12, nombre: 'Palmira', departamentoId: 23),
        Ciudad(id: 13, nombre: 'Buenaventura', departamentoId: 23),
      ],
      // Agrega más ciudades según necesites
    };

    return ciudadesPorDepartamento[departamentoId] ?? [];
  }

  /// Limpiar caché
  static void limpiarCache() {
    _departamentosCache = null;
    _ciudadesCache.clear();
  }
}

