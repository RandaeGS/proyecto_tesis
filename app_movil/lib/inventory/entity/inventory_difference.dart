/// Model to represent the difference in a product's inventory
class InventoryDifference {
  final String category;
  final int initialCount;
  final int currentCount;
  final int difference;
  final String percentageChange;

  InventoryDifference({
    required this.category,
    required this.initialCount,
    required this.currentCount,
    required this.difference,
    required this.percentageChange,
  });

  /// Creates an instance from a JSON map
  factory InventoryDifference.fromJson(Map<String, dynamic> json) {
    return InventoryDifference(
      category: json['category'] ?? '',
      initialCount: json['initial_count'] ?? 0,
      currentCount: json['current_count'] ?? 0,
      difference: json['difference'] ?? 0,
      percentageChange: json['percentage_change'] ?? 'N/A',
    );
  }

  /// Converts the instance to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'initial_count': initialCount,
      'current_count': currentCount,
      'difference': difference,
      'percentage_change': percentageChange,
    };
  }
}