/// Modelo para representar un reporte analítico de consumo de productos
class AnalyticsReport {
  final String id;
  final String name;
  final String createdAt;
  final int centerId;
  final List<String> categories; // Categorías incluidas en el análisis
  final DateRange dateRange; // Rango de fechas del análisis
  final PeriodType periodType; // Tipo de período (semanal, mensual)
  final Map<String, List<ConsumptionDataPoint>> consumptionData; // Datos de consumo por categoría
  final Map<String, int> totalConsumption; // Consumo total por categoría en el período

  AnalyticsReport({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.centerId,
    required this.categories,
    required this.dateRange,
    required this.periodType,
    required this.consumptionData,
    required this.totalConsumption,
  });

  /// Crea una instancia desde un mapa JSON
  factory AnalyticsReport.fromJson(Map<String, dynamic> json) {
    // Convertir mapa de datos de consumo
    final Map<String, List<ConsumptionDataPoint>> consumption = {};

    if (json['consumptionData'] != null) {
      final consumptionMap = Map<String, dynamic>.from(json['consumptionData']);

      consumptionMap.forEach((category, dataList) {
        consumption[category] = (dataList as List).map((data) =>
            ConsumptionDataPoint.fromJson(data)
        ).toList();
      });
    }

    // Convertir consumo total
    final Map<String, int> total = {};

    if (json['totalConsumption'] != null) {
      final totalMap = Map<String, dynamic>.from(json['totalConsumption']);

      totalMap.forEach((category, count) {
        total[category] = count is int ? count : int.tryParse(count.toString()) ?? 0;
      });
    }

    return AnalyticsReport(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      createdAt: json['createdAt'] ?? '',
      centerId: json['centerId'] is int
          ? json['centerId']
          : int.tryParse(json['centerId'].toString()) ?? 0,
      categories: List<String>.from(json['categories'] ?? []),
      dateRange: DateRange.fromJson(json['dateRange'] ?? {}),
      periodType: PeriodType.values.firstWhere(
            (type) => type.toString() == json['periodType'],
        orElse: () => PeriodType.weekly,
      ),
      consumptionData: consumption,
      totalConsumption: total,
    );
  }

  /// Convierte la instancia a un mapa JSON
  Map<String, dynamic> toJson() {
    // Convertir datos de consumo a formato JSON
    final Map<String, List<Map<String, dynamic>>> consumptionJson = {};

    consumptionData.forEach((category, dataPoints) {
      consumptionJson[category] = dataPoints.map((point) => point.toJson()).toList();
    });

    return {
      'id': id,
      'name': name,
      'createdAt': createdAt,
      'centerId': centerId,
      'categories': categories,
      'dateRange': dateRange.toJson(),
      'periodType': periodType.toString(),
      'consumptionData': consumptionJson,
      'totalConsumption': totalConsumption,
    };
  }

  /// Formatea la fecha de creación
  String getFormattedDate() {
    try {
      final date = DateTime.parse(createdAt);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return createdAt;
    }
  }

  /// Obtiene la categoría con mayor consumo
  String getMostConsumedCategory() {
    if (totalConsumption.isEmpty) return 'N/A';

    return totalConsumption.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  /// Obtiene la categoría con menor consumo
  String getLeastConsumedCategory() {
    if (totalConsumption.isEmpty) return 'N/A';

    return totalConsumption.entries
        .reduce((a, b) => a.value < b.value ? a : b)
        .key;
  }

  /// Calcula el consumo promedio diario por categoría
  Map<String, double> getAverageDailyConsumption() {
    final days = dateRange.getDaysCount();
    if (days <= 0) return {};

    final Map<String, double> averages = {};

    totalConsumption.forEach((category, total) {
      averages[category] = total / days;
    });

    return averages;
  }

  /// Obtiene los días de mayor consumo por categoría
  Map<String, String> getPeakConsumptionDays() {
    final Map<String, String> peakDays = {};

    consumptionData.forEach((category, dataPoints) {
      if (dataPoints.isEmpty) return;

      final peakPoint = dataPoints.reduce(
              (a, b) => a.count > b.count ? a : b
      );

      peakDays[category] = peakPoint.getFormattedDate();
    });

    return peakDays;
  }
}

/// Punto de datos para análisis de consumo
class ConsumptionDataPoint {
  final String date; // Fecha del punto de datos (en formato ISO)
  final int count; // Cantidad consumida
  final String? note; // Nota opcional

  ConsumptionDataPoint({
    required this.date,
    required this.count,
    this.note,
  });

  /// Crea una instancia desde un mapa JSON
  factory ConsumptionDataPoint.fromJson(Map<String, dynamic> json) {
    return ConsumptionDataPoint(
      date: json['date'] ?? '',
      count: json['count'] is int
          ? json['count']
          : int.tryParse(json['count'].toString()) ?? 0,
      note: json['note'],
    );
  }

  /// Convierte la instancia a un mapa JSON
  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'count': count,
      if (note != null) 'note': note,
    };
  }

  /// Obtiene el objeto DateTime
  DateTime getDateTime() {
    try {
      return DateTime.parse(date);
    } catch (e) {
      return DateTime.now();
    }
  }

  /// Formatea la fecha de manera legible
  String getFormattedDate() {
    try {
      final dateTime = DateTime.parse(date);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return date;
    }
  }
}

/// Rango de fechas para análisis
class DateRange {
  final String startDate; // Fecha de inicio en formato ISO
  final String endDate; // Fecha de fin en formato ISO

  DateRange({
    required this.startDate,
    required this.endDate,
  });

  /// Crea una instancia desde un mapa JSON
  factory DateRange.fromJson(Map<String, dynamic> json) {
    return DateRange(
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
    );
  }

  /// Convierte la instancia a un mapa JSON
  Map<String, dynamic> toJson() {
    return {
      'startDate': startDate,
      'endDate': endDate,
    };
  }

  /// Crea un rango para la última semana
  factory DateRange.lastWeek() {
    final now = DateTime.now();
    final endDate = now;
    final startDate = now.subtract(const Duration(days: 7));

    return DateRange(
      startDate: startDate.toIso8601String(),
      endDate: endDate.toIso8601String(),
    );
  }

  /// Crea un rango para el último mes
  factory DateRange.lastMonth() {
    final now = DateTime.now();
    final endDate = now;
    final startDate = DateTime(now.year, now.month - 1, now.day);

    return DateRange(
      startDate: startDate.toIso8601String(),
      endDate: endDate.toIso8601String(),
    );
  }

  /// Obtiene el objeto DateTime de inicio
  DateTime getStartDateTime() {
    try {
      return DateTime.parse(startDate);
    } catch (e) {
      return DateTime.now().subtract(const Duration(days: 30));
    }
  }

  /// Obtiene el objeto DateTime de fin
  DateTime getEndDateTime() {
    try {
      return DateTime.parse(endDate);
    } catch (e) {
      return DateTime.now();
    }
  }

  /// Calcula el número de días en el rango
  int getDaysCount() {
    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);

      return end.difference(start).inDays + 1;
    } catch (e) {
      return 0;
    }
  }

  /// Formatea el rango de fechas como una cadena legible
  String getFormattedRange() {
    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);

      return '${start.day}/${start.month}/${start.year} - ${end.day}/${end.month}/${end.year}';
    } catch (e) {
      return '$startDate - $endDate';
    }
  }
}

/// Tipo de período para análisis
enum PeriodType {
  weekly,
  monthly,
}