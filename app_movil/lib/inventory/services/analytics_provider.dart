import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../entity/analytics_report.dart';
import '../entity/inventory_snapshot.dart';
import '../../services/config.dart';

class AnalyticsProvider with ChangeNotifier {
  final _baseUrl = '${AppConfig.getApiUrl()}/inventory/api';
  String? _authToken;

  List<AnalyticsReport> _reports = [];
  AnalyticsReport? _selectedReport;
  bool _isLoading = false;
  String _errorMessage = '';

  // Getters
  List<AnalyticsReport> get reports => _reports;
  AnalyticsReport? get selectedReport => _selectedReport;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  /// Converts PeriodType enum to string for API
  String _periodTypeToString(PeriodType periodType) {
    switch (periodType) {
      case PeriodType.weekly:
        return 'weekly';
      case PeriodType.monthly:
        return 'monthly';
      default:
        return 'weekly'; // Default to weekly
    }
  }

  /// Sets the authentication token to use for API requests
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// Load analytics reports for a specific center
  Future<void> loadReports(int centerId) async {
    // IMPORTANTE: No llamar a notifyListeners aquí - puede causar error en el build
    // Sólo actualizamos internamente el estado
    _isLoading = true;
    _errorMessage = '';

    try {
      final url = Uri.parse('$_baseUrl/analytics/by_center/?center_id=$centerId');

      debugPrint('Loading analytics reports from: $url');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      debugPrint('Response status: ${response.statusCode}');
      // Limitar la longitud del log para evitar problemas
      final responsePreview = response.body.length > 500
          ? '${response.body.substring(0, 500)}...'
          : response.body;
      debugPrint('Response body: $responsePreview');

      if (response.statusCode == 200) {
        // Intentar decodificar con manejo de errores
        List<dynamic> reportsJson;
        try {
          reportsJson = json.decode(response.body);
        } catch (e) {
          debugPrint('Error parsing JSON: $e');
          throw Exception('Error decoding response: $e');
        }

        // Lista temporal para almacenar los reportes procesados
        final List<AnalyticsReport> tempReports = [];

        // Procesar cada reporte individualmente
        for (var reportJson in reportsJson) {
          try {
            final report = AnalyticsReport.fromJson(reportJson);
            tempReports.add(report);
          } catch (e) {
            // Registrar error pero continuar con otros reportes
            debugPrint('Error parsing report: $e');
          }
        }

        // Actualizar la lista principal sólo si hubo éxito
        if (tempReports.isNotEmpty) {
          _reports = tempReports;

          // Sort by creation date (most recent first)
          _reports.sort((a, b) =>
              DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt))
          );

          // Reset selected report
          _selectedReport = null;
        } else {
          _errorMessage = 'No se pudieron procesar los reportes';
        }
      } else {
        _errorMessage = 'Error al cargar reportes analíticos: ${response.statusCode}';
        debugPrint(_errorMessage);
      }
    } catch (e) {
      _errorMessage = 'Error al cargar reportes analíticos: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      // Ahora que todo el procesamiento ha terminado, notificamos
      notifyListeners();
    }
  }

  /// Generate a consumption report
  Future<AnalyticsReport?> generateConsumptionReport({
    required int centerId,
    required InventorySnapshot startSnapshot,
    required InventorySnapshot endSnapshot,
    required PeriodType periodType,
    required List<String> selectedCategories,
    String? reportName,
  }) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // Prepare data for API
      final data = {
        'start_snapshot_id': startSnapshot.id,
        'end_snapshot_id': endSnapshot.id,
        'period_type': _periodTypeToString(periodType), // Convert enum to string
        'selected_categories': selectedCategories,
        if (reportName != null && reportName.isNotEmpty) 'report_name': reportName,
      };

      debugPrint('Generating report with data: $data');
      final url = Uri.parse('$_baseUrl/analytics/generate/');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: json.encode(data),
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        // Parsear con manejo de excepciones seguro
        Map<String, dynamic> reportJson;
        try {
          reportJson = json.decode(response.body);
          debugPrint('Report JSON: $reportJson');
        } catch (e) {
          debugPrint('Error parsing JSON response: $e');
          throw Exception('Invalid JSON response: $e');
        }

        // Manejar explícitamente campos problemáticos
        // Asegurarnos de que categories exista
        if (reportJson['categories'] == null) {
          if (reportJson['consumption_totals'] is List) {
            final categoryNames = <String>[];
            for (var total in reportJson['consumption_totals']) {
              if (total['category_name'] != null) {
                categoryNames.add(total['category_name']);
              }
            }
            reportJson['categories'] = categoryNames;
          } else {
            reportJson['categories'] = []; // Valor predeterminado
          }
        }

        // Crear el reporte
        try {
          final report = AnalyticsReport.fromJson(reportJson);

          // Debug output to verify data was correctly parsed
          debugPrint('Parsed report: ${report.name}');
          debugPrint('Categories: ${report.categories}');
          debugPrint('Total consumption: ${report.totalConsumption}');
          debugPrint('Consumption data points: ${report.consumptionData.keys.length}');

          // Reload reports to include the new one
          await loadReports(centerId);

          // Select the newly created report
          _selectedReport = report;

          return report;
        } catch (e) {
          debugPrint('Error creating AnalyticsReport object: $e');
          throw Exception('Error creating report object: $e');
        }
      } else {
        _errorMessage = 'Error al generar reporte analítico: ${response.statusCode} - ${response.body}';
        debugPrint(_errorMessage);
        return null;
      }
    } catch (e) {
      _errorMessage = 'Error al generar reporte analítico: $e';
      debugPrint(_errorMessage);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete an analytics report
  Future<bool> deleteReport(int centerId, String reportId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final url = Uri.parse('$_baseUrl/analytics/$reportId/');

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
        _errorMessage = 'No se pudo eliminar el reporte: ${response.statusCode}';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error al eliminar reporte: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Select a specific report
  void selectReport(AnalyticsReport report) {
    _selectedReport = report;
    notifyListeners();
  }

  /// Clear the current selection
  void clearSelection() {
    _selectedReport = null;
    notifyListeners();
  }

  /// Get reports filtered by period type
  List<AnalyticsReport> getReportsByPeriodType(PeriodType periodType) {
    final periodTypeStr = _periodTypeToString(periodType);
    return _reports.where((report) => report.periodType == periodTypeStr).toList();
  }

  /// Get reports that include a specific category
  List<AnalyticsReport> getReportsByCategory(String category) {
    return _reports.where((report) => report.categories.contains(category)).toList();
  }

  /// Get the latest report
  AnalyticsReport? getLatestReport() {
    if (_reports.isEmpty) return null;
    return _reports.first; // Already sorted by date
  }
}