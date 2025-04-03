import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../entities/analisysresult.dart';
import '../core/api_client.dart';
import '../core/api_constants.dart';
import '../core/storage_services.dart';

/// Servicio para analizar imágenes y manejar resultados
class ImageAnalysisService {
  final ApiClient _apiClient = ApiClient();
  final StorageService _storageService = StorageService();

  /// Prepara una imagen para el análisis, optimizando su formato sin deformaciones
  Future<File> _prepareImageForAnalysis(File imageFile) async {
    try {
      debugPrint('Preparando imagen para análisis: ${imageFile.path}');

      // Verificar si necesitamos procesar la imagen
      final fileExt = path.extension(imageFile.path).toLowerCase();

      // Si ya es un formato JPEG y su tamaño es razonable, podemos usarlo directamente
      final fileSize = await imageFile.length();
      if (fileExt == '.jpg' || fileExt == '.jpeg') {
        if (fileSize < 2 * 1024 * 1024) { // Menos de 2MB
          debugPrint('Usando imagen JPEG directamente: ${fileSize ~/ 1024} KB');
          return imageFile;
        }
      }

      // Crear un directorio temporal para guardar la imagen procesada
      final tempDir = await getTemporaryDirectory();
      final targetPath = path.join(tempDir.path,
          'analysis_${DateTime.now().millisecondsSinceEpoch}.jpg');

      // Usar compresión preservando calidad
      int quality = 95; // Alta calidad
      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.path,
        targetPath,
        quality: quality,
        keepExif: true, // Mantener metadatos de la imagen
        autoCorrectionAngle: true, // Corregir rotación automáticamente
      );

      if (result == null) {
        debugPrint('Error al comprimir imagen, usando original');
        return imageFile;
      }

      // Convertir XFile a File
      final compressedFile = File(result.path);

      final compressedSize = await compressedFile.length();
      debugPrint('Imagen preparada: ${compressedSize ~/ 1024} KB');

      return compressedFile;
    } catch (e) {
      debugPrint('Error preparando imagen: $e, usando original');
      return imageFile; // En caso de error, usar la imagen original
    }
  }

  /// Analiza una imagen usando el endpoint de la API sin guardar automáticamente
  Future<AnalysisResult> analyzeImage(File imageFile, String modelType, {int? centerId, bool saveToServer = true}) async {
    try {
      debugPrint('Analizando imagen con modelo $modelType, guardar=${saveToServer}');

      // Preparar la imagen para optimizar calidad
      final preparedImage = await _prepareImageForAnalysis(imageFile);

      // Campos adicionales para el análisis
      final fields = {
        'tipo_modelo': modelType,
        'guardar_imagen': saveToServer.toString(), // Parámetro de guardar o no
      };

      // Añadir centerId si está disponible
      if (centerId != null) {
        fields['center_id'] = centerId.toString();
      }

      // Enviar la imagen para análisis
      final data = await _apiClient.uploadFile(
        ApiConstants.analyzeImage,
        preparedImage.path,
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

  /// Confirma y guarda los resultados de análisis en el servidor
  /// Ahora con soporte para resultados modificados por el usuario
  Future<AnalysisResult> confirmAndSaveAnalysis(
      AnalysisResult result,
      File imageFile,
      {int? centerId, Map<String, dynamic>? modifiedResults}
      ) async {
    try {
      debugPrint('Confirmando y guardando análisis para imagen: ${imageFile.path}');

      // Preparar la imagen para optimizar calidad
      final preparedImage = await _prepareImageForAnalysis(imageFile);

      // Campos para la solicitud
      final fields = {
        'analysis_id': result.id,
        'guardar_imagen': 'true',  // Ahora sí queremos guardar
      };

      // Añadir centerId si está disponible
      if (centerId != null) {
        fields['center_id'] = centerId.toString();
      }

      // Si hay resultados modificados, agregarlos a los campos
      if (modifiedResults != null) {
        // Convertir modifiedResults a JSON y pasarlo como string en los campos
        fields['resultados_modificados'] = json.encode(modifiedResults);

        debugPrint('Enviando resultados modificados al servidor');
        debugPrint('Objetos en resultados modificados: ${modifiedResults['count']}');
      }

      // Endpoint para confirmar y guardar
      final endpoint = ApiConstants.confirmAnalysis;

      // Enviar solicitud al servidor
      final data = await _apiClient.uploadFile(
        endpoint,
        preparedImage.path,
        'imagen',
        fields,
        entityName: 'Confirmación',
        // En una implementación real, pasaríamos modifiedResults como body adicional
        // o como un campo de formulario serializado a JSON
      );

      // Actualizar el resultado local con los datos del servidor
      final updatedResult = AnalysisResult.fromJson(data);

      // Actualizar en almacenamiento local
      await _storageService.saveAnalysisResult(imageFile.path, updatedResult);

      return updatedResult;
    } catch (e) {
      debugPrint('Error en confirmAndSaveAnalysis: $e');
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