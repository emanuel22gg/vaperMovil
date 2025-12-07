import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/usuario_model.dart';
import '../services/auth_service.dart';

/// Provider de autenticación
class AuthProvider extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Usuario? _currentUser;
  bool _isLoading = false;
  String? _error;

  Usuario? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.rol == 'Admin';
  bool get isCliente => _currentUser?.rol == 'Cliente';

  /// Inicializar sesión guardada
  Future<void> init() async {
    try {
      _isLoading = true;
      notifyListeners();

      final userIdStr = await _storage.read(key: 'user_id');
      if (userIdStr != null) {
        final userId = int.parse(userIdStr);
        _currentUser = await AuthService.getUsuarioById(userId);
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Login
  Future<bool> login(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _currentUser = await AuthService.login(email, password);

      // Guardar sesión
      if (_currentUser?.id != null) {
        await _storage.write(
          key: 'user_id',
          value: _currentUser!.id.toString(),
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Cambiar contraseña
  Future<bool> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      if (_currentUser?.id == null) {
        throw Exception('Usuario no autenticado');
      }

      _isLoading = true;
      _error = null;
      notifyListeners();

      final success = await AuthService.changePassword(
        _currentUser!.id!,
        currentPassword,
        newPassword,
      );

      if (success) {
        // Actualizar usuario
        _currentUser = await AuthService.getUsuarioById(_currentUser!.id!);
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    _currentUser = null;
    _error = null;
    await _storage.delete(key: 'user_id');
    notifyListeners();
  }

  /// Limpiar error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}

