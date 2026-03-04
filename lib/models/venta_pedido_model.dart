import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'usuario_model.dart';
import 'estado_model.dart';

/// Modelo de Venta/Pedido
class VentaPedido {
  final int? id;
  final int? usuarioId;
  final Usuario? usuario;
  final int? estadoId;
  final Estado? estado;
  final DateTime? fechaCreacion;
  final DateTime? fechaEntrega;
  final double subtotal;
  final double envio;
  final double total;
  final String? direccionEntrega;
  final String? ciudadEntrega;
  final String? departamentoEntrega;
  final String? metodoPago; // 'efectivo' o 'transferencia'
  // Campos adicionales para uso interno (no se envían a la API)
  final String? tipoEntrega; // 'recoger' o 'domicilio'
  final String? telefonoContacto;
  final String? observaciones;
  final String? comprobanteUrl;

  VentaPedido({
    this.id,
    this.usuarioId,
    this.usuario,
    this.estadoId,
    this.estado,
    this.fechaCreacion,
    this.fechaEntrega,
    this.subtotal = 0.0,
    this.envio = 0.0,
    required this.total,
    this.direccionEntrega,
    this.ciudadEntrega,
    this.departamentoEntrega,
    this.metodoPago,
    // Campos adicionales para uso interno
    this.tipoEntrega,
    this.telefonoContacto,
    this.observaciones,
    this.comprobanteUrl,
  });

