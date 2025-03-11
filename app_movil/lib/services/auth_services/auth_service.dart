// lib/services/auth_services/auth_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/entities/user.dart';
import 'package:app_movil/services/config.dart';

class AuthService {
  // Claves para SharedPreferences
  static String get baseUrl => AppConfig.getApiUrl();
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String centerKey = 'center_data';
  static const String tokenFormatKey = 'token_format';

  // Mostrar detalles de la respuesta HTTP para depuración
  void _logResponse(http.Response response) {
    debugPrint('Status code: ${response.statusCode}');
    debugPrint('Headers: ${response.headers}');
    try {
      if (response.body.isNotEmpty) {
        debugPrint('Body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');
      } else {
        debugPrint('Body: (vacío)');
      }
    } catch (e) {
      debugPrint('Error al mostrar cuerpo de respuesta: $e');
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

  // Manejar respuesta HTTP con manejo de errores
  dynamic _handleResponse(http.Response response, {String? entityName}) {
    _logResponse(response);

    switch (response.statusCode) {
      case 200:
      case 201:
        if (response.body.isEmpty) {
          return null;
        }
        return json.decode(response.body);
      case 204:
        return null;
      case 400:
        throw 'Error de validación: ${response.body}';
      case 401:
        throw 'No autorizado. Por favor inicie sesión nuevamente.';
      case 403:
        throw 'No tiene permisos para esta acción. Contacte al administrador.';
      case 404:
        if (entityName != null) {
          throw '$entityName no encontrado.';
        }
        throw 'Recurso no encontrado.';
      case 500:
        throw 'Error del servidor. Intente más tarde.';
      default:
        throw 'Error inesperado (${response.statusCode}): ${response.body}';
    }
  }

  Future<Map<String, dynamic>> register({
    required String centerName,
    required String centerAddress,
    required String email,
    required String password,
    required String userName,
    required bool isSuperuser,
    required bool isStaff,
  }) async {
    // URL correcta según tu configuración Django
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

    debugPrint('Registrando usuario en URL: $url');
    debugPrint('Datos: ${jsonEncode(body)}');

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));

      final responseData = _handleResponse(response, entityName: 'Registro');

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

      // Guardar información del centro
      if (responseData.containsKey('center')) {
        await saveCenter(responseData['center'] as Map<String, dynamic>);
      }

      return responseData;
    } catch (e) {
      debugPrint('Error en registro: $e');
      if (e is http.ClientException) {
        throw 'Error de conexión: verifica tu internet y la URL del servidor';
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // URL correcta según tu configuración Django
      final url = '$baseUrl/api/login/';
      debugPrint('Intentando login en: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      final data = _handleResponse(response, entityName: 'Login');

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

      // Guardar información del centro si está disponible
      if (data.containsKey('center')) {
        await saveCenter(data['center'] as Map<String, dynamic>);
      }

      return data;
    } catch (e) {
      debugPrint('Error de login: $e');
      if (e is http.ClientException) {
        throw 'Error de conexión: verifica tu internet';
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUserCenters() async {
    final token = await getToken();
    if (token == null) {
      throw 'No autorizado: inicie sesión primero';
    }

    // Usar el endpoint correcto según tu API
    final url = '$baseUrl/api/users/me/';
    debugPrint('Obteniendo información del usuario con sus centros: $url');

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final data = _handleResponse(response, entityName: 'Usuario');

      // Verificar si la respuesta contiene información de centros
      if (data is Map && data.containsKey('centers')) {
        // Si el backend devuelve los centros directamente
        return List<Map<String, dynamic>>.from(data['centers']);
      } else if (data is Map) {
        // Si necesitamos hacer una segunda llamada para obtener los centros
        // por ejemplo, si 'me' devuelve el ID pero no la información completa
        final userId = data['id'] ?? data['email'];
        return await _getUserCentersById(userId.toString());
      }

      return [];
    } catch (e) {
      debugPrint('Error al obtener centros: $e');
      rethrow;
    }
  }

// Método auxiliar para obtener los centros por ID de usuario
  Future<List<Map<String, dynamic>>> _getUserCentersById(String userId) async {
    final token = await getToken();
    if (token == null) {
      throw 'No autorizado: inicie sesión primero';
    }

    // Este endpoint debería devolvernos los centros asociados a un usuario
    final url = '$baseUrl/users/api/users/$userId/centers/';
    debugPrint('Obteniendo centros del usuario por ID: $url');

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final data = _handleResponse(response, entityName: 'Centros');

      // Manejar diferentes estructuras de respuesta
      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      } else if (data is Map && data.containsKey('centers')) {
        return List<Map<String, dynamic>>.from(data['centers']);
      }

      return [];
    } catch (e) {
      // Si falla específicamente esta llamada, intentamos con otra ruta alternativa
      try {
        // Probar con la ruta alternativa que obtiene los centros
        return await _getAllCentersForUser();
      } catch (_) {
        debugPrint('Error al obtener centros del usuario: $e');
        rethrow;
      }
    }
  }


// Método alternativo para obtener todos los centros y filtrar por usuario
  Future<List<Map<String, dynamic>>> _getAllCentersForUser() async {
    final token = await getToken();
    if (token == null) {
      throw 'No autorizado: inicie sesión primero';
    }

    final url = '$baseUrl/users/api/centers/';
    debugPrint('Obteniendo todos los centros: $url');

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final data = _handleResponse(response, entityName: 'Centros');

      if (data is List) {
        // Aquí deberíamos filtrar los centros que pertenecen al usuario
        // Si el backend no proporciona esta información, devolvemos todos
        return List<Map<String, dynamic>>.from(data);
      } else if (data is Map && data.containsKey('results')) {
        return List<Map<String, dynamic>>.from(data['results']);
      }

      return [];
    } catch (e) {
      debugPrint('Error al obtener todos los centros: $e');
      rethrow;
    }
  }


  Future<void> saveCenter(Map<String, dynamic> centerData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(centerKey, json.encode(centerData));
    debugPrint('Centro guardado: ${json.encode(centerData)}');
  }

  Future<Map<String, dynamic>?> getSavedCenter() async {
    final prefs = await SharedPreferences.getInstance();
    final centerStr = prefs.getString(centerKey);
    if (centerStr != null) {
      return json.decode(centerStr) as Map<String, dynamic>;
    }
    return null;
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

  Future<Map<String, dynamic>> getUserByEmail(String email) async {
    final token = await getToken();
    if (token == null) {
      throw 'No autorizado: inicie sesión primero';
    }

    final url = '$baseUrl/users/api/users/by-email/$email/';
    debugPrint('Obteniendo usuario por email: $url');

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      return _handleResponse(response, entityName: 'Usuario');
    } catch (e) {
      debugPrint('Error al obtener usuario por email: $e');
      rethrow;
    }
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
    debugPrint('Token guardado (primeros 10 caracteres): ${token.substring(0, token.length > 10 ? 10 : token.length)}...');
    // SimpleJWT usa Bearer como formato
    await prefs.setString(tokenFormatKey, 'Bearer');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(tokenKey);
    if (token != null && token.isNotEmpty) {
      debugPrint('Token recuperado (primeros 10 caracteres): ${token.substring(0, token.length > 10 ? 10 : token.length)}...');
    } else {
      debugPrint('No se encontró token almacenado');
    }
    return token;
  }

  // Obtener el token con el formato correcto
  Future<String?> getFormattedToken() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    // SimpleJWT usa Bearer por defecto
    return 'Bearer $token';
  }

  Future<void> clearAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    await prefs.remove(userKey);
    await prefs.remove(centerKey);
    // Mantener el formato del token para futuras sesiones
  }
}
