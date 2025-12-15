/// Modelo de Departamento
class Departamento {
  final int? id;
  final String nombre;
  final String? codigo;

  Departamento({
    this.id,
    required this.nombre,
    this.codigo,
  });

  factory Departamento.fromJson(Map<String, dynamic> json) {
    return Departamento(
      id: json['id'] as int?,
      nombre: json['nombre'] as String? ?? json['name'] as String? ?? '',
      codigo: json['codigo'] as String? ?? json['code'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      if (codigo != null) 'codigo': codigo,
    };
  }
}




