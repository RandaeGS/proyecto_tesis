import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;

import '../auth_services/auth_service.dart';
import '../config.dart';

// Modelo de resultados de análisis
class AnalysisResult {
  final String id;
  final String fechaCreacion;
  final String tipoModelo;
  final int numeroObjetos;
  final double tiempoProcesamiento;
  final String resultados;

  AnalysisResult({
    required this.id,
    required this.fechaCreacion,
    required this.tipoModelo,
    required this.numeroObjetos,
    required this.tiempoProcesamiento,
    required this.resultados,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      id: json['id'] ?? '',
      fechaCreacion: json['fecha_creacion'] ?? '',
      tipoModelo: json['tipo_modelo'] ?? '',
      numeroObjetos: json['numero_objetos'] ?? 0,
      tiempoProcesamiento: json['tiempo_procesamiento']?.toDouble() ?? 0.0,
      resultados: json['resultados'] ?? '',
    );
  }
}

class ImageAnalysisService {
  static String get baseUrl => AppConfig.getApiUrl();

  // Obtener token de autenticación
  Future<String> _getAuthToken() async {
    final authService = AuthService();
    final token = await authService.getToken();
    if (token == null || token.isEmpty) {
      throw 'No se encontró token de autenticación. Por favor inicie sesión nuevamente.';
    }
    return token;
  }

  // Analizar una imagen usando el endpoint
  Future<AnalysisResult> analyzeImage(File imageFile, String modelType) async {
    final token = await _getAuthToken();
    final url = '$baseUrl/api/detecciones/analizar/';

    debugPrint('Analizando imagen con modelo $modelType');
    debugPrint('URL: $url');

    try {
      // Primero, intentamos con JSON simple como muestra el ejemplo de la API
      final jsonResponse = await _analyzeWithJsonOnly(imageFile.path, modelType, token);
      if (jsonResponse != null) {
        return jsonResponse;
      }

      // Si falla, intentamos con multipart
      return await _analyzeWithMultipart(imageFile, modelType, token);
    } catch (e) {
      debugPrint('Error en analyzeImage: $e');
      rethrow;
    }
  }

  // Método para enviar solo JSON (como en el ejemplo de la documentación)
  Future<AnalysisResult?> _analyzeWithJsonOnly(String imagePath, String modelType, String token) async {
    final url = '$baseUrl/api/detecciones/analizar/';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'tipo_modelo': modelType
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return AnalysisResult.fromJson(data);
      } else {
        debugPrint('Error en _analyzeWithJsonOnly: ${response.statusCode} - ${response.body}');
        return null; // Permitir que se intente el otro método
      }
    } catch (e) {
      debugPrint('Error en _analyzeWithJsonOnly: $e');
      return null; // Permitir que se intente el otro método
    }
  }

  // Método para enviar con multipart
  Future<AnalysisResult> _analyzeWithMultipart(File imageFile, String modelType, String token) async {
    final url = '$baseUrl/api/detecciones/analizar/';

    // Crear solicitud multipart
    final request = http.MultipartRequest('POST', Uri.parse(url));

    // Añadir headers de autenticación
    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    // Añadir el tipo de modelo como campo JSON
    request.fields['tipo_modelo'] = modelType;

    // Añadir la imagen
    final fileExtension = path.extension(imageFile.path).toLowerCase();
    String mimeType;

    if (fileExtension == '.jpg' || fileExtension == '.jpeg') {
      mimeType = 'image/jpeg';
    } else if (fileExtension == '.png') {
      mimeType = 'image/png';
    } else {
      mimeType = 'application/octet-stream';
    }

    request.files.add(await http.MultipartFile.fromPath(
        'imagen',
        imageFile.path,
        contentType: MediaType.parse(mimeType)
    ));

    // Enviar la solicitud
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    // Manejar la respuesta
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return AnalysisResult.fromJson(data);
    } else {
      throw 'Error al analizar imagen (multipart): ${response.statusCode} - ${response.body}';
    }
  }
}
