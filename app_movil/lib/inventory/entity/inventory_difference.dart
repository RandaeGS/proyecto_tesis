
/// Modelo para representar la diferencia en el inventario de un producto
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
}