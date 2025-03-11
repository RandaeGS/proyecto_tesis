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
          _centerId = _userCenter?.id;  // Usamos el ID numérico
          debugPrint('Centro cargado: ${_userCenter?.name} (ID: $_centerId)');
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

      // Guardar información del centro si está disponible en la respuesta
      if (authData.containsKey('center')) {
        final centerData = authData['center'] as Map<String, dynamic>;
        _userCenter = app_center.Center.fromJson(centerData);
        _centerId = _userCenter?.id;  // Usamos el ID numérico
        debugPrint('Centro asociado: ${_userCenter?.name} (ID: $_centerId)');
        await _authService.saveCenter(centerData);
      }

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
