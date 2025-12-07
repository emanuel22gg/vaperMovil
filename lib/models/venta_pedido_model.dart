import 'usuario_model.dart';
import 'estado_model.dart';

/// Modelo de Venta/Pedido
class VentaPedido {
  final int? id;
  final int? usuarioId;
  final Usuario? usuario;
  final int? estadoId;
  final Estado? estado;
  final DateTime? fechaPedido;
  final double total;
  final String? direccionEntrega;
  final String? telefonoContacto;
  final String? observaciones;

  VentaPedido({
    this.id,
    this.usuarioId,
    this.usuario,
    this.estadoId,
    this.estado,
    this.fechaPedido,
    required this.total,
    this.direccionEntrega,
    this.telefonoContacto,
    this.observaciones,
  });

  factory VentaPedido.fromJson(Map<String, dynamic> json) {
    return VentaPedido(
      id: json['id'] as int?,
      usuarioId: json['usuarioId'] as int?,
      usuario: json['usuario'] != null
          ? Usuario.fromJson(json['usuario'] as Map<String, dynamic>)
          : null,
      estadoId: json['estadoId'] as int?,
      estado: json['estado'] != null
          ? Estado.fromJson(json['estado'] as Map<String, dynamic>)
          : null,
      fechaPedido: json['fechaPedido'] != null
          ? DateTime.parse(json['fechaPedido'] as String)
          : null,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      direccionEntrega: json['direccionEntrega'] as String?,
      telefonoContacto: json['telefonoContacto'] as String?,
      observaciones: json['observaciones'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (usuarioId != null) 'usuarioId': usuarioId,
      if (estadoId != null) 'estadoId': estadoId,
      if (fechaPedido != null)
        'fechaPedido': fechaPedido!.toIso8601String(),
      'total': total,
      if (direccionEntrega != null) 'direccionEntrega': direccionEntrega,
      if (telefonoContacto != null) 'telefonoContacto': telefonoContacto,
      if (observaciones != null) 'observaciones': observaciones,
    };
  }

  VentaPedido copyWith({
    int? id,
    int? usuarioId,
    Usuario? usuario,
    int? estadoId,
    Estado? estado,
    DateTime? fechaPedido,
    double? total,
    String? direccionEntrega,
    String? telefonoContacto,
    String? observaciones,
  }) {
    return VentaPedido(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      usuario: usuario ?? this.usuario,
      estadoId: estadoId ?? this.estadoId,
      estado: estado ?? this.estado,
      fechaPedido: fechaPedido ?? this.fechaPedido,
      total: total ?? this.total,
      direccionEntrega: direccionEntrega ?? this.direccionEntrega,
      telefonoContacto: telefonoContacto ?? this.telefonoContacto,
      observaciones: observaciones ?? this.observaciones,
    );
  }
}

