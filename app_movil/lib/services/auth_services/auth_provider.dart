import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../entities/user.dart';
import 'auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  bool _isAuthenticated = false;
  User? _user;

  bool get isAuthenticated => _isAuthenticated;
  User? get user => _user;

  Future<void> login(String username, String password) async {
    try {
      final token = await _authService.login(username, password);
      _isAuthenticated = true;
      // Aquí podrías hacer una petición adicional para obtener los datos del usuario
      notifyListeners();
    } catch (e) {
      _isAuthenticated = false;
      throw e;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    _isAuthenticated = false;
    _user = null;
    notifyListeners();
  }
}