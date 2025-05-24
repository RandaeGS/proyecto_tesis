import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../entity/analytics_report.dart';
import '../entity/inventory_snapshot.dart';

class AnalyticsService {
  static const String analyticsReportsKey = 'analytics_reports';

  Future<AnalyticsReport> generateConsumptionReport({
    required int centerId,
    required InventorySnapshot startSnapshot,
    required InventorySnapshot endSnapshot,
    required PeriodType periodType,
    required List<String> selectedCategories,
    String? reportName,
  }) async {
    final startDate = _parseDateTime(startSnapshot.createdAt);
    final endDate = _parseDateTime(endSnapshot.createdAt);

    if (startDate == null || endDate == null) {
      throw Exception('Fechas de instantáneas inválidas');
    }

    if (startDate.isAfter(endDate)) {
      throw Exception('La fecha de inicio debe ser anterior a la fecha de fin');
    }

    final Map<String, int> consumption = {};
    final Map<String, List<ConsumptionDataPoint>> consumptionData = {};

    final categoriesToAnalyze = selectedCategories.isEmpty
        ? {...startSnapshot.productCounts.keys, ...endSnapshot.productCounts.keys}
        : selectedCategories.toSet();

    for (final category in categoriesToAnalyze) {
      final startCount = startSnapshot.productCounts[category] ?? 0;
      final endCount = endSnapshot.productCounts[category] ?? 0;

      int consumptionValue = startCount - endCount;

      if (consumptionValue < 0) {
        consumptionValue = 0;
      }

      consumption[category] = consumptionValue;

      final dataPoints = _generateConsumptionDataPoints(
        startDate: startDate,
        endDate: endDate,
        totalConsumption: consumptionValue,
        periodType: periodType,
      );

      consumptionData[category] = dataPoints;
    }

    final dateRange = DateRange(
      startDate: startDate.toIso8601String(),
      endDate: endDate.toIso8601String(),
    );

    final report = AnalyticsReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: reportName ?? _generateReportName(periodType),
      createdAt: DateTime.now().toIso8601String(),
      centerId: centerId,
      categories: categoriesToAnalyze.toList(),
      dateRange: dateRange,
      periodTypeEnum: periodType,
      consumptionData: consumptionData,
      totalConsumption: consumption,
      startSnapshotId: startSnapshot.id,
      endSnapshotId: endSnapshot.id,
    );

    await saveReport(report);

    return report;
  }

  List<ConsumptionDataPoint> _generateConsumptionDataPoints({
    required DateTime startDate,
    required DateTime endDate,
    required int totalConsumption,
    required PeriodType periodType,
  }) {
    final points = <ConsumptionDataPoint>[];

    if (totalConsumption <= 0) {
      return points;
    }

    final days = endDate.difference(startDate).inDays + 1;

    if (days <= 0) {
      return points;
    }

    if (periodType == PeriodType.weekly) {
      int remainingConsumption = totalConsumption;
      final random = Random();

      for (int i = 0; i < days; i++) {
        final date = startDate.add(Duration(days: i));

        int dailyConsumption;

        if (i == days - 1) {
          dailyConsumption = remainingConsumption;
        } else {
          final maxDailyConsumption = (remainingConsumption / (days - i)).ceil();
          dailyConsumption = random.nextInt(maxDailyConsumption + 1);
        }

        remainingConsumption -= dailyConsumption;

        if (dailyConsumption > 0) {
          points.add(ConsumptionDataPoint(
            date: date.toIso8601String(),
            count: dailyConsumption,
          ));
        }
      }
    } else if (periodType == PeriodType.monthly) {
      final weeks = (days / 7).ceil();

      int remainingConsumption = totalConsumption;
      final random = Random();

      for (int i = 0; i < weeks; i++) {
        final weekStartDate = startDate.add(Duration(days: i * 7));
        final weekEndDate = i == weeks - 1
            ? endDate
            : startDate.add(Duration(days: (i + 1) * 7 - 1));

        if (weekEndDate.isBefore(weekStartDate)) continue;

        int weeklyConsumption;

        if (i == weeks - 1) {
          weeklyConsumption = remainingConsumption;
        } else {
          final maxWeeklyConsumption = (remainingConsumption / (weeks - i)).ceil();
          weeklyConsumption = random.nextInt(maxWeeklyConsumption + 1);
        }

        remainingConsumption -= weeklyConsumption;

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

  DateTime? _parseDateTime(String dateStr) {
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      debugPrint('Error al parsear fecha: $e');
      return null;
    }
  }

  Future<bool> saveReport(AnalyticsReport report) async {
    try {
      final reports = await getReports(report.centerId);

      reports.add(report);

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

  Future<bool> deleteReport(int centerId, String reportId) async {
    try {
      final reports = await getReports(centerId);

      reports.removeWhere((report) => report.id == reportId);

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