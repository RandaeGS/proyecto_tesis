import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;

import '../auth_services/auth_service.dart';
import '../config.dart';

class AnalysisResult {
  final String id;
  final String fechaCreacion;
  final String tipoModelo;
  final int numeroObjetos;
  final double tiempoProcesamiento;
  final String resultados;
  final List<Map<String, dynamic>> detecciones;
  final String modeloUsado;

  AnalysisResult({
    required this.id,
    required this.fechaCreacion,
    required this.tipoModelo,
    required this.numeroObjetos,
    required this.tiempoProcesamiento,
    required this.resultados,
    this.detecciones = const [],
    this.modeloUsado = '',
  });

  // Agregar método para convertir a Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fechaCreacion': fechaCreacion,
      'tipoModelo': tipoModelo,
      'numeroObjetos': numeroObjetos,
      'tiempoProcesamiento': tiempoProcesamiento,
      'resultados': resultados,
      'detecciones': detecciones,
      'modeloUsado': modeloUsado,
    };
  }

  // Método factory para construir desde JSON
  factory AnalysisResult.fromJsonMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>> detecList = [];

    if (map['detecciones'] != null) {
      detecList = List<Map<String, dynamic>>.from(
          (map['detecciones'] as List).map((item) =>
          Map<String, dynamic>.from(item))
      );
    }

    return AnalysisResult(
      id: map['id'] ?? '',
      fechaCreacion: map['fechaCreacion'] ?? '',
      tipoModelo: map['tipoModelo'] ?? '',
      numeroObjetos: map['numeroObjetos'] ?? 0,
      tiempoProcesamiento: map['tiempoProcesamiento'] ?? 0.0,
      resultados: map['resultados'] ?? '',
      detecciones: detecList,
      modeloUsado: map['modeloUsado'] ?? '',
    );
  }

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    debugPrint('Procesando AnalysisResult.fromJson con: ${json.keys}');

    // Intentamos extraer los resultados
    final resultadosData = json['resultados'] ?? {};
    List<Map<String, dynamic>> detecciones = [];
    int objCount = 0;
    String modelType = '';

    // Procesamos la estructura de resultados
    if (resultadosData is Map) {
      // Extraer el tipo de modelo
      modelType = resultadosData['model_type'] ?? '';

      // Extraer conteo de objetos
      objCount = resultadosData['count'] ?? 0;

      // Extraer detecciones
      if (resultadosData.containsKey('detections') && resultadosData['detections'] is List) {
        final List detectionsList = resultadosData['detections'] as List;
        detecciones = detectionsList.map((item) =>
        Map<String, dynamic>.from(item as Map)
        ).toList();

        // Asegurar que el conteo coincida si no estaba explícito
        if (objCount == 0) {
          objCount = detecciones.length;
        }
      }
    }

    // Crear una versión formateada del JSON de resultados para mostrar
    final formattedJson = _formatResultJson(resultadosData);

    return AnalysisResult(
      id: json['deteccion_id']?.toString() ?? '',
      fechaCreacion: DateTime.now().toString(),
      tipoModelo: json['tipo_modelo'] ?? modelType,
      numeroObjetos: objCount,
      tiempoProcesamiento: json['tiempo_procesamiento']?.toDouble() ?? 0.0,
      resultados: formattedJson,
      detecciones: detecciones,
      modeloUsado: modelType,
    );
  }

  // Método para formatear el JSON de resultados de manera más legible
  static String _formatResultJson(Map<String, dynamic> json) {
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    try {
      return encoder.convert(json);
    } catch (e) {
      return json.toString();
    }
  }

  // Método para obtener una descripción resumida de cada detección
  List<String> getDetectionDescriptions() {
    return detecciones.map((detection) {
      final className = detection['class'] ?? 'Desconocido';
      final confidence = detection['confidence'] ?? 0.0;
      final formattedConfidence = (confidence * 100).toStringAsFixed(1);

      return '$className (${formattedConfidence}%)';
    }).toList();
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
      // Ya que sabemos que el endpoint requiere un archivo, vamos directo a multipart
      return await _analyzeWithMultipart(imageFile, modelType, token);
    } catch (e) {
      debugPrint('Error en analyzeImage: $e');
      rethrow;
    }
  }

  // Método para enviar solo JSON (como en el ejemplo de la documentación)
  Future<AnalysisResult?> _analyzeWithJsonOnly(String imagePath,
      String modelType, String token) async {
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
        debugPrint(
            'Error en _analyzeWithJsonOnly: ${response.statusCode} - ${response
                .body}');
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

    // Añadir campos
    request.fields['tipo_modelo'] = modelType;
    request.fields['guardar_imagen'] = 'true';

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

    // Debug para verificar qué estamos enviando
    debugPrint('Enviando solicitud a $url');
    debugPrint('Campos: ${request.fields}');

    // Enviar la solicitud
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    // Debug para ver la respuesta
    debugPrint('Código de respuesta: ${response.statusCode}');
    debugPrint('Respuesta body: ${response.body}');

    // Manejar la respuesta
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      return AnalysisResult.fromJson(data);
    } else {
      throw 'Error al analizar imagen (multipart): ${response.statusCode} - ${response.body}';
    }
  }
}
