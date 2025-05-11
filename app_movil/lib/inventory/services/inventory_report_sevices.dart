import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../entities/analisysresult.dart';
import '../entity/inventory_report.dart';
import '../entity/inventory_snapshot.dart';

/// Servicio para manejar informes de inventario con recomendaciones de reposición
class InventoryReportService {
  static const String reportsKey = 'inventory_reports';

  // Umbrales para determinar prioridades de reposición
  static const Map<String, int> defaultIdealCounts = {
    'Bebidas': 50,
    'Alimentos Enlatados': 100,
    'Galletas': 80,
    'Cereales': 60,
    'Pastas y Fideos': 70,
    'Leches en Polvo': 40,
    'Condimentos': 30,
  };

  // Prioridades predeterminadas para emergencias
  static const Map<String, int> emergencyPriorities = {
    'Bebidas': 5,             // Máxima prioridad
    'Alimentos Enlatados': 5, // Máxima prioridad
    'Leches en Polvo': 5,     // Máxima prioridad
    'Galletas': 4,
    'Cereales': 4,
    'Pastas y Fideos': 3,
    'Condimentos': 2,
  };

  /// Genera un informe de reposición basado en el inventario actual
  Future<InventoryReport> generateReplenishmentReport(
      InventorySnapshot currentInventory,
      {bool isEmergency = false, Map<String, int>? customIdealCounts}
      ) async {
    // Usar cantidades ideales personalizadas o predeterminadas
    final idealCounts = customIdealCounts ?? defaultIdealCounts;

    // Mapa para almacenar las recomendaciones de reposición
    final Map<String, ProductReplenishmentInfo> recommendations = {};

    // Analizar cada categoría de producto
    for (final category in currentInventory.productCounts.keys) {
      final currentCount = currentInventory.productCounts[category] ?? 0;
      final idealCount = idealCounts[category] ?? 50; // 50 es el valor predeterminado si no se especifica

      // Determinar la prioridad según el porcentaje faltante
      int priority;

      if (isEmergency) {
        // En situaciones de emergencia, usar las prioridades predefinidas
        priority = emergencyPriorities[category] ?? 3;
      } else {
        // Calcular prioridad basada en el porcentaje faltante
        final percentageMissing = idealCount > 0
            ? ((idealCount - currentCount) / idealCount) * 100
            : 0;

        if (percentageMissing <= 10) {
          priority = 1; // Baja prioridad
        } else if (percentageMissing <= 30) {
          priority = 2; // Media-baja prioridad
        } else if (percentageMissing <= 50) {
          priority = 3; // Media prioridad
        } else if (percentageMissing <= 75) {
          priority = 4; // Media-alta prioridad
        } else {
          priority = 5; // Alta prioridad
        }
      }

      // Generar mensaje personalizado
      String note = '';
      if (currentCount <= 0) {
        note = 'URGENTE: No hay existencias';
      } else if (currentCount < idealCount * 0.25) {
        note = 'Nivel critico de existencias';
      } else if (currentCount < idealCount * 0.5) {
        note = 'Nivel bajo de existencias';
      }

      // Crear la recomendación para esta categoría
      recommendations[category] = ProductReplenishmentInfo(
        category: category,
        currentCount: currentCount,
        idealCount: idealCount,
        priority: priority,
        note: note,
      );
    }

    // Crear el informe
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

    // Guardar el informe
    await saveReport(report);

    return report;
  }

  /// Guarda un informe en el almacenamiento local
  Future<bool> saveReport(InventoryReport report) async {
    try {
      // Obtener informes existentes
      final reports = await getReports(report.centerId);

      // Agregar el nuevo informe
      reports.add(report);

      // Guardar la lista actualizada
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

  /// Obtiene todos los informes de un centro
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

  /// Elimina un informe
  Future<bool> deleteReport(int centerId, String reportId) async {
    try {
      // Obtener todos los informes
      final reports = await getReports(centerId);

      // Remover el informe con el ID especificado
      reports.removeWhere((report) => report.id == reportId);

      // Guardar la lista actualizada
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

  /// Obtiene los productos por categoría específica
  Future<List<ProductReplenishmentInfo>> getProductsByCategory(int centerId, String category) async {
    try {
      // Obtener el informe más reciente
      final reports = await getReports(centerId);

      if (reports.isEmpty) {
        return [];
      }

      // Ordenar por fecha más reciente
      reports.sort((a, b) => DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt)));

      final latestReport = reports.first;

      // Filtrar por categoría
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

  /// Obtiene todos los productos prioritarios
  Future<Map<String, ProductReplenishmentInfo>> getPriorityProducts(int centerId) async {
    try {
      // Obtener el informe más reciente
      final reports = await getReports(centerId);

      if (reports.isEmpty) {
        return {};
      }

      // Ordenar por fecha más reciente
      reports.sort((a, b) => DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt)));

      final latestReport = reports.first;

      // Obtener productos prioritarios
      return latestReport.getPriorityProducts();
    } catch (e) {
      debugPrint('Error al obtener productos prioritarios: $e');
      return {};
    }
  }
}