import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../entity/inventory_report.dart';
import '../entity/inventory_snapshot.dart';
import '../../services/config.dart';

class InventoryReportProvider with ChangeNotifier {
  final _baseUrl = '${AppConfig.getApiUrl()}/inventory/api';
  String? _authToken;

  List<InventoryReport> _reports = [];
  InventoryReport? _selectedReport;
  bool _isLoading = false;
  String _errorMessage = '';

  // Mapa para almacenar las cantidades ideales actuales
  // Esto nos permitirá comparar con los informes existentes
  Map<String, int> _currentIdealCounts = {};

  // Getters
  List<InventoryReport> get reports => _reports;
  InventoryReport? get selectedReport => _selectedReport;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  // Getter para obtener productos prioritarios (con prioridad > 3)
  Map<String, ProductReplenishmentInfo> get priorityProducts {
    final latestReport = getLatestReport();
    if (latestReport == null) return {};
    return latestReport.getPriorityProducts();
  }

  /// Sets the authentication token to use for API requests
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// Load analytics reports for a specific center
  Future<void> loadReports(int centerId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final url = Uri.parse('$_baseUrl/reports/by_center/?center_id=$centerId');

      debugPrint('Loading inventory reports from: $url');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      debugPrint('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        List<dynamic> reportsJson;
        try {
          reportsJson = json.decode(response.body);
        } catch (e) {
          debugPrint('Error parsing JSON: $e');
          throw Exception('Error decoding response: $e');
        }

        // Lista temporal para almacenar los reportes procesados
        final List<InventoryReport> tempReports = [];

        // Procesar cada reporte individualmente
        for (var reportJson in reportsJson) {
          try {
            final report = InventoryReport.fromJson(reportJson);
            tempReports.add(report);
          } catch (e) {
            debugPrint('Error parsing report: $e');
          }
        }

        // Actualizar la lista principal
        _reports = tempReports;

        // Sort by creation date (most recent first)
        _reports.sort((a, b) =>
            DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt))
        );

