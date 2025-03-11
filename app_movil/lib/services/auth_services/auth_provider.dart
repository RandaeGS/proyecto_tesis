// lib/services/auth_services/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:app_movil/entities/user.dart';
import 'package:app_movil/entities/center.dart' as app_center;
import 'auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  bool _isAuthenticated = false;
  bool _isInitialized = false;
  User? _user;
  String? _token;
  int? _centerId;    // Cambiado a int
  app_center.Center? _userCenter;

  bool get isAuthenticated => _isAuthenticated;
  bool get isInitialized => _isInitialized;
  User? get user => _user;
  String? get token => _token;
  int? get centerId => _centerId;  // Cambiado a int
  app_center.Center? get userCenter => _userCenter;

  Future<void> initializeAuth() async {
    if (_isInitialized) return;

    try {
      _token = await _authService.getToken();
      if (_token != null) {
        _user = await _authService.getSavedUser();
        _isAuthenticated = _user != null;

        // Cargar información del centro si está disponible
        final centerData = await _authService.getSavedCenter();
        if (centerData != null) {
          _userCenter = app_center.Center.fromJson(centerData);
          _centerId = _userCenter?.id;
          debugPrint('Centro cargado: ${_userCenter?.name} (ID: $_centerId)');
        } else if (_user != null) {
          // Si tenemos usuario pero no centro, intentar cargar la información
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
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    try {
      final authData = await _authService.login(email, password);

      _token = authData['token'] as String;
      final userData = authData['user'] as Map<String, dynamic>;
      _user = User.fromJson(userData);
      _isAuthenticated = true;

      // Cargar información completa del usuario y sus centros
      await loadUserWithCenters();

      notifyListeners();
    } catch (e) {
      debugPrint('Error en login: $e');
      _isAuthenticated = false;
      _user = null;
      _token = null;
      _centerId = null;
      _userCenter = null;
      notifyListeners();
      throw _handleError(e);
    }
  }

// Nuevo método para cargar los centros del usuario
  Future<void> _loadUserCenter() async {
    try {
      final centers = await _authService.getUserCenters();

      if (centers.isNotEmpty) {
        // Tomar el primer centro de la lista (puedes implementar una selección)
        final centerData = centers.first;
        _userCenter = app_center.Center.fromJson(centerData);
        _centerId = _userCenter?.id;
        debugPrint('Centro cargado explícitamente: ${_userCenter?.name} (ID: $_centerId)');
        debugPrint('Usuario autenticado: ${_user?.email}');
        await _authService.saveCenter(centerData);
      } else {
        debugPrint('El usuario no tiene centros asignados');
        _userCenter = null;
        _centerId = null;
      }
    } catch (e) {
      debugPrint('Error al cargar centro del usuario: $e');
      // No hacemos fallar el login si esto falla
    }
  }

  // Añadir este método a tu clase AuthProvider
  Future<void> loadUserWithCenters() async {
    if (!_isAuthenticated || _user == null) {
      throw 'Usuario no autenticado';
    }

    try {
      final userData = await _authService.getUserByEmail(_user!.email);

      // Actualizar información del usuario si es necesario
      _user = User(
        email: userData['email'],
        password: '',
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

        // Guardar el centro en las preferencias
        await _authService.saveCenter(centerData);
      } else {
        debugPrint('El usuario no tiene centros asignados');
        _userCenter = null;
        _centerId = null;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error al cargar información completa del usuario: $e');
      // No hacemos fallar todo el proceso si esto falla
    }
  }

  Future<void> refreshCenterInfo() async {
    try {
      if (_user != null) {
        await loadUserWithCenters();
      } else {
        debugPrint('No hay usuario autenticado para refrescar el centro');
      }
    } catch (e) {
      debugPrint('Error al refrescar información del centro: $e');
    }
  }

  Future<void> register({
    required String centerName,
    required String centerAddress,
    required String email,
    required String password,
    required String userName,
    required bool isSuperuser,
    required bool isStaff,
  }) async {
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

      _token = response['token'] as String;
      final userData = response['user'] as Map<String, dynamic>;
      _user = User.fromJson(userData);
      _isAuthenticated = true;

      // Guardar información del centro recién creado
      if (response.containsKey('center')) {
        final centerData = response['center'] as Map<String, dynamic>;
        _userCenter = app_center.Center.fromJson(centerData);
        _centerId = _userCenter?.id;  // Usamos el ID numérico
        debugPrint('Centro creado: ${_userCenter?.name} (ID: $_centerId)');
        await _authService.saveCenter(centerData);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error en registro: $e');
      _isAuthenticated = false;
      _user = null;
      _token = null;
      _centerId = null;
      _userCenter = null;
      notifyListeners();
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    try {
      await _authService.clearAuthData();
      _isAuthenticated = false;
      _user = null;
      _token = null;
      _centerId = null;
      _userCenter = null;
      notifyListeners();
    } catch (e) {
      throw 'Error al cerrar sesión: $e';
    }
  }

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
