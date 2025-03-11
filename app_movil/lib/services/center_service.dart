// lib/services/center_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../entities/center.dart' as app_center;
import '../entities/user.dart';
import '../services/auth_services/auth_service.dart';
import '../services/config.dart';

class CenterService {
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

  // Obtener headers de autorización
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getAuthToken();
    // Usar Bearer token para JWT (SimpleJWT)
    return {
      'Authorization': 'Bearer $token', // SimpleJWT usa Bearer
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
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

    // Lista de formatos de token para probar - para SimpleJWT primero Bearer
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

  // Obtener todos los centros
  Future<List<app_center.Center>> getAllCenters() async {
    // URL correcta según tu código Django
    final url = '$baseUrl/api/all-centers/';

    debugPrint('Solicitando todos los centros');
    debugPrint('URL: $url');

    try {
      final response = await _makeRequestWithTokenRetry(
              (headers) => http.get(Uri.parse(url), headers: headers)
      );

      final data = _handleResponse(response, entityName: 'Centros');
      if (data is List) {
        return data.map((json) => app_center.Center.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error en getAllCenters: $e');
      // Intentar con la URL alternativa si la primera falla
      try {
        final alternativeUrl = '$baseUrl/api/centers/';
        debugPrint('Intentando URL alternativa: $alternativeUrl');

        final response = await _makeRequestWithTokenRetry(
                (headers) => http.get(Uri.parse(alternativeUrl), headers: headers)
        );

        final data = _handleResponse(response, entityName: 'Centros');
        if (data is List) {
          return data.map((json) => app_center.Center.fromJson(json)).toList();
        }
        return [];
      } catch (alternativeError) {
        debugPrint('Error también con URL alternativa: $alternativeError');
        if (e is http.ClientException) {
          throw 'Error de conexión: verifique su internet';
        }
        rethrow;
      }
    }
  }

  // Obtener usuarios de un centro
  Future<List<User>> getCenterUsers(String centerId) async {
    // URL correcta según tu código Django
    final url = '$baseUrl/users/api/centers/$centerId/users/';

    debugPrint('Solicitando usuarios del centro $centerId');
    debugPrint('URL: $url');

    try {
      final response = await _makeRequestWithTokenRetry(
              (headers) => http.get(Uri.parse(url), headers: headers)
      );

      final data = _handleResponse(response, entityName: 'Centro');
      if (data is List) {
        return data.map((json) => User.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error en getCenterUsers: $e');
      if (e is http.ClientException) {
        throw 'Error de conexión: verifique su internet';
      }
      rethrow;
    }
  }

  // Obtener un centro por ID
  Future<app_center.Center> getCenterById(String centerId) async {
    // URL para obtener detalles del centro
    final url = '$baseUrl/api/centers/$centerId/';

    debugPrint('Obteniendo información del centro $centerId');
    debugPrint('URL: $url');

    try {
      final response = await _makeRequestWithTokenRetry(
              (headers) => http.get(Uri.parse(url), headers: headers)
      );

      final data = _handleResponse(response, entityName: 'Centro');
      return app_center.Center.fromJson(data);
    } catch (e) {
      debugPrint('Error en getCenterById: $e');
      if (e is http.ClientException) {
        throw 'Error de conexión: verifique su internet';
      }
      rethrow;
    }
  }

  // Crear un nuevo centro
  Future<app_center.Center> createCenter({
    required String name,
    required String address,
  }) async {
    final url = '$baseUrl/api/centers/';

    debugPrint('Creando nuevo centro');
    debugPrint('URL: $url');

    final body = {
      'name': name,
      'address': address,
    };

    try {
      final response = await _makeRequestWithTokenRetry(
              (headers) => http.post(
            Uri.parse(url),
            headers: headers,
            body: json.encode(body),
          )
      );

      final data = _handleResponse(response, entityName: 'Centro');
      return app_center.Center.fromJson(data);
    } catch (e) {
      debugPrint('Error en createCenter: $e');
      if (e is http.ClientException) {
        throw 'Error de conexión: verifique su internet';
      }
      rethrow;
    }
  }

  // Actualizar un centro existente
  Future<app_center.Center> updateCenter({
    required String centerId,
    required String name,
    required String address,
  }) async {
    final url = '$baseUrl/api/centers/$centerId/';

    debugPrint('Actualizando centro: $centerId');
    debugPrint('URL: $url');

    final body = {
      'name': name,
      'address': address,
    };

    try {
      final response = await _makeRequestWithTokenRetry(
              (headers) => http.put(
            Uri.parse(url),
            headers: headers,
            body: json.encode(body),
          )
      );

      final data = _handleResponse(response, entityName: 'Centro');
      return app_center.Center.fromJson(data);
    } catch (e) {
      debugPrint('Error en updateCenter: $e');
      if (e is http.ClientException) {
        throw 'Error de conexión: verifique su internet';
      }
      rethrow;
    }
  }

  // Eliminar un centro
  Future<void> deleteCenter(String centerId) async {
    final url = '$baseUrl/api/centers/$centerId/';

    debugPrint('Eliminando centro: $centerId');
    debugPrint('URL: $url');

    try {
      final response = await _makeRequestWithTokenRetry(
              (headers) => http.delete(Uri.parse(url), headers: headers)
      );

      _handleResponse(response, entityName: 'Centro');
    } catch (e) {
      debugPrint('Error en deleteCenter: $e');
      if (e is http.ClientException) {
        throw 'Error de conexión: verifique su internet';
      }
      rethrow;
    }
  }
}
