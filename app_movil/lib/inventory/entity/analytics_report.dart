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
    // Convert consumption data
    final Map<String, List<ConsumptionDataPoint>> consumption = {};

    if (json['data_points'] != null) {
      final List<dynamic> dataPoints = json['data_points'];

      // Group data points by category
      final Map<String, List<dynamic>> pointsByCategory = {};
      for (var point in dataPoints) {
        final categoryName = point['category_name'] as String;
        if (!pointsByCategory.containsKey(categoryName)) {
          pointsByCategory[categoryName] = [];
        }
        pointsByCategory[categoryName]!.add(point);
      }

      // Convert to ConsumptionDataPoint objects
      pointsByCategory.forEach((category, points) {
        consumption[category] = points
            .map((point) => ConsumptionDataPoint.fromJson(point))
            .toList();
      });
    }

    // Convert total consumption
    final Map<String, int> total = {};

    if (json['consumption_totals'] != null) {
      final List<dynamic> totals = json['consumption_totals'];

      for (var item in totals) {
        final categoryName = item['category_name'] as String;
        final count = item['count'] as int;
        total[categoryName] = count;
      }
    }

    // Get date range
    DateRange range;
    if (json['date_range'] != null) {
      range = DateRange.fromJson(json['date_range']);
    } else {
      // Create from start_date and end_date
      range = DateRange(
        startDate: json['start_date'] ?? '',
        endDate: json['end_date'] ?? '',
      );
    }

    // Use the alternative constructor with direct string period type
    return AnalyticsReport.withStringPeriodType(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      createdAt: json['created_at'] ?? '',
      centerId: json['center'] is int
          ? json['center']
          : int.tryParse(json['center'].toString()) ?? 0,
      categories: json['categories'] != null
          ? List<String>.from(json['categories'])
          : [],
      dateRange: range,
      periodType: json['period_type'] ?? 'weekly', // Use string directly
      consumptionData: consumption,
      totalConsumption: total,
      startSnapshotId: json['start_snapshot'],
      endSnapshotId: json['end_snapshot'],
    );
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
    return ConsumptionDataPoint(
      date: json['date'] ?? '',
      count: json['count'] is int
          ? json['count']
          : int.tryParse(json['count'].toString()) ?? 0,
      note: json['note'],
    );
  }

  /// Converts the instance to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'count': count,
      if (note != null) 'note': note,
    };
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
    return DateRange(
      startDate: json['startDate'] ?? '',
      endDate: json['endDate'] ?? '',
    );
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