        // Reset selected report
        _selectedReport = null;
      } else {
        _errorMessage = 'Error al cargar informes de inventario: ${response.statusCode}';
        debugPrint(_errorMessage);
      }
    } catch (e) {
      _errorMessage = 'Error al cargar informes de inventario: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Generate an inventory report
  Future<InventoryReport?> generateReport(
      InventorySnapshot snapshot, {
        bool isEmergency = false,
        Map<String, int> customIdealCounts = const {},
      }) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // Almacenar las cantidades ideales para uso futuro
      _currentIdealCounts = Map.from(customIdealCounts);

      // Prepare data for API
      final data = {
        'snapshot_id': snapshot.id,
        'is_emergency': isEmergency,
        'custom_ideal_counts': customIdealCounts,
      };

      debugPrint('Generating report with data: $data');
      final url = Uri.parse('$_baseUrl/reports/generate/');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: json.encode(data),
      );

      debugPrint('Response status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        Map<String, dynamic> reportJson = json.decode(response.body);
        final report = InventoryReport.fromJson(reportJson);

        // Add to local reports list
        _reports.insert(0, report); // Add at the beginning
        _selectedReport = report;

        notifyListeners();
        return report;
      } else {
        _errorMessage = 'Error al generar informe: ${response.statusCode}';
        debugPrint(_errorMessage);
        debugPrint('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      _errorMessage = 'Error al generar informe: $e';
      debugPrint(_errorMessage);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete an inventory report
  Future<bool> deleteReport(int centerId, String reportId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final url = Uri.parse('$_baseUrl/reports/$reportId/');

      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 204) {
        // Update local list
        _reports.removeWhere((report) => report.id == reportId);

        // If the deleted report was the selected one, clear selection
        if (_selectedReport?.id == reportId) {
          _selectedReport = null;
        }

        notifyListeners();
        return true;
      } else {
        _errorMessage = 'No se pudo eliminar el informe: ${response.statusCode}';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error al eliminar informe: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Select a specific report
  void selectReport(InventoryReport report) {
    _selectedReport = report;
    notifyListeners();
  }

  /// Clear the current selection
  void clearSelection() {
    _selectedReport = null;
    notifyListeners();
  }

  /// Get the latest report
  InventoryReport? getLatestReport() {
    if (_reports.isEmpty) return null;
    return _reports.first; // Already sorted by date
  }

  /// Update ideal counts in all reports
  /// Esta función actualiza las cantidades ideales en todos los informes
  void updateIdealCountsInReports(Map<String, int> newIdealCounts) {
    // Guarda los nuevos valores ideales
    _currentIdealCounts = Map.from(newIdealCounts);

    debugPrint('Actualizando cantidades ideales en informes: $newIdealCounts');

    // Actualiza cada informe
    for (var i = 0; i < _reports.length; i++) {
      final report = _reports[i];

      // Crea un nuevo mapa para las recomendaciones actualizadas
      final updatedRecommendations = <String, ProductReplenishmentInfo>{};

      // Actualiza cada recomendación de producto
      report.productRecommendations.forEach((category, info) {
        // Si hay un nuevo valor ideal para esta categoría
        if (newIdealCounts.containsKey(category)) {
          // Crea una nueva recomendación con el valor ideal actualizado
          updatedRecommendations[category] = ProductReplenishmentInfo(
            category: category,
            currentCount: info.currentCount, // Mantener el conteo actual
            idealCount: newIdealCounts[category]!, // Actualizar el conteo ideal
            priority: _calculateNewPriority(info.currentCount, newIdealCounts[category]!), // Recalcular prioridad
            note: info.note,
            categoryId: info.categoryId,
          );
        } else {
          // Mantener la recomendación original si no hay un nuevo valor ideal
          updatedRecommendations[category] = info;
        }
      });

      // Crea un nuevo informe con las recomendaciones actualizadas
      _reports[i] = InventoryReport(
        id: report.id,
        name: report.name,
        createdAt: report.createdAt,
        centerId: report.centerId,
        productRecommendations: updatedRecommendations,
        isEmergency: report.isEmergency,
        sourceSnapshotId: report.sourceSnapshotId,
      );

      // Actualiza el informe seleccionado si es necesario
      if (_selectedReport?.id == report.id) {
        _selectedReport = _reports[i];
      }
    }

    // Notifica a los oyentes sobre los cambios
    notifyListeners();

    debugPrint('Informes actualizados con nuevas cantidades ideales');
  }

  /// Calcular nueva prioridad basada en la diferencia entre actual e ideal
  int _calculateNewPriority(int currentCount, int idealCount) {
    if (idealCount == 0) return 1; // Evitar división por cero

    // Calcular el porcentaje faltante
    final percentageMissing = ((idealCount - currentCount) / idealCount) * 100;

    // Asignar prioridad basada en el porcentaje faltante
    if (percentageMissing <= 10) return 1;
    if (percentageMissing <= 30) return 2;
    if (percentageMissing <= 50) return 3;
    if (percentageMissing <= 75) return 4;
    return 5; // Más del 75% faltante
  }


  Future<bool> saveIdealCounts(int centerId, Map<String, int> idealCounts) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // Imprimir las categorías y valores ideales actuales para depuración
      debugPrint('Guardando valores ideales: $idealCounts');

      // Antes de guardar, veamos si realmente hay cambios que hacer
      bool hasChanges = false;

      // Primero cargamos los valores ideales actuales del backend para comparar
      // O alternativamente usa el endpoint with_ideal_counts
      final url = Uri.parse('${AppConfig.getApiUrl()}/inventory/api/categories/with_ideal_counts/');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> currentIdealCounts = json.decode(response.body);

        // Comparar los valores actuales con los nuevos
        idealCounts.forEach((category, newCount) {
          final currentCount = currentIdealCounts[category];
          if (currentCount != newCount) {
            hasChanges = true;
            debugPrint('Cambio detectado en $category: $currentCount -> $newCount');
          }
        });
      }

      if (!hasChanges) {
        debugPrint('No se detectaron cambios en los valores ideales, continuando de todas formas');
      }

      // Guardamos los valores ideales en las categorías
      final updateUrl = Uri.parse('${AppConfig.getApiUrl()}/inventory/api/categories/update_ideal_counts/');
      final updateResponse = await http.post(
        updateUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: json.encode(idealCounts),
      );

      debugPrint('Response status: ${updateResponse.statusCode}');
      debugPrint('Response body: ${updateResponse.body}');

      bool success = updateResponse.statusCode == 200 || updateResponse.statusCode == 201;

      // Actualizamos los informes en memoria sin importar el resultado del servidor
      updateIdealCountsInReports(idealCounts);

      // Ahora actualizamos las recomendaciones en el backend
      // IMPORTANTE: Incluso si no hay cambios detectados, forzamos la actualización para asegurar consistencia
      await _updateRecommendationsInBackendFixed(idealCounts);

      // Guardamos los valores en SharedPreferences para respaldo
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ideal_counts_$centerId', json.encode(idealCounts));

      return success;
    } catch (e) {
      _errorMessage = 'Error al guardar configuración: $e';
      debugPrint(_errorMessage);

      // Aún actualizamos localmente como respaldo
      updateIdealCountsInReports(idealCounts);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ideal_counts_$centerId', json.encode(idealCounts));

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

// Este método actualiza TODAS las recomendaciones sin comparar los valores ideales anteriores
  Future<void> _updateRecommendationsInBackendFixed(Map<String, int> idealCounts) async {
    if (_reports.isEmpty) {
      debugPrint('No hay informes para actualizar en el backend');
      return;
    }

    debugPrint('Actualizando recomendaciones en el backend para ${_reports.length} informes');

    // Para cada informe, enviaremos las actualizaciones de recomendaciones forzadas
    for (var report in _reports) {
      try {
        final recommendations = <Map<String, dynamic>>[];

        // Para cada categoría en los valores ideales
        idealCounts.forEach((categoryName, newIdealCount) {
          // Buscar si esta categoría está en las recomendaciones del informe
          if (report.productRecommendations.containsKey(categoryName)) {
            final info = report.productRecommendations[categoryName]!;

            // Calcular nueva prioridad
            final newPriority = _calculateNewPriority(info.currentCount, newIdealCount);

            // FORZAR LA ACTUALIZACIÓN sin comparar con el valor anterior
            recommendations.add({
              'category': info.categoryId, // ID de la categoría
              'ideal_count': newIdealCount,
              'current_count': info.currentCount,
              'priority': newPriority,
              'note': info.note,
            });

            debugPrint('Forzando actualización para $categoryName en informe ${report.id}');
          }
        });

        if (recommendations.isEmpty) {
          debugPrint('No se encontraron categorías para actualizar en el informe ${report.id}');
          continue;
        }

        // Construir URL para actualizar las recomendaciones
        final url = Uri.parse('${AppConfig.getApiUrl()}/inventory/api/reports/${report.id}/update_recommendations/');

        debugPrint('Enviando ${recommendations.length} actualizaciones para el informe ${report.id}');

        // Realizar la petición PATCH
        final response = await http.patch(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_authToken',
          },
          body: json.encode({'recommendations': recommendations}),
        );

        if (response.statusCode == 200 || response.statusCode == 204) {
          final responseData = json.decode(response.body);
          debugPrint('Actualización exitosa. Actualizados: ${responseData['updated_count']}');
          if (responseData['errors'] != null && responseData['errors'].isNotEmpty) {
            debugPrint('Errores: ${responseData['errors']}');
          }
        } else {
          debugPrint('Error: ${response.statusCode}, ${response.body}');
        }
      } catch (e) {
        debugPrint('Error al actualizar informe ${report.id}: $e');
      }
    }
  }

  Future<Map<String, int>> loadIdealCounts(int centerId) async {
    // Si ya tenemos valores en memoria, los devolvemos
    if (_currentIdealCounts.isNotEmpty) {
      debugPrint('Devolviendo valores ideales de memoria: $_currentIdealCounts');
      return _currentIdealCounts;
    }

    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // Primero intentamos cargar desde el endpoint correcto
      final url = Uri.parse('${AppConfig.getApiUrl()}/inventory/api/categories/with_ideal_counts/');
      debugPrint('Intentando cargar valores ideales desde: $url');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      debugPrint('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Aquí el backend devuelve directamente un objeto {category_name: ideal_count, ...}
        final Map<String, dynamic> data = json.decode(response.body);
        final Map<String, int> idealCounts = {};

        // Convertir valores a enteros
        data.forEach((key, value) {
          idealCounts[key] = value is int ? value : int.tryParse(value.toString()) ?? 0;
        });

        debugPrint('Valores ideales cargados desde backend: $idealCounts');

        // Guardar en memoria y en SharedPreferences
        _currentIdealCounts = idealCounts;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('ideal_counts_$centerId', json.encode(idealCounts));

        return idealCounts;
      } else if (response.statusCode == 404) {
        debugPrint('ERROR 404: Endpoint no encontrado. Intentando URL alternativa...');

        // Intentar con una URL alternativa (sin "inventory/api")
        final alternativeUrl = Uri.parse('${AppConfig.getApiUrl()}/categories/with_ideal_counts/');
        debugPrint('Intentando URL alternativa: $alternativeUrl');

        try {
          final altResponse = await http.get(
            alternativeUrl,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_authToken',
            },
          );

          debugPrint('Respuesta alternativa status: ${altResponse.statusCode}');

          if (altResponse.statusCode == 200) {
            final Map<String, dynamic> altData = json.decode(altResponse.body);
            final Map<String, int> altIdealCounts = {};

            altData.forEach((key, value) {
              altIdealCounts[key] = value is int ? value : int.tryParse(value.toString()) ?? 0;
            });

            _currentIdealCounts = altIdealCounts;

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('ideal_counts_$centerId', json.encode(altIdealCounts));

            return altIdealCounts;
          }
        } catch (e) {
          debugPrint('Error con URL alternativa: $e');
        }

        // Si llegamos aquí, ambos intentos fallaron
        return _loadFromSharedPreferences(centerId);
      } else {
        // Cualquier otro error, intentar cargar desde SharedPreferences
        debugPrint('Error al cargar desde backend: ${response.statusCode}');
        return _loadFromSharedPreferences(centerId);
      }
    } catch (e) {
      _errorMessage = 'Error al cargar configuración: $e';
      debugPrint(_errorMessage);

      // Si falla, cargar desde SharedPreferences
      return _loadFromSharedPreferences(centerId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

// Método auxiliar para cargar desde SharedPreferences
  Future<Map<String, int>> _loadFromSharedPreferences(int centerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedConfig = prefs.getString('ideal_counts_$centerId');

      if (savedConfig != null && savedConfig.isNotEmpty) {
        debugPrint('Cargando configuración desde SharedPreferences');
        final Map<String, dynamic> savedMap = json.decode(savedConfig);
        final Map<String, int> idealCounts = {};

        savedMap.forEach((key, value) {
          idealCounts[key] = value is int ? value : int.tryParse(value.toString()) ?? 0;
        });

        // Guardar en memoria
        _currentIdealCounts = idealCounts;

        debugPrint('Valores ideales cargados desde SharedPreferences: $idealCounts');
        return idealCounts;
      }

      debugPrint('No se encontraron valores ideales guardados en SharedPreferences');
      return {};
    } catch (e) {
      debugPrint('Error al cargar desde SharedPreferences: $e');
      return {};
    }
  }

}