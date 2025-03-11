// lib/services/user_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../entities/user.dart';
import '../services/auth_services/auth_service.dart';
import '../services/config.dart';

class UserService {
  static String get baseUrl => AppConfig.getApiUrl();

  // Obtener el token de autenticación
  Future<String> _getAuthToken() async {
    final authService = AuthService();
    final token = await authService.getToken();
    if (token == null || token.isEmpty) {
      throw 'No se encontró token de autenticación. Por favor inicie sesión nuevamente.';
    }
    return token;
  }

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

  // Método para probar diferentes formatos de token si el primero falla
  Future<http.Response> _makeRequestWithTokenRetry(
      Future<http.Response> Function(Map<String, String> headers) requestFunction
      ) async {
    final token = await _getAuthToken();

    // Lista de formatos de token para probar
    final tokenFormats = [
      'Bearer $token',  // Formato JWT común
      'Token $token',   // Formato usado en algunos sistemas Django Rest Framework
      token,            // Solo el token sin prefijo
    ];

    http.Response? lastResponse;

    // Intentar con cada formato de token
    for (final tokenFormat in tokenFormats) {
      try {
        final headers = {
          'Authorization': tokenFormat,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        };

        debugPrint('Intentando con formato de token: ${tokenFormat.substring(0, tokenFormat.length > 15 ? 15 : tokenFormat.length)}...');

        final response = await requestFunction(headers);
        lastResponse = response;

        // Si no es 401/403, consideramos que el formato funcionó
        if (response.statusCode != 401 && response.statusCode != 403) {
          debugPrint('Formato de token aceptado: ${tokenFormat.split(' ').first}');
          return response;
        }
      } catch (e) {
        debugPrint('Error con formato de token $tokenFormat: $e');
      }
    }

    // Si todos los formatos fallaron, devolver la última respuesta o lanzar una excepción
    if (lastResponse != null) {
      return lastResponse;
    } else {
      throw 'No se pudo realizar la solicitud con ningún formato de token';
    }
  }

