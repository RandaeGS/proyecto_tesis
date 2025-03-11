import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../entities/analisysresult.dart';

class AnalysisStorageService {
  static const String analysisResultsKey = 'analysis_results';

  // Guardar un resultado de análisis
  Future<void> saveAnalysisResult(String imagePath, AnalysisResult result) async {
    final prefs = await SharedPreferences.getInstance();

    // Obtener resultados existentes
    final Map<String, dynamic> currentResults = await getAnalysisResults();

    // Guardar nuevo resultado
    currentResults[imagePath] = result.toJson();

    // Guardar en shared preferences
    await prefs.setString(analysisResultsKey, jsonEncode(currentResults));
  }

  // Cargar todos los resultados de análisis
  Future<Map<String, dynamic>> getAnalysisResults() async {
    final prefs = await SharedPreferences.getInstance();
    final String resultsJson = prefs.getString(analysisResultsKey) ?? '{}';
    return jsonDecode(resultsJson) as Map<String, dynamic>;
  }

  // Obtener un resultado específico
  Future<AnalysisResult?> getAnalysisResult(String imagePath) async {
    final Map<String, dynamic> results = await getAnalysisResults();

    if (results.containsKey(imagePath)) {
      return AnalysisResult.fromJsonMap(results[imagePath]);
    }

    return null;
  }

  // Eliminar un resultado
  Future<void> removeAnalysisResult(String imagePath) async {
    final prefs = await SharedPreferences.getInstance();

    final Map<String, dynamic> currentResults = await getAnalysisResults();
    currentResults.remove(imagePath);

    await prefs.setString(analysisResultsKey, jsonEncode(currentResults));
  }
}