  factory VentaPedido.fromJson(Map<String, dynamic> json) {
    // Mapear campos con fallbacks para PascalCase
    final int? id = json['id'] as int? ?? json['Id'] as int?;
    final int? usuarioId = json['usuarioId'] as int? ?? json['UsuarioId'] as int?;
    
    final usuarioJson = json['usuario'] ?? json['Usuario'];
    final Usuario? usuario = usuarioJson != null
        ? Usuario.fromJson(usuarioJson as Map<String, dynamic>)
        : null;

    final int? estadoId = json['estadoId'] as int? ?? json['EstadoId'] as int?;
    
    final estadoJson = json['estado'] ?? json['Estado'];
    final Estado? estado = estadoJson != null
        ? Estado.fromJson(estadoJson as Map<String, dynamic>)
        : null;

    final String? fechaCreacionRaw = json['fechaCreacion'] as String? ?? 
                                     json['FechaCreacion'] as String? ??
                                     json['fechaPedido'] as String? ??
                                     json['FechaPedido'] as String?;
    
    final DateTime? fechaCreacion = fechaCreacionRaw != null
        ? DateTime.parse(fechaCreacionRaw)
        : null;

    final String? fechaEntregaRaw = json['fechaEntrega'] as String? ?? 
                                     json['FechaEntrega'] as String?;
                                     
    final DateTime? fechaEntrega = fechaEntregaRaw != null
        ? DateTime.parse(fechaEntregaRaw)
        : null;

    final double subtotal = (json['subtotal'] as num? ?? json['Subtotal'] as num?)?.toDouble() ?? 0.0;
    final double envio = (json['envio'] as num? ?? json['Envio'] as num?)?.toDouble() ?? 0.0;
    final double total = (json['total'] as num? ?? json['Total'] as num?)?.toDouble() ?? 0.0;

    return VentaPedido(
      id: id,
      usuarioId: usuarioId,
      usuario: usuario,
      estadoId: estadoId,
      estado: estado,
      fechaCreacion: fechaCreacion,
      fechaEntrega: fechaEntrega,
      subtotal: subtotal,
      envio: envio,
      total: total,
      direccionEntrega: json['direccionEntrega'] as String? ?? json['DireccionEntrega'] as String?,
      ciudadEntrega: json['ciudadEntrega'] as String? ?? json['CiudadEntrega'] as String?,
      departamentoEntrega: json['departamentoEntrega'] as String? ?? json['DepartamentoEntrega'] as String?,
      metodoPago: json['metodoPago'] as String? ?? json['MetodoPago'] as String?,
      tipoEntrega: json['tipoEntrega'] as String? ?? json['TipoEntrega'] as String?,
      telefonoContacto: json['telefonoContacto'] as String? ?? json['TelefonoContacto'] as String?,
      observaciones: json['observaciones'] as String? ?? json['Observaciones'] as String?,
      comprobanteUrl: json['comprobanteUrl'] as String? ?? json['ComprobanteUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    // Formato exacto que espera la API
    // Las fechas deben estar en formato ISO 8601 con Z (UTC)
    String formatFecha(DateTime? fecha) {
      if (fecha == null) return DateTime.now().toUtc().toIso8601String();
      final utc = fecha.toUtc();
      final iso = utc.toIso8601String();
      return iso.endsWith('Z') ? iso : '${iso}Z';
    }
    
    final fechaCreacionStr = formatFecha(fechaCreacion);
    final fechaEntregaStr = formatFecha(fechaEntrega);
    
    // Validar campos requeridos
    if (usuarioId == null) {
      throw Exception('usuarioId es requerido para crear un pedido');
    }
    if (estadoId == null) {
      throw Exception('estadoId es requerido para crear un pedido');
    }
    
    // Algunos servidores ASP.NET Core no manejan bien los null en JSON
    // Enviar strings vacíos en lugar de null para campos opcionales de texto
    // y omitir campos que son null si el servidor no los acepta
    final json = <String, dynamic>{
      'id': id ?? 0,
      'usuarioId': usuarioId,
      'estadoId': estadoId,
      'fechaCreacion': fechaCreacionStr,
      'fechaEntrega': fechaEntregaStr,
      'subtotal': subtotal,
      'envio': envio,
      'total': total,
    };
    
    // Agregar campos opcionales solo si tienen valor, o como string vacío si el servidor lo requiere
    // Intentar primero sin estos campos, y si falla, enviarlos como string vacío
    if (metodoPago != null && metodoPago!.isNotEmpty) {
      json['metodoPago'] = metodoPago;
    }
    
    if (direccionEntrega != null && direccionEntrega!.isNotEmpty) {
      json['direccionEntrega'] = direccionEntrega;
    }
    
    if (ciudadEntrega != null && ciudadEntrega!.isNotEmpty) {
      json['ciudadEntrega'] = ciudadEntrega;
    }
    
    if (departamentoEntrega != null && departamentoEntrega!.isNotEmpty) {
      json['departamentoEntrega'] = departamentoEntrega;
    }
    
    // Log para debugging
    debugPrint('🔵 VentaPedido.toJson(): ${jsonEncode(json)}');
    
    return json;
  }

  VentaPedido copyWith({
    int? id,
    int? usuarioId,
    Usuario? usuario,
    int? estadoId,
    Estado? estado,
    DateTime? fechaCreacion,
    DateTime? fechaEntrega,
    double? subtotal,
    double? envio,
    double? total,
    String? direccionEntrega,
    String? ciudadEntrega,
    String? departamentoEntrega,
    String? metodoPago,
    String? tipoEntrega,
    String? telefonoContacto,
    String? observaciones,
    String? comprobanteUrl,
  }) {
    return VentaPedido(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      usuario: usuario ?? this.usuario,
      estadoId: estadoId ?? this.estadoId,
      estado: estado ?? this.estado,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaEntrega: fechaEntrega ?? this.fechaEntrega,
      subtotal: subtotal ?? this.subtotal,
      envio: envio ?? this.envio,
      total: total ?? this.total,
      direccionEntrega: direccionEntrega ?? this.direccionEntrega,
      ciudadEntrega: ciudadEntrega ?? this.ciudadEntrega,
      departamentoEntrega: departamentoEntrega ?? this.departamentoEntrega,
      metodoPago: metodoPago ?? this.metodoPago,
      tipoEntrega: tipoEntrega ?? this.tipoEntrega,
      telefonoContacto: telefonoContacto ?? this.telefonoContacto,
      observaciones: observaciones ?? this.observaciones,
      comprobanteUrl: comprobanteUrl ?? this.comprobanteUrl,
    );
  }
}

