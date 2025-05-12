import 'package:flutter/foundation.dart'; // Para debugPrint

/// Model to represent an analytics report of product consumption
class AnalyticsReport {
  final String id;
  final String name;
  final String createdAt;
  final int centerId;
  final List<String> categories; // Categories included in the analysis
  final DateRange dateRange; // Date range of the analysis
  final String periodType; // Type of period (weekly, monthly)
  final Map<String, List<ConsumptionDataPoint>> consumptionData; // Consumption data by category
  final Map<String, int> totalConsumption; // Total consumption by category in the period
  final String? startSnapshotId; // ID of the start snapshot
  final String? endSnapshotId; // ID of the end snapshot

  /// Converts PeriodType enum to string for storage
  static String _periodTypeToString(PeriodType periodType) {
    switch (periodType) {
      case PeriodType.weekly:
        return 'weekly';
      case PeriodType.monthly:
        return 'monthly';
      default:
        return 'weekly'; // Default to weekly
    }
  }

  AnalyticsReport({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.centerId,
    required this.categories,
    required this.dateRange,
    required PeriodType periodTypeEnum, // Accept enum, not string
    required this.consumptionData,
    required this.totalConsumption,
    this.startSnapshotId,
    this.endSnapshotId,
  }) : this.periodType = _periodTypeToString(periodTypeEnum); // Convert enum to string in initializer

  /// Alternative constructor directly with periodType as string
  AnalyticsReport.withStringPeriodType({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.centerId,
    required this.categories,
    required this.dateRange,
    required this.periodType, // Direct string
    required this.consumptionData,
    required this.totalConsumption,
    this.startSnapshotId,
    this.endSnapshotId,
  });

  /// Get the period type as enum
  PeriodType getPeriodTypeEnum() {
    switch (periodType.toLowerCase()) {
      case 'weekly':
        return PeriodType.weekly;
      case 'monthly':
        return PeriodType.monthly;
      default:
        return PeriodType.weekly; // Default
    }
  }

