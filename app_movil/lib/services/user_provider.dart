// lib/services/user_provider.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../entities/user.dart';
import '../entities/center.dart' as app_center;
import '../services/user_service.dart';
import '../services/center_service.dart';
import '../services/auth_services/auth_provider.dart';
import '../services/auth_services/auth_service.dart';

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

  // Método para manejar errores de autorización
  void _handleAuthError(String error) async {
    if (error.contains('No autorizado') || error.contains('401') || error.contains('403')) {
      debugPrint('Error de autorización detectado: $error');
      // Si es un error de autorización, podríamos intentar renovar el token
      try {
        // Implementar lógica de renovación de token si es necesario
        // Por ahora, simplemente notificamos para que se vuelva a iniciar sesión
        await _authService.clearAuthData();
        _errorMessage = 'Su sesión ha expirado. Por favor, inicie sesión nuevamente.';
      } catch (e) {
        _errorMessage = 'Error de autorización: $error';
      }
    } else {
      _errorMessage = error;
    }
  }

  // Método para obtener el ID del centro del usuario actual
  Future<int?> getCurrentUserCenterId(BuildContext context) async {
    try {
      // Obtenemos el provider de autenticación
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Si el usuario ya tiene un centro asignado, lo usamos
      if (authProvider.centerId != null) {
        debugPrint('Centro del usuario: ${authProvider.centerId}');
        return authProvider.centerId;
      }

      // Si no tienen un centro asignado pero tenemos acceso a su información
      // intentamos cargarlo desde las preferencias compartidas
      if (authProvider.user != null) {
        final centerData = await _authService.getSavedCenter();
        if (centerData != null) {
          final center = app_center.Center.fromJson(centerData);
          debugPrint('Centro cargado desde preferencias: ${center.id}');
          return center.id;
        }
      }

      // Como último recurso, intentamos obtener el primer centro (para administradores)
      if (authProvider.user?.isSuperuser == true) {
        try {
          final centers = await _centerService.getAllCenters();
          if (centers.isNotEmpty) {
            debugPrint('Primer centro disponible: ${centers[0].id}');
            return centers[0].id;
          }
        } catch (e) {
          debugPrint('Error al obtener centros: $e');
        }
      }

      debugPrint('No se pudo determinar el centro del usuario');
      return null;
    } catch (e) {
      debugPrint('Error al obtener centerId: $e');
      return null;
    }
  }

  // Método para cargar los usuarios del centro actual
  Future<void> loadUsers(int centerId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      debugPrint('Iniciando carga de usuarios para centro ID: $centerId');

      // Primero obtenemos los datos del centro
      try {
        _currentCenter = await _centerService.getCenterById(centerId.toString());
        debugPrint('Centro obtenido: ${_currentCenter?.name} (ID: ${_currentCenter?.id})');
      } catch (e) {
        debugPrint('Error al obtener centro: $e');
        throw 'No se pudo obtener información del centro: $e';
      }

      // Luego obtenemos los usuarios asociados a ese centro
      try {
        final List<User> centerUsers = await _centerService.getCenterUsers(centerId.toString());
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

  // Método para buscar usuarios dentro del centro
  Future<void> searchUsers(int centerId, String query) async {
    if (query.isEmpty) {
      await loadUsers(centerId);
      return;
    }

    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // Implementar búsqueda de usuarios específica del centro
      final usersData = await _userService.searchUsers(query);

      // Filtramos los usuarios que pertenecen al centro actual
      // Esto es en caso de que el backend no soporte filtrado combinado
      _users = usersData;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _handleAuthError(e.toString());
      notifyListeners();
    }
  }

  // Método para crear un usuario en el centro actual
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
      // Crear el usuario
      final user = await _userService.createUser(
        email: email,
        password: password,
        name: name,
        isSuperuser: isSuperuser,
        isStaff: isStaff,
      );

      // Asignar usuario al centro si fue creado exitosamente
      try {
        await _userService.assignUserToCenter(
          userId: user.email,
          centerId: centerId.toString(),
        );
      } catch (assignError) {
        debugPrint('Error al asignar usuario al centro: $assignError');
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

  // Método para actualizar un usuario
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

  // Método para eliminar un usuario
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

  // Método para restablecer la contraseña de un usuario
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
