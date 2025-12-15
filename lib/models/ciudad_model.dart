/// Modelo de Ciudad
class Ciudad {
  final int? id;
  final String nombre;
  final int? departamentoId;
  final String? codigo;

  Ciudad({
    this.id,
    required this.nombre,
    this.departamentoId,
    this.codigo,
  });

  factory Ciudad.fromJson(Map<String, dynamic> json) {
    return Ciudad(
      id: json['id'] as int?,
      nombre: json['nombre'] as String? ?? json['name'] as String? ?? '',
      departamentoId: json['departamentoId'] as int? ?? json['departamento_id'] as int?,
      codigo: json['codigo'] as String? ?? json['code'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      if (departamentoId != null) 'departamentoId': departamentoId,
      if (codigo != null) 'codigo': codigo,
    };
  }
}




