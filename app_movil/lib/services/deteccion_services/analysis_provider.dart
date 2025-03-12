import 'dart:io';
import 'package:flutter/material.dart';

import '../../entities/analisysresult.dart';
import 'image_analisys_service.dart';


/// Provider para manejar operaciones y estado de análisis de imágenes
class AnalysisProvider with ChangeNotifier {
  final ImageAnalysisService _analysisService = ImageAnalysisService();

  Map<String, AnalysisResult> _analysisResults = {};
  bool _isLoading = false;
  String _errorMessage = '';
  String _selectedModel = "yolo";

  // Getters
  Map<String, AnalysisResult> get analysisResults => _analysisResults;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get selectedModel => _selectedModel;

  /// Cambia el modelo seleccionado para análisis
  void setSelectedModel(String model) {
    _selectedModel = model;
    notifyListeners();
  }

  /// Carga todos los resultados de análisis guardados
  Future<void> loadAnalysisResults() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _analysisResults = await _analysisService.getAllAnalysisResults();
    } catch (e) {
      _errorMessage = 'Error al cargar resultados: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Carga resultados de análisis de un centro específico
  Future<void> loadAnalysisResultsByCenter(int centerId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _analysisResults = await _analysisService.getAnalysisResultsByCenter(centerId);
    } catch (e) {
      _errorMessage = 'Error al cargar resultados del centro: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Analiza una imagen usando el modelo seleccionado
  Future<AnalysisResult?> analyzeImage(File imageFile, {int? centerId}) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final result = await _analysisService.analyzeImage(
        imageFile,
        _selectedModel,
        centerId: centerId,
      );

      // Actualizar resultados almacenados
      _analysisResults[imageFile.path] = result;

      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = 'Error al analizar imagen: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Elimina un resultado de análisis
  Future<void> removeAnalysisResult(String imagePath) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _analysisService.removeAnalysisResult(imagePath);
      _analysisResults.remove(imagePath);
    } catch (e) {
      _errorMessage = 'Error al eliminar resultado: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Obtiene conteos de objetos por tipo
  Map<String, int> getObjectCounts() {
    return _analysisService.getObjectCountsByType(_analysisResults);
  }

  /// Obtiene imágenes agrupadas por tipo de objeto
  Map<String, List<String>> getImagesByObjectType() {
    return _analysisService.getImagesByObjectType(_analysisResults);
  }

  /// Obtiene todas las categorías únicas de objetos
  List<String> getObjectCategories() {
    final Map<String, int> counts = getObjectCounts();
    return counts.keys.toList()..sort();
  }
}