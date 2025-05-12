import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
}