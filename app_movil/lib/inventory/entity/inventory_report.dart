/// Model to represent an inventory report with replenishment recommendations
class InventoryReport {
  final String id;
  final String name;
  final String createdAt;
  final int centerId;
  final Map<String, ProductReplenishmentInfo> productRecommendations;
  final bool isEmergency; // Indicates if this is an emergency report
  final String? sourceSnapshotId; // ID of the snapshot used to generate this report

  InventoryReport({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.centerId,
    required this.productRecommendations,
    this.isEmergency = false,
    this.sourceSnapshotId,
  });

  /// Creates an instance from a JSON map
  factory InventoryReport.fromJson(Map<String, dynamic> json) {
    final Map<String, ProductReplenishmentInfo> recommendations = {};

    if (json['recommendations'] != null) {
      final List<dynamic> recsList = json['recommendations'];

      for (var rec in recsList) {
        // Use category name as the key
        final categoryName = rec['category_name'] as String;
        recommendations[categoryName] = ProductReplenishmentInfo.fromJson(rec);
      }
    }

    return InventoryReport(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      createdAt: json['created_at'] ?? '',
      centerId: json['center'] is int
          ? json['center']
          : int.tryParse(json['center'].toString()) ?? 0,
      productRecommendations: recommendations,
      isEmergency: json['is_emergency'] ?? false,
      sourceSnapshotId: json['source_snapshot'],
    );
  }

  /// Converts the instance to a JSON map
  Map<String, dynamic> toJson() {
    final List<Map<String, dynamic>> recsList = [];
    productRecommendations.forEach((key, value) {
      recsList.add(value.toJson());
    });

    return {
      'id': id,
      'name': name,
      'created_at': createdAt,
      'center': centerId,
      'recommendations': recsList,
      'is_emergency': isEmergency,
      'source_snapshot': sourceSnapshotId,
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

  /// Gets priority products (with priority > 3)
  Map<String, ProductReplenishmentInfo> getPriorityProducts() {
    return Map.fromEntries(
        productRecommendations.entries
            .where((entry) => entry.value.priority > 3)
    );
  }

  /// Gets recommendations grouped by priority level
  Map<int, List<MapEntry<String, ProductReplenishmentInfo>>> getRecommendationsByPriority() {
    final Map<int, List<MapEntry<String, ProductReplenishmentInfo>>> result = {};

    // Initialize lists for each priority level (1-5)
    for (int i = 1; i <= 5; i++) {
      result[i] = [];
    }

    // Group recommendations by priority level
    productRecommendations.entries.forEach((entry) {
      final priority = entry.value.priority;
      result[priority]!.add(entry);
    });

    return result;
  }
}

/// Information about product replenishment
class ProductReplenishmentInfo {
  final String category;
  final int currentCount;
  final int idealCount;
  final int priority; // 1-5 where 5 is the highest priority
  final String note;
  final int? categoryId; // ID of the category in the database

  ProductReplenishmentInfo({
    required this.category,
    required this.currentCount,
    required this.idealCount,
    required this.priority,
    this.note = '',
    this.categoryId,
  });

  /// Creates an instance from a JSON map
  factory ProductReplenishmentInfo.fromJson(Map<String, dynamic> json) {
    return ProductReplenishmentInfo(
      category: json['category_name'] ?? '',
      currentCount: json['current_count'] ?? 0,
      idealCount: json['ideal_count'] ?? 0,
      priority: json['priority'] ?? 1,
      note: json['note'] ?? '',
      categoryId: json['category'],
    );
  }

  /// Converts the instance to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'category': categoryId,
      'category_name': category,
      'current_count': currentCount,
      'ideal_count': idealCount,
      'priority': priority,
      'note': note,
    };
  }

  /// Calculates how many items to replenish
  int get replenishAmount => idealCount > currentCount ? idealCount - currentCount : 0;

  /// Calculates percentage missing
  double get percentageMissing {
    if (idealCount == 0) return 0.0;
    return (replenishAmount / idealCount) * 100;
  }
}