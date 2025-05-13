import 'package:flutter/material.dart';

class InventoryCategoryItem extends StatelessWidget {
  final String category;
  final TextEditingController controller;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onDelete;

  const InventoryCategoryItem({
    Key? key,
    required this.category,
    required this.controller,
    required this.onDecrease,
    required this.onIncrease,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          children: [
            Row(
              children: [
                // Category icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getCategoryIcon(category),
                    color: _getCategoryColor(category),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Category name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getCategoryDescription(category),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Delete button
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onDelete,
                  tooltip: 'Eliminar',
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Quantity controls
            Row(
              children: [
                const Text(
                  'Cantidad:',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),

                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        // Decrease button
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: onDecrease,
                          color: Colors.red,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Disminuir',
                        ),

                        // Quantity input
                        Expanded(
                          child: TextFormField(
                            controller: controller,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Requerido';
                              }
                              if (int.tryParse(value) == null) {
                                return 'Inválido';
                              }
                              return null;
                            },
                          ),
                        ),

                        // Increase button
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: onIncrease,
                          color: Colors.green,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Aumentar',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    final lowerCategory = category.toLowerCase();

    if (lowerCategory.contains('bebida')) return Icons.local_drink;
    if (lowerCategory.contains('enlatado')) return Icons.lunch_dining;
    if (lowerCategory.contains('leche')) return Icons.coffee;
    if (lowerCategory.contains('galleta')) return Icons.cookie;
    if (lowerCategory.contains('cereal')) return Icons.breakfast_dining;
    if (lowerCategory.contains('pasta') || lowerCategory.contains('fideo')) return Icons.ramen_dining;
    if (lowerCategory.contains('condimento')) return Icons.kitchen;

    return Icons.inventory_2;
  }

  Color _getCategoryColor(String category) {
    final lowerCategory = category.toLowerCase();

    if (lowerCategory.contains('bebida')) return Colors.blue;
    if (lowerCategory.contains('enlatado')) return Colors.orange;
    if (lowerCategory.contains('leche')) return Colors.lightBlue;
    if (lowerCategory.contains('galleta')) return Colors.amber;
    if (lowerCategory.contains('cereal')) return Colors.green;
    if (lowerCategory.contains('pasta') || lowerCategory.contains('fideo')) return Colors.deepOrange;
    if (lowerCategory.contains('condimento')) return Colors.purple;

    return Colors.teal;
  }

  String _getCategoryDescription(String category) {
    final lowerCategory = category.toLowerCase();

    if (lowerCategory.contains('bebida')) return 'Líquidos y refrescos';
    if (lowerCategory.contains('enlatado')) return 'Alimentos envasados';
    if (lowerCategory.contains('leche')) return 'Productos lácteos';
    if (lowerCategory.contains('galleta')) return 'Snacks y dulces';
    if (lowerCategory.contains('cereal')) return 'Cereales y granos';
    if (lowerCategory.contains('pasta') || lowerCategory.contains('fideo')) return 'Pastas y fideos';
    if (lowerCategory.contains('condimento')) return 'Especias y saborizantes';

    return 'Productos varios';
  }
}