  /// Creates an instance from a JSON map
  factory AnalyticsReport.fromJson(Map<String, dynamic> json) {
    try {
      debugPrint('Creating AnalyticsReport from JSON: ${json['name']}');

      // Convert consumption data
      final Map<String, List<ConsumptionDataPoint>> consumption = {};

      if (json['data_points'] != null) {
        final List<dynamic> dataPoints = json['data_points'];
        debugPrint('Found ${dataPoints.length} data points');

        // Group data points by category
        final Map<String, List<dynamic>> pointsByCategory = {};
        for (var point in dataPoints) {
          try {
            // El problema está aquí - necesitamos usar el nombre de la categoría o la referencia correcta
            String categoryName;

            // Primero intentar obtener el category_name directamente
            if (point['category_name'] != null) {
              categoryName = point['category_name'].toString();
            }
            // Si no está disponible, intenta buscar la categoría por ID
            else if (point['category'] != null) {
              // Buscamos la categoría correspondiente en consumption_totals
              final categoryId = point['category'];
              final matchingTotal = json['consumption_totals']?.firstWhere(
                      (total) => total['category'] == categoryId,
                  orElse: () => null
              );

              if (matchingTotal != null && matchingTotal['category_name'] != null) {
                categoryName = matchingTotal['category_name'].toString();
              } else {
                // Si no podemos encontrar el nombre, usamos el ID como string
                categoryName = 'Categoría ${categoryId.toString()}';
              }
            } else {
              // Si no hay manera de identificar la categoría, saltamos este punto
              continue;
            }

            if (!pointsByCategory.containsKey(categoryName)) {
              pointsByCategory[categoryName] = [];
            }
            pointsByCategory[categoryName]!.add(point);
          } catch (e) {
            debugPrint('Error processing data point: $e');
            // Continue with the next point
          }
        }

        // Convert to ConsumptionDataPoint objects
        pointsByCategory.forEach((category, points) {
          try {
            consumption[category] = points
                .map((point) => ConsumptionDataPoint.fromJson(point))
                .toList();
            debugPrint('Added ${points.length} data points for $category');
          } catch (e) {
            debugPrint('Error converting data points for $category: $e');
            // If there's an error, use an empty list
            consumption[category] = [];
          }
        });
      }

      // Convert total consumption
      final Map<String, int> total = {};

      if (json['consumption_totals'] != null) {
        final List<dynamic> totals = json['consumption_totals'];
        debugPrint('Found ${totals.length} consumption totals');

        for (var item in totals) {
          try {
            if (item['category_name'] != null) {
              final categoryName = item['category_name'].toString();
              final count = item['count'] is int
                  ? item['count']
                  : int.tryParse(item['count'].toString()) ?? 0;
              total[categoryName] = count;
            }
          } catch (e) {
            debugPrint('Error processing consumption total: $e');
            // Continue with the next item
          }
        }
      }

      // Get categories with null-safety
      List<String> categories = [];
      if (json['categories'] != null) {
        try {
          if (json['categories'] is List) {
            categories = (json['categories'] as List)
                .map((item) => item?.toString() ?? "")
                .where((item) => item.isNotEmpty)
                .toList();
          }
        } catch (e) {
          debugPrint('Error extracting categories: $e');
        }
      }

      // If categories is still empty, try to get from consumption totals
      if (categories.isEmpty && json['consumption_totals'] != null) {
        try {
          final List<dynamic> totals = json['consumption_totals'];
          final Set<String> categorySet = {};

          for (var item in totals) {
            if (item != null && item['category_name'] != null) {
              categorySet.add(item['category_name'].toString());
            }
          }

          categories = categorySet.toList();
        } catch (e) {
          debugPrint('Error extracting categories from totals: $e');
        }
      }

      // Extract date range (safe version)
      DateRange dateRange;
      try {
        if (json['date_range'] != null && json['date_range'] is Map) {
          final startDate = json['date_range']['startDate']?.toString() ?? '';
          final endDate = json['date_range']['endDate']?.toString() ?? '';
          dateRange = DateRange(startDate: startDate, endDate: endDate);
        } else {
          // Fallback: use start_date and end_date directly
          final startDate = json['start_date']?.toString() ?? '';
          final endDate = json['end_date']?.toString() ?? '';
          dateRange = DateRange(startDate: startDate, endDate: endDate);
        }
      } catch (e) {
        debugPrint('Error parsing date range: $e');
        dateRange = DateRange(
          startDate: DateTime.now().toIso8601String(),
          endDate: DateTime.now().toIso8601String(),
        );
      }

      // Extract all other properties with null safety
      final String id = json['id']?.toString() ?? '';
      final String name = json['name']?.toString() ?? 'Reporte';
      final String createdAt = json['created_at']?.toString() ?? DateTime.now().toIso8601String();

      int centerId;
      try {
        if (json['center'] is int) {
          centerId = json['center'];
        } else {
          centerId = int.tryParse(json['center']?.toString() ?? '0') ?? 0;
        }
      } catch (e) {
        debugPrint('Error parsing centerId: $e');
        centerId = 0;
      }

      final String periodType = json['period_type']?.toString() ?? 'weekly';

      // Extract snapshot IDs safely
      String? startSnapshotId;
      String? endSnapshotId;
      try {
        startSnapshotId = json['start_snapshot']?.toString();
        endSnapshotId = json['end_snapshot']?.toString();
      } catch (e) {
        debugPrint('Error extracting snapshot IDs: $e');
      }

      // Create the report
      final report = AnalyticsReport.withStringPeriodType(
        id: id,
        name: name,
        createdAt: createdAt,
        centerId: centerId,
        categories: categories,
        dateRange: dateRange,
        periodType: periodType,
        consumptionData: consumption,
        totalConsumption: total,
        startSnapshotId: startSnapshotId,
        endSnapshotId: endSnapshotId,
      );

      debugPrint('Parsed report: ${report.name}');
      debugPrint('Categories: ${report.categories}');
      debugPrint('Total consumption: ${report.totalConsumption}');
      debugPrint('Consumption data points: ${report.consumptionData.values.fold(0, (prev, list) => prev + list.length)}');

      return report;
    } catch (e) {
      debugPrint('Error creating AnalyticsReport: $e');
      rethrow; // Re-lanzar la excepción para que se maneje en niveles superiores
    }
  }

