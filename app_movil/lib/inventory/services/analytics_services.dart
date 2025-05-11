import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../entity/analytics_report.dart';
import '../entity/inventory_snapshot.dart';

/// Servicio para generar y gestionar reportes analíticos de consumo
class AnalyticsService {
  static const String analyticsReportsKey = 'analytics_reports';

  /// Genera un reporte analítico de consumo basado en dos instantáneas de inventario
  Future<AnalyticsReport> generateConsumptionReport({
    required int centerId,
    required InventorySnapshot startSnapshot,
    required InventorySnapshot endSnapshot,
    required PeriodType periodType,
    required List<String> selectedCategories,
    String? reportName,
  }) async {
    // Verificar que las instantáneas tengan fechas válidas
    final startDate = _parseDateTime(startSnapshot.createdAt);
    final endDate = _parseDateTime(endSnapshot.createdAt);

    if (startDate == null || endDate == null) {
      throw Exception('Fechas de instantáneas inválidas');
    }

    // Verificar que la fecha de inicio sea anterior a la de fin
    if (startDate.isAfter(endDate)) {
      throw Exception('La fecha de inicio debe ser anterior a la fecha de fin');
    }

    // Calcular el consumo entre las instantáneas
    final Map<String, int> consumption = {};
    final Map<String, List<ConsumptionDataPoint>> consumptionData = {};

    // Si no se especifican categorías, usar todas las disponibles
    final categoriesToAnalyze = selectedCategories.isEmpty
        ? {...startSnapshot.productCounts.keys, ...endSnapshot.productCounts.keys}
        : selectedCategories.toSet();

    for (final category in categoriesToAnalyze) {
      final startCount = startSnapshot.productCounts[category] ?? 0;
      final endCount = endSnapshot.productCounts[category] ?? 0;

      // Calcular la diferencia para determinar el consumo
      // (asumimos que consumo = reducción en el inventario)
      int consumptionValue = startCount - endCount;

      // Si el valor es negativo, posiblemente hubo reposición
      // En ese caso, asumimos consumo 0 o podríamos usar otra lógica
      if (consumptionValue < 0) {
        consumptionValue = 0;
      }

      consumption[category] = consumptionValue;

      // Generar puntos de datos para el consumo
      // Aquí aplicamos un modelo simple de distribución diaria
      final dataPoints = _generateConsumptionDataPoints(
        startDate: startDate,
        endDate: endDate,
        totalConsumption: consumptionValue,
        periodType: periodType,
      );

      consumptionData[category] = dataPoints;
    }

    // Crear el rango de fechas para el reporte
    final dateRange = DateRange(
      startDate: startDate.toIso8601String(),
      endDate: endDate.toIso8601String(),
    );

    // Crear el reporte utilizando el nuevo constructor
    final report = AnalyticsReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: reportName ?? _generateReportName(periodType),
      createdAt: DateTime.now().toIso8601String(),
      centerId: centerId,
      categories: categoriesToAnalyze.toList(),
      dateRange: dateRange,
      periodTypeEnum: periodType, // Pasamos el enum directamente
      consumptionData: consumptionData,
      totalConsumption: consumption,
      startSnapshotId: startSnapshot.id,
      endSnapshotId: endSnapshot.id,
    );

    // Guardar el reporte
    await saveReport(report);

