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
  Map<String, ProductReplenishmentInfo> _priorityProducts = {};
  bool _isLoading = false;
  String _errorMessage = '';

  // Getters
  List<InventoryReport> get reports => _reports;

  Map<String, ProductReplenishmentInfo> get priorityProducts =>
      _priorityProducts;

  bool get isLoading => _isLoading;

  String get errorMessage => _errorMessage;

  /// Sets the authentication token to use for API requests
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// Load inventory reports for a specific center
  Future<void> loadReports(int centerId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // Load reports
      final url = Uri.parse('$_baseUrl/reports/by_center/?center_id=$centerId');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> reportsJson = json.decode(response.body);

        _reports =
            reportsJson.map((json) => InventoryReport.fromJson(json)).toList();

        // Sort by creation date (most recent first)
        _reports.sort((a, b) =>
            DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt))
        );

        // Also load priority products
        await _loadPriorityProducts(centerId);
      } else {
        _errorMessage = 'Error al cargar informes: ${response.statusCode}';
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

  /// Load priority products for a center
  Future<void> _loadPriorityProducts(int centerId) async {
    try {
      final url = Uri.parse(
          '$_baseUrl/reports/priority_products/?center_id=$centerId');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> productsJson = json.decode(response.body);

        _priorityProducts = {};
        productsJson.forEach((key, value) {
          _priorityProducts[key] = ProductReplenishmentInfo.fromJson(value);
        });
      } else {
        debugPrint(
            'Error al cargar productos prioritarios: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error al cargar productos prioritarios: $e');
    }
  }

  /// Generate a report based on current inventory
  Future<InventoryReport?> generateReport(InventorySnapshot currentInventory,
      {bool isEmergency = false, Map<String, int>? customIdealCounts}) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // Prepare data for API
      final data = {
        'snapshot_id': currentInventory.id,
        'is_emergency': isEmergency,
        if (customIdealCounts != null) 'custom_ideal_counts': customIdealCounts,
      };

      final url = Uri.parse('$_baseUrl/reports/generate/');

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
        final report = InventoryReport.fromJson(reportJson);

        // Reload reports to include the new one
        await loadReports(currentInventory.centerId);

        return report;
      } else {
        _errorMessage = 'Error al generar informe: ${response.statusCode}';
        debugPrint(_errorMessage);
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

  /// Delete a report
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
        notifyListeners();
        return true;
      } else {
        _errorMessage =
        'No se pudo eliminar el informe: ${response.statusCode}';
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

  /// Fetch products by category
  Future<List<ProductReplenishmentInfo>> getProductsByCategory(int centerId,
      String category) async {
    _isLoading = true;
    notifyListeners();

    try {
      final url = Uri.parse(
          '$_baseUrl/reports/by_category/?center_id=$centerId&category=$category');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> productsJson = json.decode(response.body);

        final products = productsJson
            .map((json) => ProductReplenishmentInfo.fromJson(json))
            .toList();

        return products;
      } else {
        _errorMessage =
        'Error al obtener productos por categoría: ${response.statusCode}';
        debugPrint(_errorMessage);
        return [];
      }
    } catch (e) {
      _errorMessage = 'Error al obtener productos por categoría: $e';
      debugPrint(_errorMessage);
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update priority products
  Future<void> updatePriorityProducts(int centerId) async {
    try {
      await _loadPriorityProducts(centerId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error al actualizar productos prioritarios: $e');
    }
  }

  /// Get the latest report
  InventoryReport? getLatestReport() {
    if (_reports.isEmpty) return null;
    return _reports.first; // Already sorted by date
  }
}