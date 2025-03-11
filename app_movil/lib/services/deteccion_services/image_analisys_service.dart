import 'dart:io';
import 'package:flutter/material.dart';

import '../../entities/analisysresult.dart';
import '../core/api_client.dart';
import '../core/api_constants.dart';
import '../core/storage_services.dart';

/// Servicio para analizar imágenes y manejar resultados
class ImageAnalysisService {
  final ApiClient _apiClient = ApiClient();
  final StorageService _storageService = StorageService();

  /// Analiza una imagen usando el endpoint de la API
  Future<AnalysisResult> analyzeImage(File imageFile, String modelType, {int? centerId}) async {
    try {
      debugPrint('Analizando imagen con modelo $modelType');

      // Campos adicionales para el análisis
      final fields = {
        'tipo_modelo': modelType,
        'guardar_imagen': 'true',
      };

      // Añadir centerId si está disponible
      if (centerId != null) {
        fields['center_id'] = centerId.toString();
      }

      // Enviar la imagen para análisis
      final data = await _apiClient.uploadFile(
        ApiConstants.analyzeImage,
        imageFile.path,
        'imagen',
        fields,
        entityName: 'Análisis',
      );

      // Convertir la respuesta a un objeto AnalysisResult
      final result = AnalysisResult.fromJson(data);

      // Guardar el resultado en el almacenamiento local
      await _storageService.saveAnalysisResult(imageFile.path, result);

      return result;
    } catch (e) {
      debugPrint('Error en analyzeImage: $e');
      rethrow;
    }
  }

  /// Obtiene todos los resultados de análisis guardados
  Future<Map<String, AnalysisResult>> getAllAnalysisResults() async {
    try {
      final Map<String, dynamic> resultsMap = await _storageService.getAnalysisResults();
      final Map<String, AnalysisResult> analysisResults = {};

      // Convertir cada entrada a un objeto AnalysisResult
      resultsMap.forEach((key, value) {
        analysisResults[key] = AnalysisResult.fromJsonMap(value);
      });

      return analysisResults;
    } catch (e) {
      debugPrint('Error en getAllAnalysisResults: $e');
      return {};
    }
  }

  /// Obtiene un resultado de análisis guardado por la ruta de la imagen
  Future<AnalysisResult?> getAnalysisResult(String imagePath) async {
    return await _storageService.getAnalysisResult(imagePath);
  }

  /// Elimina un resultado de análisis
  Future<void> removeAnalysisResult(String imagePath) async {
    await _storageService.removeAnalysisResult(imagePath);
  }

  /// Obtiene resultados de análisis filtrados por un centro específico
  Future<Map<String, AnalysisResult>> getAnalysisResultsByCenter(int centerId) async {
    try {
      final Map<String, AnalysisResult> allResults = await getAllAnalysisResults();
      final Map<String, AnalysisResult> filteredResults = {};

      // Filtrar solo los resultados del centro especificado
      allResults.forEach((key, value) {
        // Incluir si el centerId coincide o si no tiene centerId asignado
        if (value.centerId == centerId || value.centerId == null) {
          filteredResults[key] = value;
        }
      });

      return filteredResults;
    } catch (e) {
      debugPrint('Error en getAnalysisResultsByCenter: $e');
      return {};
    }
  }

  /// Obtiene un mapa de conteo de objetos por tipo desde los resultados
  Map<String, int> getObjectCountsByType(Map<String, AnalysisResult> results) {
    final Map<String, int> counts = {};

    results.forEach((path, result) {
      for (var detection in result.detecciones) {
        final String className = detection['class'] ?? 'unknown';
        counts[className] = (counts[className] ?? 0) + 1;
      }
    });

    return counts;
  }

  /// Obtiene una lista de imágenes agrupadas por tipo de objeto
  Map<String, List<String>> getImagesByObjectType(Map<String, AnalysisResult> results) {
    final Map<String, List<String>> imagesByType = {};

    results.forEach((imagePath, result) {
      // Obtener conjunto de tipos únicos en esta imagen
      final Set<String> typesInImage = result.detecciones
          .map((detection) => detection['class'] as String? ?? 'unknown')
          .toSet();

      // Añadir la imagen a cada tipo encontrado
      for (var type in typesInImage) {
        if (!imagesByType.containsKey(type)) {
          imagesByType[type] = [];
        }
        imagesByType[type]!.add(imagePath);
      }
    });

    return imagesByType;
  }
}