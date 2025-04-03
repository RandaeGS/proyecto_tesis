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

  // Almacena temporalmente el resultado pendiente de confirmación
  AnalysisResult? _pendingResult;
  File? _pendingImageFile;

  // Almacena las modificaciones del usuario a las detecciones
  Map<String, dynamic>? _modifiedResults;

  // Getters
  Map<String, AnalysisResult> get analysisResults => _analysisResults;

  bool get isLoading => _isLoading;

  String get errorMessage => _errorMessage;

  String get selectedModel => _selectedModel;

  AnalysisResult? get pendingResult => _pendingResult;

  File? get pendingImageFile => _pendingImageFile;

  Map<String, dynamic>? get modifiedResults => _modifiedResults;

  /// Cambia el modelo seleccionado para análisis
  void setSelectedModel(String model) {
    _selectedModel = model;
    notifyListeners();
  }

  /// Guarda los resultados modificados por el usuario
  void setModifiedResults(Map<String, dynamic> modified) {
    _modifiedResults = modified;
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
      _analysisResults =
      await _analysisService.getAnalysisResultsByCenter(centerId);
    } catch (e) {
      _errorMessage = 'Error al cargar resultados del centro: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Analiza una imagen usando el modelo seleccionado sin guardar automáticamente
  Future<AnalysisResult?> analyzeImage(File imageFile,
      {int? centerId, bool saveToServer = false}) async {
    _isLoading = true;
    _errorMessage = '';
    _pendingResult = null;
    _pendingImageFile = null;
    _modifiedResults = null; // Limpiar modificaciones pendientes
    notifyListeners();

    try {
      final result = await _analysisService.analyzeImage(
          imageFile,
          _selectedModel,
          centerId: centerId,
          saveToServer: saveToServer
      );

      // Guardar temporalmente el resultado y la imagen para confirmar
      if (!saveToServer) {
        _pendingResult = result;
        _pendingImageFile = imageFile;
      }

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

  /// Confirma y guarda el resultado de análisis pendiente con posibles modificaciones
  Future<AnalysisResult?> confirmAnalysis({int? centerId}) async {
    if (_pendingResult == null || _pendingImageFile == null) {
      _errorMessage = 'No hay resultado pendiente para confirmar';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // Si hay modificaciones, aplicarlas al resultado antes de guardar
      AnalysisResult resultToSave = _pendingResult!;

      if (_modifiedResults != null) {
        // Crear una copia del resultado con las modificaciones
        // En una implementación real, aquí aplicaríamos todas las modificaciones
        // del usuario al resultado antes de enviarlo al servidor
        debugPrint(
            'Aplicando modificaciones del usuario al resultado antes de confirmar');

        // Aquí simularemos la actualización del resultToSave con _modifiedResults
        // En una implementación completa, esto modificaría las detecciones y conteos
      }

      final updatedResult = await _analysisService.confirmAndSaveAnalysis(
          resultToSave,
          _pendingImageFile!,
          centerId: centerId,
          modifiedResults: _modifiedResults
      );

      // Actualizar resultados almacenados
      _analysisResults[_pendingImageFile!.path] = updatedResult;

      // Limpiar pendientes
      _pendingResult = null;
      _pendingImageFile = null;
      _modifiedResults = null;

      _isLoading = false;
      notifyListeners();
      return updatedResult;
    } catch (e) {
      _errorMessage = 'Error al confirmar análisis: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Cancela el resultado de análisis pendiente
  void cancelPendingAnalysis() {
    _pendingResult = null;
    _pendingImageFile = null;
    _modifiedResults = null;
    notifyListeners();
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
    return counts.keys.toList()
      ..sort();
  }
}