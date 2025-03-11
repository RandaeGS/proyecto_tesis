import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../entities/analisysresult.dart';
import '../../entities/center.dart' as app_center;
import '../../entities/user.dart';
import 'api_constants.dart';

/// Servicio centralizado para el almacenamiento local
class StorageService {
  static final StorageService _instance = StorageService._internal();

  factory StorageService() => _instance;

  StorageService._internal();

  /// Guarda la información de un usuario
  Future<void> saveUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ApiConstants.userKey, jsonEncode(user.toJson()));
      debugPrint('Usuario guardado: ${user.email}');
    } catch (e) {
      debugPrint('Error al guardar usuario: $e');
      rethrow;
    }
  }

  /// Recupera la información del usuario guardado
  Future<User?> getUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString(ApiConstants.userKey);

      if (userStr != null && userStr.isNotEmpty) {
        final userMap = jsonDecode(userStr) as Map<String, dynamic>;
        return User.fromJson(userMap);
      }
      return null;
    } catch (e) {
      debugPrint('Error al recuperar usuario: $e');
      return null;
    }
  }

  /// Guarda la información de un centro
  Future<void> saveCenter(app_center.Center center) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ApiConstants.centerKey, jsonEncode(center.toJson()));
      debugPrint('Centro guardado: ${center.name} (ID: ${center.id})');
    } catch (e) {
      debugPrint('Error al guardar centro: $e');
      rethrow;
    }
  }

  /// Recupera la información del centro guardado
  Future<app_center.Center?> getCenter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final centerStr = prefs.getString(ApiConstants.centerKey);

      if (centerStr != null && centerStr.isNotEmpty) {
        final centerMap = jsonDecode(centerStr) as Map<String, dynamic>;
        return app_center.Center.fromJson(centerMap);
      }
      return null;
    } catch (e) {
      debugPrint('Error al recuperar centro: $e');
      return null;
    }
  }

  /// Guarda un resultado de análisis
  Future<void> saveAnalysisResult(String imagePath, AnalysisResult result) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Obtener resultados almacenados actualmente
      final String resultsJson = prefs.getString(ApiConstants.analysisResultsKey) ?? '{}';
      final Map<String, dynamic> currentResults = jsonDecode(resultsJson) as Map<String, dynamic>;

      // Guardar el nuevo resultado
      currentResults[imagePath] = result.toJson();

      // Guardar todo de nuevo
      await prefs.setString(ApiConstants.analysisResultsKey, jsonEncode(currentResults));
      debugPrint('Resultado de análisis guardado para imagen: $imagePath');
    } catch (e) {
      debugPrint('Error al guardar resultado de análisis: $e');
      rethrow;
    }
  }

  /// Recupera todos los resultados de análisis
  Future<Map<String, dynamic>> getAnalysisResults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String resultsJson = prefs.getString(ApiConstants.analysisResultsKey) ?? '{}';
      return jsonDecode(resultsJson) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error al recuperar resultados de análisis: $e');
      return {};
    }
  }

  /// Recupera un resultado de análisis específico
  Future<AnalysisResult?> getAnalysisResult(String imagePath) async {
    try {
      final Map<String, dynamic> results = await getAnalysisResults();

      if (results.containsKey(imagePath)) {
        return AnalysisResult.fromJsonMap(results[imagePath]);
      }

      return null;
    } catch (e) {
      debugPrint('Error al recuperar resultado de análisis: $e');
      return null;
    }
  }

  /// Elimina un resultado de análisis
  Future<void> removeAnalysisResult(String imagePath) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Obtener resultados almacenados actualmente
      final String resultsJson = prefs.getString(ApiConstants.analysisResultsKey) ?? '{}';
      final Map<String, dynamic> currentResults = jsonDecode(resultsJson) as Map<String, dynamic>;

      // Eliminar el resultado
      currentResults.remove(imagePath);

      // Guardar todo de nuevo
      await prefs.setString(ApiConstants.analysisResultsKey, jsonEncode(currentResults));
      debugPrint('Resultado de análisis eliminado para imagen: $imagePath');
    } catch (e) {
      debugPrint('Error al eliminar resultado de análisis: $e');
      rethrow;
    }
  }

  /// Limpia toda la información de autenticación y usuario
  Future<void> clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ApiConstants.userKey);
      await prefs.remove(ApiConstants.centerKey);
      debugPrint('Datos de usuario y centro eliminados');
    } catch (e) {
      debugPrint('Error al limpiar datos de usuario: $e');
      rethrow;
    }
  }
}