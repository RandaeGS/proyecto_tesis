import 'dart:io';
import 'package:flutter/material.dart';
import '../../entities/analisysresult.dart';
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

  // Getters
  List<ServerImage> get centerImages => _centerImages;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  int? get currentCenterId => _currentCenterId;
  Map<String, List<Map<String, dynamic>>> get imageDetections => _imageDetections;
  Map<String, AnalysisResult> get analysisResults => _analysisResults;

  // Carga las imágenes del centro actual
  Future<void> loadCenterImages(int centerId) async {
    _isLoading = true;
    _errorMessage = '';
    _currentCenterId = centerId;
    notifyListeners();

    try {
      final images = await _imageService.getCenterImages(centerId);
      _centerImages = images;

      // Cargar detecciones para cada imagen
      await _loadDetectionsForImages();
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
}