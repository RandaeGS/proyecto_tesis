import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/config.dart';

/// Cliente API centralizado para manejar todas las solicitudes HTTP
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();

  factory ApiClient() => _instance;

  ApiClient._internal();

  // Claves para SharedPreferences
  static const String tokenKey = 'auth_token';
  static const String tokenFormatKey = 'token_format';

  // Formato del token por defecto (Bearer para JWT)
  String _tokenFormat = 'Bearer';

  // Obtener la URL base desde la configuración
  String get baseUrl => AppConfig.getApiUrl();

  /// Obtiene el token de autenticación almacenado
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

  /// Guarda el token de autenticación
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
    await prefs.setString(tokenFormatKey, _tokenFormat);
    debugPrint('Token guardado (primeros 10 caracteres): ${token.substring(0, token.length > 10 ? 10 : token.length)}...');
  }

  /// Elimina el token guardado y otros datos de autenticación
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    // Mantener el formato del token para futuras sesiones
  }

  /// Obtiene los headers para autenticación
  Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      // Headers básicos sin autenticación
      return {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
    }

    // Headers con autenticación
    return {
      'Authorization': '$_tokenFormat $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  /// Registra detalles de la respuesta HTTP para debugging
  void _logResponse(http.Response response) {
    debugPrint('URL: ${response.request?.url}');
    debugPrint('Status code: ${response.statusCode}');

    try {
      if (response.body.isNotEmpty) {
        final preview = response.body.length > 200
            ? '${response.body.substring(0, 200)}...'
            : response.body;
        debugPrint('Body: $preview');
      } else {
        debugPrint('Body: (vacío)');
      }
    } catch (e) {
      debugPrint('Error al mostrar cuerpo de respuesta: $e');
    }
  }

  /// Procesa la respuesta HTTP y maneja errores comunes
  dynamic handleResponse(http.Response response, {String? entityName}) {
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

  /// GET request
  Future<dynamic> get(String endpoint, {String? entityName}) async {
    final headers = await getAuthHeaders();
    final url = Uri.parse('$baseUrl$endpoint');

    debugPrint('GET request a: $url');

    try {
      final response = await http.get(url, headers: headers);
      return handleResponse(response, entityName: entityName);
    } catch (e) {
      _handleConnectionError(e);
    }
  }

  /// POST request
  Future<dynamic> post(String endpoint, dynamic data, {String? entityName}) async {
    final headers = await getAuthHeaders();
    final url = Uri.parse('$baseUrl$endpoint');

    debugPrint('POST request a: $url');
    debugPrint('Data: ${json.encode(data)}');

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(data),
      );
      return handleResponse(response, entityName: entityName);
    } catch (e) {
      _handleConnectionError(e);
    }
  }

  /// PUT request
  Future<dynamic> put(String endpoint, dynamic data, {String? entityName}) async {
    final headers = await getAuthHeaders();
    final url = Uri.parse('$baseUrl$endpoint');

    debugPrint('PUT request a: $url');
    debugPrint('Data: ${json.encode(data)}');

    try {
      final response = await http.put(
        url,
        headers: headers,
        body: json.encode(data),
      );
      return handleResponse(response, entityName: entityName);
    } catch (e) {
      _handleConnectionError(e);
    }
  }

  /// PATCH request
  Future<dynamic> patch(String endpoint, dynamic data, {String? entityName}) async {
    final headers = await getAuthHeaders();
    final url = Uri.parse('$baseUrl$endpoint');

    debugPrint('PATCH request a: $url');
    debugPrint('Data: ${json.encode(data)}');

    try {
      final response = await http.patch(
        url,
        headers: headers,
        body: json.encode(data),
      );
      return handleResponse(response, entityName: entityName);
    } catch (e) {
      _handleConnectionError(e);
    }
  }

  /// DELETE request
  Future<dynamic> delete(String endpoint, {String? entityName}) async {
    final headers = await getAuthHeaders();
    final url = Uri.parse('$baseUrl$endpoint');

    debugPrint('DELETE request a: $url');

    try {
      final response = await http.delete(url, headers: headers);
      return handleResponse(response, entityName: entityName);
    } catch (e) {
      _handleConnectionError(e);
    }
  }

  /// Maneja errores de conexión comunes
  void _handleConnectionError(dynamic error) {
    debugPrint('Error de conexión: $error');

    if (error is http.ClientException) {
      throw 'Error de conexión: Verifique su conexión a internet y la URL del servidor.';
    }

    throw error.toString();
  }

  /// Multipart request para subir archivos
  Future<dynamic> uploadFile(
      String endpoint,
      String filePath,
      String fieldName,
      Map<String, String> fields,
      {String? entityName}
      ) async {
    final token = await getToken();
    final url = Uri.parse('$baseUrl$endpoint');

    debugPrint('POST Multipart a: $url');
    debugPrint('Campos: $fields');

    try {
      // Crear solicitud multipart
      final request = http.MultipartRequest('POST', url);

      // Añadir headers de autenticación
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = '$_tokenFormat $token';
      }
      request.headers['Accept'] = 'application/json';

      // Añadir campos adicionales
      request.fields.addAll(fields);

      // Añadir archivo
      request.files.add(await http.MultipartFile.fromPath(
        fieldName,
        filePath,
      ));

      // Enviar solicitud
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      return handleResponse(response, entityName: entityName);
    } catch (e) {
      _handleConnectionError(e);
    }
  }
}