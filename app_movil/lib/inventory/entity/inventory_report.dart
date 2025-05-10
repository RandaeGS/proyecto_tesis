/// Modelo para representar un informe de inventario con recomendaciones
class InventoryReport {
  final String id;
  final String name;
  final String createdAt;
  final int centerId;
  final Map<String, ProductReplenishmentInfo> productRecommendations;
  final bool isEmergency; // Indica si es un informe para situaciones de emergencia

  InventoryReport({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.centerId,
    required this.productRecommendations,
    this.isEmergency = false,
  });

  /// Crea una instancia desde un mapa JSON
  factory InventoryReport.fromJson(Map<String, dynamic> json) {
    final Map<String, ProductReplenishmentInfo> recommendations = {};

    if (json['productRecommendations'] != null) {
      final Map<String, dynamic> recommendationsMap =
      Map<String, dynamic>.from(json['productRecommendations']);

      recommendationsMap.forEach((key, value) {
        recommendations[key] = ProductReplenishmentInfo.fromJson(value);
      });
    }

    return InventoryReport(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      createdAt: json['createdAt'] ?? '',
      centerId: json['centerId'] is int
          ? json['centerId']
          : int.tryParse(json['centerId'].toString()) ?? 0,
      productRecommendations: recommendations,
      isEmergency: json['isEmergency'] ?? false,
    );
  }

  /// Convierte la instancia a un mapa JSON
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> recommendationsMap = {};

    productRecommendations.forEach((key, value) {
      recommendationsMap[key] = value.toJson();
    });

    return {
      'id': id,
      'name': name,
      'createdAt': createdAt,
      'centerId': centerId,
      'productRecommendations': recommendationsMap,
      'isEmergency': isEmergency,
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

  /// Obtiene los productos prioritarios (con prioridad > 3)
  Map<String, ProductReplenishmentInfo> getPriorityProducts() {
    return Map.fromEntries(
        productRecommendations.entries
            .where((entry) => entry.value.priority > 3)
    );
  }

  /// Obtiene las recomendaciones agrupadas por nivel de prioridad
  Map<int, List<MapEntry<String, ProductReplenishmentInfo>>> getRecommendationsByPriority() {
    final Map<int, List<MapEntry<String, ProductReplenishmentInfo>>> result = {};

    // Inicializar las listas para cada nivel de prioridad (1-5)
    for (int i = 1; i <= 5; i++) {
      result[i] = [];
    }

    // Agrupar las recomendaciones por nivel de prioridad
    productRecommendations.entries.forEach((entry) {
      final priority = entry.value.priority;
      result[priority]!.add(entry);
    });

    return result;
  }
}

/// Información de reposición de un producto
class ProductReplenishmentInfo {
  final String category;
  final int currentCount;
  final int idealCount;
  final int priority; // 1-5 donde 5 es la máxima prioridad
  final String note;

  ProductReplenishmentInfo({
    required this.category,
    required this.currentCount,
    required this.idealCount,
    required this.priority,
    this.note = '',
  });

  /// Crea una instancia desde un mapa JSON
  factory ProductReplenishmentInfo.fromJson(Map<String, dynamic> json) {
    return ProductReplenishmentInfo(
      category: json['category'] ?? '',
      currentCount: json['currentCount'] ?? 0,
      idealCount: json['idealCount'] ?? 0,
      priority: json['priority'] ?? 1,
      note: json['note'] ?? '',
    );
  }

  /// Convierte la instancia a un mapa JSON
  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'currentCount': currentCount,
      'idealCount': idealCount,
      'priority': priority,
      'note': note,
    };
  }

  /// Calcula la cantidad a reponer
  int get replenishAmount => idealCount - currentCount;

  /// Calcula el porcentaje faltante
  double get percentageMissing {
    if (idealCount == 0) return 0.0;
    return (replenishAmount / idealCount) * 100;
  }
}