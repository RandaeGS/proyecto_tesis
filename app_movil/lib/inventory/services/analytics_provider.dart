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

  List<AnalyticsReport> get reports => _reports;
  AnalyticsReport? get selectedReport => _selectedReport;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  String _periodTypeToString(PeriodType periodType) {
    switch (periodType) {
      case PeriodType.weekly:
        return 'weekly';
      case PeriodType.monthly:
        return 'monthly';
      default:
        return 'weekly';
    }
  }

  void setAuthToken(String token) {
    _authToken = token;
  }

  Future<void> loadReports(int centerId) async {
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
      final responsePreview = response.body.length > 500
          ? '${response.body.substring(0, 500)}...'
          : response.body;
      debugPrint('Response body: $responsePreview');

      if (response.statusCode == 200) {
        List<dynamic> reportsJson;
        try {
          reportsJson = json.decode(response.body);
        } catch (e) {
          debugPrint('Error parsing JSON: $e');
          throw Exception('Error decoding response: $e');
        }

        final List<AnalyticsReport> tempReports = [];

        for (var reportJson in reportsJson) {
          try {
            final report = AnalyticsReport.fromJson(reportJson);
            tempReports.add(report);
          } catch (e) {
            debugPrint('Error parsing report: $e');
          }
        }

        if (tempReports.isNotEmpty) {
          _reports = tempReports;

          _reports.sort((a, b) =>
              DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt))
          );

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
      notifyListeners();
    }
  }

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
      final data = {
        'start_snapshot_id': startSnapshot.id,
        'end_snapshot_id': endSnapshot.id,
        'period_type': _periodTypeToString(periodType),
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
        Map<String, dynamic> reportJson;
        try {
          reportJson = json.decode(response.body);
          debugPrint('Report JSON: $reportJson');
        } catch (e) {
          debugPrint('Error parsing JSON response: $e');
          throw Exception('Invalid JSON response: $e');
        }

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
            reportJson['categories'] = [];
          }
        }

        try {
          final report = AnalyticsReport.fromJson(reportJson);

          debugPrint('Parsed report: ${report.name}');
          debugPrint('Categories: ${report.categories}');
          debugPrint('Total consumption: ${report.totalConsumption}');
          debugPrint('Consumption data points: ${report.consumptionData.keys.length}');

          await loadReports(centerId);

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
        _reports.removeWhere((report) => report.id == reportId);

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

  void selectReport(AnalyticsReport report) {
    _selectedReport = report;
    notifyListeners();
  }

  void clearSelection() {
    _selectedReport = null;
    notifyListeners();
  }

  List<AnalyticsReport> getReportsByPeriodType(PeriodType periodType) {
    final periodTypeStr = _periodTypeToString(periodType);
    return _reports.where((report) => report.periodType == periodTypeStr).toList();
  }

  List<AnalyticsReport> getReportsByCategory(String category) {
    return _reports.where((report) => report.categories.contains(category)).toList();
  }

  AnalyticsReport? getLatestReport() {
    if (_reports.isEmpty) return null;
    return _reports.first; // Already sorted by date
  }
}