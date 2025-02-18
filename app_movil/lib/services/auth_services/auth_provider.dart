import 'package:flutter/material.dart';
import 'package:app_movil/entities/user.dart';
import 'auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  bool _isAuthenticated = false;
  bool _isInitialized = false;
  User? _user;
  String? _token;

  bool get isAuthenticated => _isAuthenticated;
  bool get isInitialized => _isInitialized;
  User? get user => _user;
  String? get token => _token;

  Future<void> initializeAuth() async {
    if (_isInitialized) return;

    try {
      _token = await _authService.getToken();
      if (_token != null) {
        _user = await _authService.getSavedUser();
        _isAuthenticated = _user != null;
      }
    } catch (e) {
      _isAuthenticated = false;
      _user = null;
      _token = null;
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

      notifyListeners();
    } catch (e) {
      _isAuthenticated = false;
      _user = null;
      _token = null;
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

      notifyListeners();
    } catch (e) {
      print('Error en registro: $e');
      _isAuthenticated = false;
      _user = null;
      _token = null;
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

    return 'Error de autenticación: ${error.toString()}';
  }
}