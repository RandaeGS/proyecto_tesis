import 'package:flutter/material.dart';

import '../entities/center.dart' as app_center;
import '../entities/user.dart';
import '../services/user_service.dart';
import '../services/center_service.dart';
import 'auth_services/auth_service.dart';

/// Provider para manejar operaciones y estado de usuarios
class UserProvider with ChangeNotifier {
  final UserService _userService = UserService();
  final CenterService _centerService = CenterService();
  final AuthService _authService = AuthService();

  List<User> _users = [];
  bool _isLoading = false;
  String _errorMessage = '';
  app_center.Center? _currentCenter;

  // Getters
  List<User> get users => _users;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  app_center.Center? get currentCenter => _currentCenter;

  /// Maneja errores de autorización
  void _handleAuthError(String error) async {
    if (error.contains('No autorizado') || error.contains('401') || error.contains('403')) {
      debugPrint('Error de autorización detectado: $error');
      // Si es un error de autorización, notificamos para que se vuelva a iniciar sesión
      await _authService.logout();
      _errorMessage = 'Su sesión ha expirado. Por favor, inicie sesión nuevamente.';
    } else {
      _errorMessage = error;
    }
  }

  /// Obtiene el ID del centro del usuario actual directamente del backend
  Future<int?> getCurrentUserCenterId(BuildContext context) async {
    try {
      // Obtener el usuario actual para usar su email
      final user = await _authService.getSavedUser();
      if (user == null) {
        debugPrint('No hay usuario autenticado');
        return null;
      }

      // Hacer petición al endpoint para obtener información completa del usuario
      debugPrint('Consultando información del usuario por email: ${user.email}');
      final userData = await _userService.getUserByEmail(user.email);

      // Verificar si tiene centros asignados
      if (userData.containsKey('centers') &&
          userData['centers'] is List &&
          (userData['centers'] as List).isNotEmpty) {

        // Obtener el primer centro (podría implementarse una selección)
        final centerData = userData['centers'][0];
        final centerId = centerData['id'];

        debugPrint('Centro obtenido desde API: ${centerData['name']} (ID: $centerId)');

        // Actualizar el centro actual en el provider
        if (_currentCenter == null || _currentCenter!.id != centerId) {
          _currentCenter = app_center.Center.fromJson(centerData);
        }

        return centerId;
      }

      debugPrint('El usuario no tiene centros asignados según la API');
      return null;
    } catch (e) {
      debugPrint('Error al obtener centerId desde API: $e');

      // Si falla la petición al API, intentar con datos guardados como fallback
      try {
        final center = await _authService.getSavedCenter();
        if (center != null) {
          debugPrint('Usando centro guardado localmente como fallback: ${center.id}');
          return center.id;
        }
      } catch (fallbackError) {
        debugPrint('Error al obtener centro guardado localmente: $fallbackError');
      }

      return null;
    }
  }

  /// Carga los usuarios de un centro específico
  Future<void> loadUsers(int centerId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      debugPrint('Iniciando carga de usuarios para centro ID: $centerId');

      // Primero obtenemos los datos del centro
      try {
        _currentCenter = await _centerService.getCenterById(centerId);
        debugPrint('Centro obtenido: ${_currentCenter?.name} (ID: ${_currentCenter?.id})');
      } catch (e) {
        debugPrint('Error al obtener centro: $e');
        throw 'No se pudo obtener información del centro: $e';
      }

      // Luego obtenemos los usuarios asociados a ese centro
      try {
        final List<User> centerUsers = await _centerService.getCenterUsers(centerId);
        debugPrint('Usuarios obtenidos: ${centerUsers.length}');
        _users = centerUsers;
      } catch (e) {
        debugPrint('Error al obtener usuarios: $e');
        throw 'No se pudieron obtener los usuarios del centro: $e';
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error en loadUsers: $e');
      _isLoading = false;
      _handleAuthError(e.toString());
      notifyListeners();
    }
  }

  /// Busca usuarios con un criterio específico
  Future<void> searchUsers(int centerId, String query) async {
    if (query.isEmpty) {
      await loadUsers(centerId);
      return;
    }

    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // Buscar usuarios específicos
      final usersData = await _userService.searchUsers(query);
      _users = usersData;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _handleAuthError(e.toString());
      notifyListeners();
    }
  }

  /// Crea un nuevo usuario en el centro especificado
  Future<bool> createUser({
    required int centerId,
    required String email,
    required String password,
    required String name,
    required bool isSuperuser,
    required bool isStaff,
  }) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // Crear usuario asignándole el centro directamente
      final user = await _userService.createUser(
        email: email,
        password: password,
        name: name,
        isSuperuser: isSuperuser,
        isStaff: isStaff,
        centerId: centerId,
      );

      // Como respaldo, intentar asignar al centro
      // (por si el backend no procesó la asignación)
      try {
        await _userService.assignUserToCenter(
          userId: user.email,
          centerId: centerId,
        );
        debugPrint('Usuario asignado al centro mediante llamada adicional');
      } catch (assignError) {
        debugPrint('Error o redundancia al asignar usuario al centro: $assignError');
        // No hacemos fallar la operación si esto falla, ya que podría ser redundante
      }

      // Recargar la lista de usuarios
      await loadUsers(centerId);
      return true;
    } catch (e) {
      _isLoading = false;
      _handleAuthError(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Actualiza un usuario existente
  Future<bool> updateUser({
    required int centerId,
    required String userId,
    required String name,
    required bool isSuperuser,
    required bool isStaff,
  }) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // Actualizar el usuario
      await _userService.updateUser(
        userId: userId,
        name: name,
        isSuperuser: isSuperuser,
        isStaff: isStaff,
      );

      // Recargar la lista de usuarios
      await loadUsers(centerId);
      return true;
    } catch (e) {
      _isLoading = false;
      _handleAuthError(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Elimina un usuario
  Future<bool> deleteUser(int centerId, String userId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // Eliminar el usuario
      await _userService.deleteUser(userId);

      // Recargar la lista de usuarios
      await loadUsers(centerId);
      return true;
    } catch (e) {
      _isLoading = false;
      _handleAuthError(e.toString());
      notifyListeners();
      return false;
    }
  }

  /// Restablece la contraseña de un usuario
  Future<bool> resetPassword({
    required String userId,
    required String newPassword,
  }) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // Restablecer la contraseña
      await _userService.resetPassword(
        userId: userId,
        newPassword: newPassword,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _handleAuthError(e.toString());
      notifyListeners();
      return false;
    }
  }
}