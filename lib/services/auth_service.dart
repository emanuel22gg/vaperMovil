import 'dart:convert';
import '../config/api_config.dart';
import '../models/usuario_model.dart';
import 'api_service.dart';

/// Servicio de autenticación
class AuthService {
  /// Login de usuario
  static Future<Usuario> login(String email, String password) async {
    try {
      // Obtener todos los usuarios y buscar coincidencia
      final response = await ApiService.get(ApiConfig.usuariosEndpoint);

      if (response.statusCode == 200) {
        final List<dynamic> usuariosJson = jsonDecode(response.body);
        final usuarios = usuariosJson
            .map((json) => Usuario.fromJson(json as Map<String, dynamic>))
            .toList();

        // Buscar usuario por email y contraseña EXACTAMENTE como vienen de la API.
        //
        // Importante:
        // - Si la API devuelve "contraseña": null, entonces u.password será null
        //   y aquí se considerará como cadena vacía ('').
        //   Eso significa que el usuario solo podrá iniciar sesión dejando
        //   el campo de contraseña vacío.
        final usuario = usuarios.firstWhere(
          (u) {
            if (u.email.toLowerCase() != email.toLowerCase()) {
              return false;
            }

            final apiPassword = u.password ?? '';
            return apiPassword == password;
          },
          orElse: () => throw Exception('Credenciales incorrectas'),
        );

        return usuario;
      } else {
        throw Exception(ApiService.handleError(response));
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// Actualizar contraseña
  static Future<bool> changePassword(
    int userId,
    String currentPassword,
    String newPassword,
  ) async {
    try {
      // Obtener usuario actual
      final getResponse = await ApiService.get(
        '${ApiConfig.usuariosEndpoint}/$userId',
      );

      if (getResponse.statusCode != 200) {
        throw Exception('Usuario no encontrado');
      }

      final usuarioJson = jsonDecode(getResponse.body);
      final usuario = Usuario.fromJson(usuarioJson as Map<String, dynamic>);

      // Verificar contraseña actual
      if (usuario.password != currentPassword) {
        throw Exception('La contraseña actual es incorrecta');
      }

      // Actualizar contraseña
      final updateData = usuario.toJson();
      updateData['password'] = newPassword;

      final updateResponse = await ApiService.put(
        '${ApiConfig.usuariosEndpoint}/$userId',
        updateData,
      );

      if (updateResponse.statusCode == 200 || updateResponse.statusCode == 204) {
        return true;
      } else {
        throw Exception(ApiService.handleError(updateResponse));
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// Obtener usuario por ID
  static Future<Usuario> getUsuarioById(int id) async {
    try {
      final response = await ApiService.get('${ApiConfig.usuariosEndpoint}/$id');

      if (response.statusCode == 200) {
        final usuarioJson = jsonDecode(response.body);
        return Usuario.fromJson(usuarioJson as Map<String, dynamic>);
      } else {
        throw Exception(ApiService.handleError(response));
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// Obtener todos los usuarios (para admin)
  static Future<List<Usuario>> getAllUsuarios() async {
    try {
      final response = await ApiService.get(ApiConfig.usuariosEndpoint);

      if (response.statusCode == 200) {
        final List<dynamic> usuariosJson = jsonDecode(response.body);
        return usuariosJson
            .map((json) => Usuario.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(ApiService.handleError(response));
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}

