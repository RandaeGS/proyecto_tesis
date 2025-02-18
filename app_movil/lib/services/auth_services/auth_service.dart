import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/entities/user.dart';

class AuthService {
  static const String baseUrl = 'http://localhost:8080';
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';

  Future<Map<String, dynamic>> register({
    required String centerName,
    required String centerAddress,
    required String email,
    required String password,
    required String userName,
    required bool isSuperuser,
    required bool isStaff,
  }) async {
    final url = '$baseUrl/api/register/';
    final body = {
      'center': {
        'name': centerName,
        'address': centerAddress,
      },
      'user': {
        'email': email,
        'password': password,
        'name': userName,
        'is_superuser': isSuperuser,
        'is_staff': isStaff,
      }
    };


    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));


      if (response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(response.body);

        // Guardamos el token
        final String token = responseData['token'] as String;
        await _saveToken(token);

        // Guardamos la información del usuario
        final Map<String, dynamic> userData = responseData['user'] as Map<String, dynamic>;
        final user = User(
          email: userData['email'] as String,
          password: '',
          name: userData['name'] as String,
          isStaff: userData['is_staff'] as bool,
          isSuperuser: userData['is_superuser'] as bool,
        );
        await _saveUserInfo(user);

        return {
          'token': token,
          'user': userData,
          'center': responseData['center'],
        };
      } else {


        if (response.statusCode == 400) {
          final errors = json.decode(response.body);
          throw 'Error de validación: ${errors.toString()}';
        } else {
          throw 'Error en el registro: ${response.statusCode}';
        }
      }
    } catch (e) {
      if (e is http.ClientException) {
        throw 'Error de conexión: verifica tu internet y la URL del servidor';
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/login/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );


      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        final String token = data['token'] as String;
        await _saveToken(token);

        final Map<String, dynamic> userData = data['user'] as Map<String, dynamic>;
        final user = User(
          email: userData['email'] as String,
          password: '',
          name: userData['name'] as String,
          isStaff: userData['is_staff'] as bool,
          isSuperuser: userData['is_superuser'] as bool,
        );

        await _saveUserInfo(user);

        return {
          'token': token,
          'user': userData,
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

  Future<void> _saveUserInfo(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final userMap = {
      'email': user.email,
      'name': user.name,
      'is_staff': user.isStaff,
      'is_superuser': user.isSuperuser,
    };
    await prefs.setString(userKey, json.encode(userMap));
  }

  Future<User?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(userKey);
    if (userStr != null) {
      final Map<String, dynamic> userMap = json.decode(userStr);
      return User(
        email: userMap['email'] as String,
        password: '',
        name: userMap['name'] as String,
        isStaff: userMap['is_staff'] as bool,
        isSuperuser: userMap['is_superuser'] as bool,
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