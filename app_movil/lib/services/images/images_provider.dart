import 'dart:io';
import 'package:flutter/material.dart';
import '../../entities/analisysresult.dart';
import '../core/api_constants.dart';
import '../deteccion_services/image_analisys_service.dart';
import 'images_service.dart';

class ServerImageProvider with ChangeNotifier {
  final ImageService _imageService = ImageService();
  final ImageAnalysisService _analysisService = ImageAnalysisService();

  List<ServerImage> _centerImages = [];
  bool _isLoading = false;
  String _errorMessage = '';
  int? _currentCenterId;

  // Mapa para almacenar las detecciones por ID de imagen
  final Map<String, List<Map<String, dynamic>>> _imageDetections = {};

  // Mapa para almacenar los resultados de análisis por ID de imagen
  final Map<String, AnalysisResult> _analysisResults = {};

  // Lista para almacenar todas las detecciones del centro
  List<AnalysisResult> _centerDetections = [];

  // Getters
  List<ServerImage> get centerImages => _centerImages;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  int? get currentCenterId => _currentCenterId;
  Map<String, List<Map<String, dynamic>>> get imageDetections => _imageDetections;
  Map<String, AnalysisResult> get analysisResults => _analysisResults;
  List<AnalysisResult> get centerDetections => _centerDetections;

