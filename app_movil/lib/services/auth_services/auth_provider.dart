import 'package:flutter/material.dart';

import '../../entities/center.dart' as app_center;
import '../../entities/user.dart';
import '../core/storage_services.dart';
import 'auth_service.dart';

/// Provider para manejar el estado de autenticación
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();

  bool _isAuthenticated = false;
  bool _isInitialized = false;
  bool _isLoading = false;
  User? _user;
  String? _token;
  int? _centerId;
  app_center.Center? _userCenter;
  String _errorMessage = '';

  // Getters
  bool get isAuthenticated => _isAuthenticated;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  User? get user => _user;
  String? get token => _token;
  int? get centerId => _centerId;
  app_center.Center? get userCenter => _userCenter;
  String get errorMessage => _errorMessage;

  /// Inicializa el estado de autenticación
  Future<void> initializeAuth() async {
    if (_isInitialized) return;

    _isLoading = true;
    notifyListeners();

    try {
      // Verificar si hay un token válido
      _isAuthenticated = await _authService.isAuthenticated();

      if (_isAuthenticated) {
        // Cargar información del usuario
        _user = await _authService.getSavedUser();

        // Cargar información del centro
        _userCenter = await _authService.getSavedCenter();
        _centerId = _userCenter?.id;

        if (_userCenter == null && _user != null) {
          // Si tenemos usuario pero no centro, intentar cargar el centro
          await loadUserWithCenters();
        }
      }
    } catch (e) {
      debugPrint('Error al inicializar auth: $e');
      _isAuthenticated = false;
      _user = null;
      _token = null;
      _centerId = null;
      _userCenter = null;
      _errorMessage = _handleError(e);
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Actualiza la información del centro manualmente
  Future<void> updateCenterInfo(app_center.Center center) async {
    _userCenter = center;
    _centerId = center.id;
    notifyListeners();

    // También guardar el centro actualizado
    await _storageService.saveCenter(center);
  }

  /// Inicia sesión con correo y contraseña
  Future<void> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final authData = await _authService.login(email, password);

      // Actualizar estado
      _token = authData['token'] as String;
      _isAuthenticated = true;

      // Cargar información completa del usuario y sus centros
      await loadUserWithCenters();
    } catch (e) {
      debugPrint('Error en login: $e');
      _isAuthenticated = false;
      _user = null;
      _token = null;
      _centerId = null;
      _userCenter = null;
      _errorMessage = _handleError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Registra un nuevo usuario y centro
  Future<void> register({
    required String centerName,
    required String centerAddress,
    required String email,
    required String password,
    required String userName,
    required bool isSuperuser,
    required bool isStaff,
  }) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final response = await _authService.register(
        centerName: centerName,
        centerAddress: centerAddress,
        email: email,
        password: password,
        userName: userName,
        isSuperuser: isSuperuser,
        isStaff: isStaff,
      );

      // Actualizar estado
      _token = response['token'] as String;
      _isAuthenticated = true;

      // Cargar información completa del usuario y sus centros
      await loadUserWithCenters();
    } catch (e) {
      debugPrint('Error en registro: $e');
      _isAuthenticated = false;
      _user = null;
      _token = null;
      _centerId = null;
      _userCenter = null;
      _errorMessage = _handleError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cierra la sesión actual
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.logout();

      _isAuthenticated = false;
      _user = null;
      _token = null;
      _centerId = null;
      _userCenter = null;
      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'Error al cerrar sesión: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Carga información completa del usuario con sus centros
  Future<void> loadUserWithCenters() async {
    if (!_isAuthenticated) {
      throw 'Usuario no autenticado';
    }

    try {
      // Cargar información del usuario guardado
      _user = await _authService.getSavedUser();

      if (_user == null) {
        throw 'No se encontró información del usuario';
      }

      // Obtener información completa del usuario
      final userData = await _authService.getUserByEmail(_user!.email);

      // Actualizar información del usuario
      _user = User(
        email: userData['email'],
        name: userData['name'],
        isStaff: userData['is_staff'],
        isSuperuser: userData['is_superuser'],
      );

      // Actualizar información de los centros
      if (userData.containsKey('centers') &&
          userData['centers'] is List &&
          (userData['centers'] as List).isNotEmpty) {

        final centerData = userData['centers'][0]; // Tomamos el primer centro
        _userCenter = app_center.Center.fromJson(centerData);
        _centerId = _userCenter?.id;

        debugPrint('Centro actualizado: ${_userCenter?.name} (ID: $_centerId)');
      } else {
        debugPrint('El usuario no tiene centros asignados');

        // Intentar cargar centros desde otro endpoint
        final centers = await _authService.getUserCenters();
        if (centers.isNotEmpty) {
          _userCenter = centers.first;
          _centerId = _userCenter?.id;
          debugPrint('Centro cargado desde endpoint alternativo: ${_userCenter?.name} (ID: $_centerId)');
        } else {
          _userCenter = null;
          _centerId = null;
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error al cargar información completa del usuario: $e');
      // No hacemos fallar todo el proceso si esto falla
    }
  }

  /// Actualiza la información del centro
  Future<void> refreshCenterInfo() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_isAuthenticated && _user != null) {
        await loadUserWithCenters();
      } else {
        debugPrint('No hay usuario autenticado para refrescar el centro');
      }
    } catch (e) {
      debugPrint('Error al refrescar información del centro: $e');
      _errorMessage = _handleError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Maneja y formatea los errores para mostrarlos al usuario
  String _handleError(dynamic error) {
    if (error is String) return error;

    if (error.toString().contains('SocketException')) {
      return 'Error de conexión: verifica tu internet';
    }

    if (error.toString().contains('TimeoutException')) {
      return 'Tiempo de espera agotado: intenta de nuevo';
    }

    if (error.toString().contains('401') || error.toString().contains('403')) {
      return 'Error de autenticación: credenciales incorrectas o permisos insuficientes';
    }

    return 'Error de autenticación: ${error.toString()}';
  }
}