  // Obtener todos los usuarios
  Future<List<User>> getUsers() async {
    final url = '$baseUrl/api/users/';

    debugPrint('Obteniendo todos los usuarios');
    debugPrint('URL: $url');

    try {
      final response = await _makeRequestWithTokenRetry(
              (headers) => http.get(Uri.parse(url), headers: headers)
      );

      final data = _handleResponse(response, entityName: 'Usuarios');
      if (data is List) {
        return data.map((json) => User.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error en getUsers: $e');
      // Si no existe el endpoint /api/users/, intentar con la búsqueda
      try {
        return await searchUsers('');
      } catch (searchError) {
        debugPrint('Error también en búsqueda: $searchError');
        if (e is http.ClientException) {
          throw 'Error de conexión: verifique su internet';
        }
        rethrow;
      }
    }
  }

  // Obtener un usuario por ID
  Future<User> getUserById(String userId) async {
    final url = '$baseUrl/api/users/$userId/';

    debugPrint('Obteniendo usuario: $userId');
    debugPrint('URL: $url');

    try {
      final response = await _makeRequestWithTokenRetry(
              (headers) => http.get(Uri.parse(url), headers: headers)
      );

      final data = _handleResponse(response, entityName: 'Usuario');
      return User.fromJson(data);
    } catch (e) {
      debugPrint('Error en getUserById: $e');
      if (e is http.ClientException) {
        throw 'Error de conexión: verifique su internet';
      }
      rethrow;
    }
  }

  // Crear un nuevo usuario
  Future<User> createUser({
    required String email,
    required String password,
    required String name,
    required bool isSuperuser,
    required bool isStaff,
  }) async {
    final url = '$baseUrl/users/api/users/create/';

    debugPrint('Creando nuevo usuario');
    debugPrint('URL: $url');

    final body = {
      'email': email,
      'password': password,
      'name': name,
      'is_superuser': isSuperuser,
      'is_staff': isStaff,
    };

    debugPrint('Datos: ${json.encode(body)}');

    try {
      final response = await _makeRequestWithTokenRetry(
              (headers) => http.post(
            Uri.parse(url),
            headers: headers,
            body: json.encode(body),
          )
      );

      final data = _handleResponse(response, entityName: 'Usuario');
      // Manejamos tanto el caso donde la API devuelve directamente los datos
      // como cuando los envuelve en un objeto 'data'
      if (data is Map<String, dynamic> && data.containsKey('data')) {
        return User.fromJson(data['data']);
      } else {
        return User.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error en createUser: $e');
      if (e is http.ClientException) {
        throw 'Error de conexión: verifique su internet';
      }
      rethrow;
    }
  }

  // Actualizar un usuario existente
  Future<User> updateUser({
    required String userId,
    required String name,
    required bool isSuperuser,
    required bool isStaff,
  }) async {
    final url = '$baseUrl/api/users/$userId/';

    debugPrint('Actualizando usuario: $userId');
    debugPrint('URL: $url');

    final body = {
      'name': name,
      'is_superuser': isSuperuser,
      'is_staff': isStaff,
    };

    debugPrint('Datos: ${json.encode(body)}');

    try {
      final response = await _makeRequestWithTokenRetry(
              (headers) => http.put(
            Uri.parse(url),
            headers: headers,
            body: json.encode(body),
          )
      );

      final data = _handleResponse(response, entityName: 'Usuario');
      // Manejar tanto respuesta directa como envuelta en 'data'
      if (data is Map<String, dynamic> && data.containsKey('data')) {
        return User.fromJson(data['data']);
      } else {
        return User.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error en updateUser: $e');
      if (e is http.ClientException) {
        throw 'Error de conexión: verifique su internet';
      }
      rethrow;
    }
  }

  // Actualizar la contraseña de un usuario
  Future<void> resetPassword({
    required String userId,
    required String newPassword,
  }) async {
    final url = '$baseUrl/api/users/$userId/';

    debugPrint('Actualizando contraseña para usuario: $userId');
    debugPrint('URL: $url');

    final body = {
      'password': newPassword,
    };

    try {
      final response = await _makeRequestWithTokenRetry(
              (headers) => http.patch(
            Uri.parse(url),
            headers: headers,
            body: json.encode(body),
          )
      );

      _handleResponse(response, entityName: 'Usuario');
    } catch (e) {
      debugPrint('Error en resetPassword: $e');
      if (e is http.ClientException) {
        throw 'Error de conexión: verifique su internet';
      }
      rethrow;
    }
  }

  // Eliminar un usuario
  Future<void> deleteUser(String userId) async {
    final url = '$baseUrl/api/users/$userId/';

    debugPrint('Eliminando usuario: $userId');
    debugPrint('URL: $url');

    try {
      final response = await _makeRequestWithTokenRetry(
              (headers) => http.delete(Uri.parse(url), headers: headers)
      );

      _handleResponse(response, entityName: 'Usuario');
    } catch (e) {
      debugPrint('Error en deleteUser: $e');
      if (e is http.ClientException) {
        throw 'Error de conexión: verifique su internet';
      }
      rethrow;
    }
  }

  // Buscar usuarios
  Future<List<User>> searchUsers(String query) async {
    final url = '$baseUrl/api/users/search/?q=$query';

    debugPrint('Buscando usuarios: $query');
    debugPrint('URL: $url');

    try {
      final response = await _makeRequestWithTokenRetry(
              (headers) => http.get(Uri.parse(url), headers: headers)
      );

      final data = _handleResponse(response, entityName: 'Usuarios');
      if (data is List) {
        return data.map((json) => User.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error en searchUsers: $e');
      if (e is http.ClientException) {
        throw 'Error de conexión: verifique su internet';
      }
      rethrow;
    }
  }

  // Asignar usuario a un centro
  Future<User> assignUserToCenter({
    required String userId,
    required String centerId,
  }) async {
    final url = '$baseUrl/api/users/$userId/assign-center/';

    debugPrint('Asignando usuario $userId al centro $centerId');
    debugPrint('URL: $url');

    final body = {
      'center_id': centerId,
    };

    try {
      final response = await _makeRequestWithTokenRetry(
              (headers) => http.put(
            Uri.parse(url),
            headers: headers,
            body: json.encode(body),
          )
      );

      final data = _handleResponse(response, entityName: 'Usuario');
      if (data is Map<String, dynamic> && data.containsKey('data')) {
        return User.fromJson(data['data']);
      } else {
        return User.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error en assignUserToCenter: $e');
      if (e is http.ClientException) {
        throw 'Error de conexión: verifique su internet';
      }
      rethrow;
    }
  }

  // Eliminar usuario de un centro
  Future<User> removeUserFromCenter({
    required String userId,
    required String centerId,
  }) async {
    final url = '$baseUrl/api/users/$userId/remove-center/';

    debugPrint('Eliminando usuario $userId del centro $centerId');
    debugPrint('URL: $url');

    final body = {
      'center_id': centerId,
    };

    try {
      final response = await _makeRequestWithTokenRetry(
              (headers) => http.put(
            Uri.parse(url),
            headers: headers,
            body: json.encode(body),
          )
      );

      final data = _handleResponse(response, entityName: 'Usuario');
      if (data is Map<String, dynamic> && data.containsKey('data')) {
        return User.fromJson(data['data']);
      } else {
        return User.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error en removeUserFromCenter: $e');
      if (e is http.ClientException) {
        throw 'Error de conexión: verifique su internet';
      }
      rethrow;
    }
  }
}