  /// Converts the instance to a JSON map
  Map<String, dynamic> toJson() {
    // Convert consumption data to JSON format
    final List<Map<String, dynamic>> dataPoints = [];
    consumptionData.forEach((category, points) {
      for (var point in points) {
        dataPoints.add(point.toJson()..['category_name'] = category);
      }
    });

    // Convert total consumption to JSON format
    final List<Map<String, dynamic>> totals = [];
    totalConsumption.forEach((category, count) {
      totals.add({
        'category_name': category,
        'count': count,
      });
    });

    return {
      'id': id,
      'name': name,
      'created_at': createdAt,
      'center': centerId,
      'categories': categories,
      'date_range': dateRange.toJson(),
      'period_type': periodType, // Store the string
      'data_points': dataPoints,
      'consumption_totals': totals,
      'start_snapshot': startSnapshotId,
      'end_snapshot': endSnapshotId,
    };
  }

  /// Formats the creation date for display
  String getFormattedDate() {
    try {
      final date = DateTime.parse(createdAt);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return createdAt;
    }
  }

  /// Gets the category with the highest consumption
  String getMostConsumedCategory() {
    if (totalConsumption.isEmpty) return 'N/A';

    String maxCategory = totalConsumption.keys.first;
    int maxValue = totalConsumption[maxCategory] ?? 0;

    totalConsumption.forEach((category, count) {
      if (count > maxValue) {
        maxValue = count;
        maxCategory = category;
      }
    });

    if (maxValue == 0) return 'N/A';
    return '$maxCategory ($maxValue)';
  }

  /// Gets the category with the lowest consumption
  String getLeastConsumedCategory() {
    if (totalConsumption.isEmpty) return 'N/A';

    String minCategory = totalConsumption.keys.first;
    int minValue = totalConsumption[minCategory] ?? 0;

    totalConsumption.forEach((category, count) {
      if (count < minValue) {
        minValue = count;
        minCategory = category;
      }
    });

    if (minValue == 0) return 'N/A';
    return '$minCategory ($minValue)';
  }

  /// Calculates average daily consumption by category
  Map<String, double> getAverageDailyConsumption() {
    final days = dateRange.getDaysCount();
    if (days <= 0) return {};

    final Map<String, double> averages = {};

    totalConsumption.forEach((category, total) {
      averages[category] = total / days;
    });

    return averages;
  }

  /// Gets the days with peak consumption by category
  Map<String, String> getPeakConsumptionDays() {
    final Map<String, String> peakDays = {};

    consumptionData.forEach((category, dataPoints) {
      if (dataPoints.isEmpty) return;

      ConsumptionDataPoint peakPoint = dataPoints.first;
      for (var point in dataPoints) {
        if (point.count > peakPoint.count) {
          peakPoint = point;
        }
      }

      peakDays[category] = peakPoint.getFormattedDate();
    });

    return peakDays;
  }
}

/// Data point for consumption analysis
class ConsumptionDataPoint {
  final String date; // Date of the data point (in ISO format)
  final int count; // Quantity consumed
  final String? note; // Optional note

  ConsumptionDataPoint({
    required this.date,
    required this.count,
    this.note,
  });

