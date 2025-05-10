import 'package:flutter/material.dart';
import '../entity/analytics_report.dart';
import '../entity/inventory_snapshot.dart';
import 'analytics_services.dart';

class AnalyticsProvider with ChangeNotifier {
  final AnalyticsService _analyticsService = AnalyticsService();

  List<AnalyticsReport> _reports = [];
  AnalyticsReport? _selectedReport;
  bool _isLoading = false;
  String _errorMessage = '';

  // Getters
  List<AnalyticsReport> get reports => _reports;
  AnalyticsReport? get selectedReport => _selectedReport;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  /// Carga los reportes analíticos para un centro específico
  Future<void> loadReports(int centerId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _reports = await _analyticsService.getReports(centerId);

      // Ordenar por fecha de creación (más recientes primero)
      _reports.sort((a, b) =>
          DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt))
      );

      // Resetear el reporte seleccionado
      _selectedReport = null;

    } catch (e) {
      _errorMessage = 'Error al cargar reportes analíticos: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Genera un reporte analítico de consumo
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
      final report = await _analyticsService.generateConsumptionReport(
        centerId: centerId,
        startSnapshot: startSnapshot,
        endSnapshot: endSnapshot,
        periodType: periodType,
        selectedCategories: selectedCategories,
        reportName: reportName,
      );

      // Recargar los reportes para incluir el nuevo
      await loadReports(centerId);

      // Seleccionar el nuevo reporte
      _selectedReport = report;

      return report;
    } catch (e) {
      _errorMessage = 'Error al generar reporte analítico: $e';
      debugPrint(_errorMessage);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Selecciona un reporte específico
  void selectReport(AnalyticsReport report) {
    _selectedReport = report;
    notifyListeners();
  }

  /// Limpia la selección actual
  void clearSelection() {
    _selectedReport = null;
    notifyListeners();
  }

  /// Elimina un reporte
  Future<bool> deleteReport(int centerId, String reportId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final success = await _analyticsService.deleteReport(centerId, reportId);

      if (success) {
        // Actualizar la lista local
        _reports.removeWhere((report) => report.id == reportId);

        // Si el reporte eliminado era el seleccionado, limpiar la selección
        if (_selectedReport?.id == reportId) {
          _selectedReport = null;
        }
      } else {
        _errorMessage = 'No se pudo eliminar el reporte';
      }

      return success;
    } catch (e) {
      _errorMessage = 'Error al eliminar reporte: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Obtiene reportes filtrados por tipo de período
  List<AnalyticsReport> getReportsByPeriodType(PeriodType periodType) {
    return _reports.where((report) => report.periodType == periodType).toList();
  }

  /// Obtiene reportes que incluyen una categoría específica
  List<AnalyticsReport> getReportsByCategory(String category) {
    return _reports.where((report) => report.categories.contains(category)).toList();
  }

  /// Obtiene el reporte más reciente
  AnalyticsReport? getLatestReport() {
    if (_reports.isEmpty) return null;
    return _reports.first; // Ya están ordenados por fecha
  }
}