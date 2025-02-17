import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/entities/user.dart';

class AuthService {
  static const String baseUrl = 'https://tu-api-django.com';
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth-token/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _saveToken(data['token']);

        // Creamos un objeto User con los datos recibidos
        final user = User(
          email: email,
          password: password, // Nota: normalmente no guardaríamos la contraseña
          name: data['name'],
        );

        await _saveUserInfo(user);

        return {
          'token': data['token'],
          'user': user,
        };
      } else if (response.statusCode == 400) {
        throw 'Credenciales inválidas';
      } else if (response.statusCode == 401) {
        throw 'No autorizado';
      } else {
        throw 'Error del servidor: ${response.statusCode}';
      }
    } catch (e) {
      if (e is http.ClientException) {
        throw 'Error de conexión: verifica tu internet';
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> register({
    required String centerName,
    required String centerAddress,
    required String email,
    required String password,
    required String userName,
    required bool isSuperuser,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/centers/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'center': {
            'name': centerName,
            'address': centerAddress,
          },
          'user': {
            'email': email,
            'password': password,
            'name': userName,
            'is_superuser': isSuperuser,
          }
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        await _saveToken(data['token']);

        return data;
      } else if (response.statusCode == 400) {
        final errors = json.decode(response.body);
        throw 'Error de validación: ${errors.toString()}';
      } else {
        throw 'Error en el registro: ${response.statusCode}';
      }
    } catch (e) {
      if (e is http.ClientException) {
        throw 'Error de conexión: verifica tu internet';
      }
      rethrow;
    }
  }

  Future<void> _saveUserInfo(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final userMap = {
      'email': user.email,
      'name': user.name,
    };
    await prefs.setString(userKey, json.encode(userMap));
  }

  Future<User?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(userKey);
    if (userStr != null) {
      final userMap = json.decode(userStr);
      return User(
        email: userMap['email'],
        password: '', // No guardamos la contraseña
        name: userMap['name'],
      );
    }
    return null;
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey);
  }

  Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    await prefs.remove(userKey);
  }
}