  /// Creates an instance from a JSON map
  factory ConsumptionDataPoint.fromJson(Map<String, dynamic> json) {
    try {
      // Debug the fields
      if (kDebugMode) {
        print('DataPoint JSON: $json');
      }

      // Extract date with null-safety
      String dateStr = '';
      if (json['date'] != null) {
        dateStr = json['date'].toString();
      }

      // Extract count with null-safety
      int countValue = 0;
      if (json['count'] != null) {
        if (json['count'] is int) {
          countValue = json['count'];
        } else {
          countValue = int.tryParse(json['count'].toString()) ?? 0;
        }
      }

      // Extract note safely - this is where the error is happening
      String? noteValue;
      if (json.containsKey('note') && json['note'] != null) {
        noteValue = json['note'].toString();
      }

      return ConsumptionDataPoint(
        date: dateStr,
        count: countValue,
        note: noteValue,
      );
    } catch (e) {
      debugPrint('Error creating ConsumptionDataPoint: $e');
      // Return a default object in case of error
      return ConsumptionDataPoint(
        date: DateTime.now().toIso8601String(),
        count: 0,
        note: null,
      );
    }
  }

  /// Converts the instance to a JSON map
  Map<String, dynamic> toJson() {
    // Create the base map first
    final Map<String, dynamic> map = {
      'date': date,
      'count': count,
    };

    // Add the note only if it's not null
    if (note != null) {
      map['note'] = note;
    }

    return map;
  }

  /// Gets the DateTime object
  DateTime getDateTime() {
    try {
      return DateTime.parse(date);
    } catch (e) {
      return DateTime.now();
    }
  }

  /// Formats the date in a readable way
  String getFormattedDate() {
    try {
      final dateTime = DateTime.parse(date);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return date;
    }
  }

  bool isIncrease() {
    if (note == null) return false;
    return note!.toLowerCase().contains('aumento');
  }
}

/// Date range for analysis
class DateRange {
  final String startDate; // Start date in ISO format
  final String endDate; // End date in ISO format

  DateRange({
    required this.startDate,
    required this.endDate,
  });

  /// Creates an instance from a JSON map
  factory DateRange.fromJson(Map<String, dynamic> json) {
    try {
      return DateRange(
        startDate: json['startDate']?.toString() ?? '',
        endDate: json['endDate']?.toString() ?? '',
      );
    } catch (e) {
      debugPrint('Error creating DateRange from JSON: $e');
      return DateRange(
          startDate: '',
          endDate: ''
      );
    }
  }

  /// Converts the instance to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'startDate': startDate,
      'endDate': endDate,
    };
  }

  /// Creates a range for the last week
  factory DateRange.lastWeek() {
    final now = DateTime.now();
    final endDate = now;
    final startDate = now.subtract(const Duration(days: 7));

    return DateRange(
      startDate: startDate.toIso8601String(),
      endDate: endDate.toIso8601String(),
    );
  }

  /// Creates a range for the last month
  factory DateRange.lastMonth() {
    final now = DateTime.now();
    final endDate = now;
    // Subtract one month (approximately)
    final startDate = DateTime(now.year, now.month - 1, now.day);

    return DateRange(
      startDate: startDate.toIso8601String(),
      endDate: endDate.toIso8601String(),
    );
  }

  /// Gets the start DateTime
  DateTime getStartDateTime() {
    try {
      return DateTime.parse(startDate);
    } catch (e) {
      return DateTime.now().subtract(const Duration(days: 30));
    }
  }

  /// Gets the end DateTime
  DateTime getEndDateTime() {
    try {
      return DateTime.parse(endDate);
    } catch (e) {
      return DateTime.now();
    }
  }

  /// Calculates the number of days in the range
  int getDaysCount() {
    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);

      return end.difference(start).inDays + 1;
    } catch (e) {
      return 0;
    }
  }

  /// Formats the date range as a readable string
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

/// Period type for analysis
enum PeriodType {
  weekly,
  monthly,
}