  // Carga las imágenes del centro actual
  Future<void> loadCenterImages(int centerId) async {
    _isLoading = true;
    _errorMessage = '';
    _currentCenterId = centerId;
    notifyListeners();

    try {
      // Cargar imágenes del centro
      final images = await _imageService.getCenterImages(centerId);
      _centerImages = images;

      // Cargar detecciones para cada imagen (para compatibilidad)
      await _loadDetectionsForImages();

      // Cargar todas las detecciones del centro
      await loadDetectionsByCenter(centerId);
    } catch (e) {
      _errorMessage = 'Error al cargar imágenes: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Carga las detecciones para todas las imágenes
  Future<void> _loadDetectionsForImages() async {
    for (var image in _centerImages) {
      try {
        if (image.processed) {
          await loadImageDetections(image.id);
        }
      } catch (e) {
        debugPrint('Error al cargar detecciones para imagen ${image.id}: $e');
      }
    }
  }

  // Carga las detecciones para una imagen específica
  Future<void> loadImageDetections(String imageId) async {
    try {
      final detections = await _imageService.getImageDetections(imageId);

      if (detections.isNotEmpty) {
        _imageDetections[imageId] = detections;

        // Convertir la primera detección a un objeto AnalysisResult
        if (detections.isNotEmpty) {
          final detection = detections.first;
          final result = AnalysisResult.fromJson({
            'deteccion_id': detection['id'],
            'tipo_modelo': detection['tipo_modelo'],
            'tiempo_procesamiento': 0.0,
            'resultados': detection['resultados']
          });

          _analysisResults[imageId] = result;
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error al cargar detecciones para imagen $imageId: $e');
    }
  }

  AnalysisResult? getBestAnalysisForImage(String imageId) {
    // Primero buscar en las detecciones del centro (que contienen el tiempo correcto)
    for (var detection in _centerDetections) {
      if (detection.imageId == imageId) {
        debugPrint('Encontrado análisis completo para imagen $imageId en centerDetections');
        return detection;
      }
    }

    // Como respaldo, usar el mapa de análisis (que podría tener tiempo=0)
    final fallbackResult = _analysisResults[imageId];
    if (fallbackResult != null) {
      debugPrint('Usando análisis de respaldo para imagen $imageId');
    }

    return fallbackResult;
  }

  // Carga todas las detecciones de un centro específico
  Future<void> loadDetectionsByCenter(int centerId) async {
    try {
      final endpoint = '${ApiConstants.detectionsByCenter}?center_id=$centerId';
      debugPrint('Solicitando detecciones por centro: $endpoint');

      final data = await _imageService.getApiClient().get(
        endpoint,
        entityName: 'Detecciones por centro',
      );

      _centerDetections = [];

      if (data is List) {
        debugPrint('Recibidos ${data.length} resultados de detecciones');
        for (var item in data) {
          try {
            final result = AnalysisResult.fromJson(item);

            // Añadir esto para depuración
            debugPrint('Detección ID: ${result.id}, Image ID: ${result.imageId}, Center ID: ${result.centerId}');

            _centerDetections.add(result);
          } catch (e) {
            debugPrint('Error al procesar resultado de análisis: $e');
          }
        }
      } else {
        debugPrint('La respuesta no es una lista: ${data.runtimeType}');
      }

      debugPrint('Cargadas ${_centerDetections.length} detecciones para el centro $centerId');
      notifyListeners();
    } catch (e) {
      debugPrint('Error al cargar detecciones por centro: $e');
    }
  }

  // Sube una nueva imagen
  Future<ServerImage?> uploadImage(
      String imagePath,
      int centerId,
      {Map<String, String>? additionalFields}
      ) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final uploadedImage = await _imageService.uploadImage(
          imagePath,
          centerId,
          additionalFields: additionalFields
      );

      // Añadir la imagen a la lista
      _centerImages.add(uploadedImage);

      _isLoading = false;
      notifyListeners();
      return uploadedImage;
    } catch (e) {
      _errorMessage = 'Error al subir imagen: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Analiza una imagen usando el API
  Future<AnalysisResult?> analyzeImage(
      File imageFile,
      String modelType,
      {int? centerId}
      ) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final result = await _analysisService.analyzeImage(
        imageFile,
        modelType,
        centerId: centerId,
      );

      // Recargar las imágenes del centro para obtener la actualizada
      if (centerId != null) {
        await loadCenterImages(centerId);
      }

      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = 'Error al analizar imagen: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Elimina una imagen del servidor
  Future<bool> deleteImage(String imageId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await _imageService.deleteImage(imageId);

      // Eliminar la imagen de la lista local
      _centerImages.removeWhere((image) => image.id == imageId);

      // Eliminar las detecciones asociadas
      _imageDetections.remove(imageId);
      _analysisResults.remove(imageId);

      // Recargar detecciones del centro si hay un centro activo
      if (_currentCenterId != null) {
        await loadDetectionsByCenter(_currentCenterId!);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al eliminar imagen: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Obtiene la URL completa de una imagen
  String getImageUrl(String filePath) {
    return _imageService.getImageUrl(filePath);
  }

  // Procesa los datos para obtener conteo de productos por categoría
  Map<String, int> getProductCounts() {
    // Conteo de productos por categoría
    final Map<String, int> counts = {};

    // Iterar sobre todas las detecciones del centro
    for (var result in _centerDetections) {
      for (var detection in result.detecciones) {
        final String className = detection['class'] ?? 'unknown';
        counts[className] = (counts[className] ?? 0) + 1;
      }
    }

    return counts;
  }

  // Obtiene las categorías de productos únicas
  List<String> getProductCategories() {
    final Set<String> categories = {};

    // Iterar sobre todas las detecciones del centro
    for (var result in _centerDetections) {
      for (var detection in result.detecciones) {
        final String className = detection['class'] ?? 'unknown';
        categories.add(className);
      }
    }

    final categoriesList = categories.toList()..sort();
    return categoriesList;
  }

// Obtiene las imágenes que contienen una categoría específica
  List<ServerImage> getImagesForCategory(String category) {
    // Lista de IDs de imágenes que contienen esta categoría
    final Set<String> imageIds = {};

    // Recorrer todas las detecciones para encontrar aquellas que contienen la categoría
    for (var detection in _centerDetections) {
      // Verificar si esta detección contiene la categoría
      bool hasCategory = detection.detecciones.any((item) =>
      (item['class'] ?? 'unknown') == category
      );

      // Si la detección contiene la categoría y tiene un image_id
      if (hasCategory && detection.imageId != null) {
        imageIds.add(detection.imageId!);
        debugPrint('Detección ${detection.id} con categoría $category está asociada a imagen ${detection.imageId}');
      }
    }

    // Filtrar las imágenes por los IDs encontrados
    final List<ServerImage> imagesWithCategory = _centerImages
        .where((image) => imageIds.contains(image.id))
        .toList();

    // Log para depuración
    debugPrint('Se encontraron ${imagesWithCategory.length} imágenes para la categoría $category');

    // Si no se encontraron imágenes, devolver todas las del centro como fallback
    if (imagesWithCategory.isEmpty) {
      debugPrint('No se encontraron imágenes específicas para $category, mostrando todas las del centro');
      return _centerImages;
    }

    return imagesWithCategory;
  }
}