    return report;
  }

  /// Genera puntos de datos de consumo distribuidos en el rango de fechas
  List<ConsumptionDataPoint> _generateConsumptionDataPoints({
    required DateTime startDate,
    required DateTime endDate,
    required int totalConsumption,
    required PeriodType periodType,
  }) {
    final points = <ConsumptionDataPoint>[];

    // Si no hay consumo, retornamos una lista vacía
    if (totalConsumption <= 0) {
      return points;
    }

    // Calculamos el número de días en el rango
    final days = endDate.difference(startDate).inDays + 1;

    // Si no hay días, retornamos una lista vacía
    if (days <= 0) {
      return points;
    }

    // Generamos puntos de datos según el tipo de período
    if (periodType == PeriodType.weekly) {
      // Para análisis semanal, generamos datos para cada día
      // con variaciones aleatorias pero preservando el total
      int remainingConsumption = totalConsumption;
      final random = Random();

      for (int i = 0; i < days; i++) {
        final date = startDate.add(Duration(days: i));

        // Calcular un valor de consumo aleatorio para este día
        int dailyConsumption;

        if (i == days - 1) {
          // En el último día, usamos el consumo restante
          dailyConsumption = remainingConsumption;
        } else {
          // En otros días, generamos un valor aleatorio
          // que no exceda el consumo restante
          final maxDailyConsumption = (remainingConsumption / (days - i)).ceil();
          dailyConsumption = random.nextInt(maxDailyConsumption + 1);
        }

        // Actualizar el consumo restante
        remainingConsumption -= dailyConsumption;

        // Crear el punto de datos solo si hay consumo
        if (dailyConsumption > 0) {
          points.add(ConsumptionDataPoint(
            date: date.toIso8601String(),
            count: dailyConsumption,
          ));
        }
      }
    } else if (periodType == PeriodType.monthly) {
      // Para análisis mensual, agrupamos por semanas
      // Calculamos el número de semanas completas
      final weeks = (days / 7).ceil();

      // Distribuimos el consumo por semanas
      int remainingConsumption = totalConsumption;
      final random = Random();

      for (int i = 0; i < weeks; i++) {
        final weekStartDate = startDate.add(Duration(days: i * 7));
        final weekEndDate = i == weeks - 1
            ? endDate
            : startDate.add(Duration(days: (i + 1) * 7 - 1));

        if (weekEndDate.isBefore(weekStartDate)) continue;

        // Calcular un valor de consumo para esta semana
        int weeklyConsumption;

        if (i == weeks - 1) {
          // En la última semana, usamos el consumo restante
          weeklyConsumption = remainingConsumption;
        } else {
          // En otras semanas, generamos un valor aleatorio
          final maxWeeklyConsumption = (remainingConsumption / (weeks - i)).ceil();
          weeklyConsumption = random.nextInt(maxWeeklyConsumption + 1);
        }

        // Actualizar el consumo restante
        remainingConsumption -= weeklyConsumption;

        // Crear el punto de datos solo si hay consumo
        if (weeklyConsumption > 0) {
          points.add(ConsumptionDataPoint(
            date: weekStartDate.toIso8601String(),
            count: weeklyConsumption,
            note: 'Semana ${i + 1}',
          ));
        }
      }
    }

    return points;
  }

  /// Genera un nombre para el reporte basado en el tipo de período
  String _generateReportName(PeriodType periodType) {
    final now = DateTime.now();
    final formattedDate = '${now.day}/${now.month}/${now.year}';

    switch (periodType) {
      case PeriodType.weekly:
        return 'Analisis Semanal - $formattedDate';
      case PeriodType.monthly:
        return 'Analisis Mensual - $formattedDate';
    }
  }

  /// Interpreta una cadena como DateTime
  DateTime? _parseDateTime(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      debugPrint('Error al parsear fecha: $e');
      return null;
    }
  }

  /// Guarda un reporte analítico
  Future<bool> saveReport(AnalyticsReport report) async {
    try {
      // Obtener reportes existentes
      final reports = await getReports(report.centerId);

      // Agregar el nuevo reporte
      reports.add(report);

      // Guardar la lista actualizada
      final prefs = await SharedPreferences.getInstance();
      final reportsJson = reports.map((r) => r.toJson()).toList();
      await prefs.setString(
          '${analyticsReportsKey}_${report.centerId}',
          jsonEncode(reportsJson)
      );

      return true;
    } catch (e) {
      debugPrint('Error al guardar reporte analítico: $e');
      return false;
    }
  }

  /// Obtiene todos los reportes analíticos de un centro
  Future<List<AnalyticsReport>> getReports(int centerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reportsString = prefs.getString('${analyticsReportsKey}_$centerId');

      if (reportsString == null || reportsString.isEmpty) {
        return [];
      }

      final List<dynamic> reportsJson = jsonDecode(reportsString);
      return reportsJson
          .map((json) => AnalyticsReport.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error al obtener reportes analíticos: $e');
      return [];
    }
  }

  /// Elimina un reporte analítico
  Future<bool> deleteReport(int centerId, String reportId) async {
    try {
      // Obtener todos los reportes
      final reports = await getReports(centerId);

      // Remover el reporte con el ID especificado
      reports.removeWhere((report) => report.id == reportId);

      // Guardar la lista actualizada
      final prefs = await SharedPreferences.getInstance();
      final reportsJson = reports.map((r) => r.toJson()).toList();
      await prefs.setString(
          '${analyticsReportsKey}_$centerId',
          jsonEncode(reportsJson)
      );

      return true;
    } catch (e) {
      debugPrint('Error al eliminar reporte analítico: $e');
      return false;
    }
  }
}