class InventorySnapshot {
  final String id;
  final String name;
  final String description;
  final int centerId;
  final String createdAt;
  final Map<String, int> productCounts;
  final List<String> sourceResultIds;

  InventorySnapshot({
    required this.id,
    required this.name,
    required this.description,
    required this.centerId,
    required this.createdAt,
    required this.productCounts,
    required this.sourceResultIds,
  });

  factory InventorySnapshot.fromJson(Map<String, dynamic> json) {
    final Map<String, int> counts = {};

    if (json['product_counts'] != null && json['product_counts'] is Map) {
      final Map<String, dynamic> countsMap = Map<String, dynamic>.from(json['product_counts']);
      countsMap.forEach((key, value) {
        counts[key] = (value is int) ? value : int.tryParse(value.toString()) ?? 0;
      });
    }
    else if (json['items'] != null && json['items'] is List) {
      final List<dynamic> items = json['items'];
      for (var item in items) {
        if (item is Map && item.containsKey('category_name') && item.containsKey('count')) {
          final categoryName = item['category_name']?.toString() ?? '';
          final count = item['count'] is int
              ? item['count']
              : int.tryParse(item['count'].toString()) ?? 0;

          if (categoryName.isNotEmpty) {
            counts[categoryName] = count;
          }
        }
      }
    }

    List<String> resultIds = [];
    if (json['source_detections'] != null) {
      resultIds = List<String>.from(json['source_detections']);
    }

    print('Creating snapshot from JSON: ${json["name"]}, Products: $counts');

    return InventorySnapshot(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      centerId: json['center'] is int
          ? json['center']
          : int.tryParse(json['center'].toString()) ?? 0,
      createdAt: json['created_at'] ?? '',
      productCounts: counts,
      sourceResultIds: resultIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'center': centerId,
      'created_at': createdAt,
      'product_counts': productCounts,
      'source_detections': sourceResultIds,
    };
  }

  InventorySnapshot copyWith({
    String? id,
    String? name,
    String? description,
    int? centerId,
    String? createdAt,
    Map<String, int>? productCounts,
    List<String>? sourceResultIds,
  }) {
    return InventorySnapshot(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      centerId: centerId ?? this.centerId,
      createdAt: createdAt ?? this.createdAt,
      productCounts: productCounts ?? this.productCounts,
      sourceResultIds: sourceResultIds ?? this.sourceResultIds,
    );
  }

  String getFormattedDate() {
    try {
      final date = DateTime.parse(createdAt);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return createdAt;
    }
  }
}