import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../entity/inventory_report.dart';
import '../entity/inventory_snapshot.dart';

class InventoryReportService {
  static const String reportsKey = 'inventory_reports';

  static const Map<String, int> defaultIdealCounts = {
    'Bebidas': 50,
    'Alimentos Enlatados': 100,
    'Galletas': 80,
    'Cereales': 60,
    'Pastas y Fideos': 70,
    'Leches en Polvo': 40,
    'Condimentos': 30,
  };

  static const Map<String, int> emergencyPriorities = {
    'Bebidas': 5,
    'Alimentos Enlatados': 5,
    'Leches en Polvo': 5,
    'Galletas': 4,
    'Cereales': 4,
    'Pastas y Fideos': 3,
    'Condimentos': 2,
  };

  Future<InventoryReport> generateReplenishmentReport(
      InventorySnapshot currentInventory,
      {bool isEmergency = false, Map<String, int>? customIdealCounts}
      ) async {
    final idealCounts = customIdealCounts ?? defaultIdealCounts;

    final Map<String, ProductReplenishmentInfo> recommendations = {};

    for (final category in currentInventory.productCounts.keys) {
      final currentCount = currentInventory.productCounts[category] ?? 0;
      final idealCount = idealCounts[category] ?? 50;

      int priority;

      if (isEmergency) {
        priority = emergencyPriorities[category] ?? 3;
      } else {
        final percentageMissing = idealCount > 0
            ? ((idealCount - currentCount) / idealCount) * 100
            : 0;

        if (percentageMissing <= 10) {
          priority = 1;
        } else if (percentageMissing <= 30) {
          priority = 2;
        } else if (percentageMissing <= 50) {
          priority = 3;
        } else if (percentageMissing <= 75) {
          priority = 4;
        } else {
          priority = 5;
        }
      }

      String note = '';
      if (currentCount <= 0) {
        note = 'URGENTE: No hay existencias';
      } else if (currentCount < idealCount * 0.25) {
        note = 'Nivel critico de existencias';
      } else if (currentCount < idealCount * 0.5) {
        note = 'Nivel bajo de existencias';
      }

      recommendations[category] = ProductReplenishmentInfo(
        category: category,
        currentCount: currentCount,
        idealCount: idealCount,
        priority: priority,
        note: note,
      );
    }

    final report = InventoryReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: isEmergency
          ? 'Informe de Emergencia ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'
          : 'Informe de Reposicion ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
      createdAt: DateTime.now().toString(),
      centerId: currentInventory.centerId,
      productRecommendations: recommendations,
      isEmergency: isEmergency,
    );

    await saveReport(report);

    return report;
  }

  Future<bool> saveReport(InventoryReport report) async {
    try {
      final reports = await getReports(report.centerId);

      reports.add(report);

      final prefs = await SharedPreferences.getInstance();
      final reportsJson = reports.map((r) => r.toJson()).toList();
      await prefs.setString(
          '${reportsKey}_${report.centerId}',
          jsonEncode(reportsJson)
      );

      return true;
    } catch (e) {
      debugPrint('Error al guardar informe: $e');
      return false;
    }
  }

  Future<List<InventoryReport>> getReports(int centerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reportsString = prefs.getString('${reportsKey}_$centerId');

      if (reportsString == null || reportsString.isEmpty) {
        return [];
      }

      final List<dynamic> reportsJson = jsonDecode(reportsString);
      return reportsJson
          .map((json) => InventoryReport.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error al obtener informes: $e');
      return [];
    }
  }

  Future<bool> deleteReport(int centerId, String reportId) async {
    try {
      final reports = await getReports(centerId);

      reports.removeWhere((report) => report.id == reportId);

      final prefs = await SharedPreferences.getInstance();
      final reportsJson = reports.map((r) => r.toJson()).toList();
      await prefs.setString(
          '${reportsKey}_$centerId',
          jsonEncode(reportsJson)
      );

      return true;
    } catch (e) {
      debugPrint('Error al eliminar informe: $e');
      return false;
    }
  }

  Future<List<ProductReplenishmentInfo>> getProductsByCategory(int centerId, String category) async {
    try {
      final reports = await getReports(centerId);

      if (reports.isEmpty) {
        return [];
      }

      reports.sort((a, b) => DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt)));

      final latestReport = reports.first;

      final productInfo = latestReport.productRecommendations[category];

      if (productInfo == null) {
        return [];
      }

      return [productInfo];
    } catch (e) {
      debugPrint('Error al obtener productos por categoría: $e');
      return [];
    }
  }

  Future<Map<String, ProductReplenishmentInfo>> getPriorityProducts(int centerId) async {
    try {
      final reports = await getReports(centerId);

      if (reports.isEmpty) {
        return {};
      }

      reports.sort((a, b) => DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt)));

      final latestReport = reports.first;

      return latestReport.getPriorityProducts();
    } catch (e) {
      debugPrint('Error al obtener productos prioritarios: $e');
      return {};
    }
  }
}