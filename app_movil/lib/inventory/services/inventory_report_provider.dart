import 'package:flutter/material.dart';
import '../entity/inventory_report.dart';
import '../entity/inventory_snapshot.dart';
import 'inventory_report_sevices.dart';

class InventoryReportProvider with ChangeNotifier {
  final InventoryReportService _reportService = InventoryReportService();

  List<InventoryReport> _reports = [];
  Map<String, ProductReplenishmentInfo> _priorityProducts = {};
  bool _isLoading = false;
  String _errorMessage = '';

  // Getters
  List<InventoryReport> get reports => _reports;
  Map<String, ProductReplenishmentInfo> get priorityProducts => _priorityProducts;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  /// Carga los informes de inventario para un centro específico
  Future<void> loadReports(int centerId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _reports = await _reportService.getReports(centerId);

      // Ordenar por fecha de creación (más recientes primero)
      _reports.sort((a, b) =>
          DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt))
      );

      // Cargar también los productos prioritarios
      _priorityProducts = await _reportService.getPriorityProducts(centerId);

    } catch (e) {
      _errorMessage = 'Error al cargar informes de inventario: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Genera un informe de reposición basado en el inventario actual
  Future<InventoryReport?> generateReport(
      InventorySnapshot currentInventory,
      {bool isEmergency = false, Map<String, int>? customIdealCounts}
      ) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final report = await _reportService.generateReplenishmentReport(
        currentInventory,
        isEmergency: isEmergency,
        customIdealCounts: customIdealCounts,
      );

      // Recargar los informes para incluir el nuevo
      await loadReports(currentInventory.centerId);

      return report;
    } catch (e) {
      _errorMessage = 'Error al generar informe: $e';
      debugPrint(_errorMessage);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Elimina un informe
  Future<bool> deleteReport(int centerId, String reportId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final success = await _reportService.deleteReport(centerId, reportId);

      if (success) {
        // Actualizar la lista local
        _reports.removeWhere((report) => report.id == reportId);
      } else {
        _errorMessage = 'No se pudo eliminar el informe';
      }

      return success;
    } catch (e) {
      _errorMessage = 'Error al eliminar informe: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Obtiene información de productos por categoría específica
  Future<List<ProductReplenishmentInfo>> getProductsByCategory(int centerId, String category) async {
    _isLoading = true;
    notifyListeners();

    try {
      final products = await _reportService.getProductsByCategory(centerId, category);
      return products;
    } catch (e) {
      _errorMessage = 'Error al obtener productos por categoría: $e';
      debugPrint(_errorMessage);
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Actualiza la lista de productos prioritarios
  Future<void> updatePriorityProducts(int centerId) async {
    try {
      _priorityProducts = await _reportService.getPriorityProducts(centerId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error al actualizar productos prioritarios: $e');
    }
  }

  /// Obtiene el informe más reciente
  InventoryReport? getLatestReport() {
    if (_reports.isEmpty) return null;
    return _reports.first; // Ya están ordenados por fecha
  }
}