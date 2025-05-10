/// Modelo para representar una instantánea del inventario en un momento dado
class InventorySnapshot {
  final String id;
  final String name;
  final String description;
  final int centerId;
  final String createdAt;
  final Map<String, int> productCounts;
  final List<String> sourceResultIds; // IDs de los resultados de análisis que generaron este snapshot

  InventorySnapshot({
    required this.id,
    required this.name,
    required this.description,
    required this.centerId,
    required this.createdAt,
    required this.productCounts,
    required this.sourceResultIds,
  });

  /// Crea una instancia desde un mapa JSON
  factory InventorySnapshot.fromJson(Map<String, dynamic> json) {
    // Convertir el mapa de conteos a formato Map<String, int>
    final Map<String, int> counts = {};

    if (json['productCounts'] != null) {
      final Map<String, dynamic> countsMap = Map<String, dynamic>.from(json['productCounts']);
      countsMap.forEach((key, value) {
        counts[key] = (value is int) ? value : int.tryParse(value.toString()) ?? 0;
      });
    }

    // Convertir la lista de IDs de resultados
    List<String> resultIds = [];
    if (json['sourceResultIds'] != null) {
      resultIds = List<String>.from(json['sourceResultIds']);
    }

    return InventorySnapshot(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      centerId: json['centerId'] is int
          ? json['centerId']
          : int.tryParse(json['centerId'].toString()) ?? 0,
      createdAt: json['createdAt'] ?? DateTime.now().toString(),
      productCounts: counts,
      sourceResultIds: resultIds,
    );
  }

  /// Convierte la instancia a un mapa JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'centerId': centerId,
      'createdAt': createdAt,
      'productCounts': productCounts,
      'sourceResultIds': sourceResultIds,
    };
  }

  /// Crea una copia de esta instantánea con los campos especificados actualizados
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

  /// Formatea la fecha de creación para mostrarla
  String getFormattedDate() {
    try {
      final date = DateTime.parse(createdAt);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return createdAt;
    }
  }
}