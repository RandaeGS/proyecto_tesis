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
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final url = Uri.parse('$_baseUrl/analytics/by_center/?center_id=$centerId');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> reportsJson = json.decode(response.body);

        _reports = reportsJson.map((json) => AnalyticsReport.fromJson(json)).toList();

        // Sort by creation date (most recent first)
        _reports.sort((a, b) =>
            DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt))
        );

        // Reset selected report
        _selectedReport = null;
      } else {
        _errorMessage = 'Error al cargar reportes analíticos: ${response.statusCode}';
        debugPrint(_errorMessage);
      }
    } catch (e) {
      _errorMessage = 'Error al cargar reportes analíticos: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
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

      final url = Uri.parse('$_baseUrl/analytics/generate/');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        final reportJson = json.decode(response.body);
        final report = AnalyticsReport.fromJson(reportJson);

        // Reload reports to include the new one
        await loadReports(centerId);

        // Select the newly created report
        _selectedReport = report;

        return report;
      } else {
        _errorMessage = 'Error al generar reporte analítico: ${response.statusCode}';
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