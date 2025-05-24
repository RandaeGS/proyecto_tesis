import 'package:flutter/material.dart';

class InventoryFilterBar extends StatefulWidget {
  final Function(String) onSearchChanged;
  final Function(String) onFilterChanged;
  final List<String> filterOptions;

  const InventoryFilterBar({
    Key? key,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.filterOptions,
  }) : super(key: key);

  @override
  State<InventoryFilterBar> createState() => _InventoryFilterBarState();
}

class _InventoryFilterBarState extends State<InventoryFilterBar> {
  String _selectedFilter = 'Todas';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 2,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextField(
              onChanged: widget.onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar por categoría...',
                border: InputBorder.none,
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey.shade600,
                ),
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 14,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Filtrar por:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),

          const SizedBox(height: 4),

          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.filterOptions.length,
              itemBuilder: (context, index) {
                final filter = widget.filterOptions[index];
                final isSelected = _selectedFilter == filter;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      filter,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : Colors.blue.shade800,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = filter;
                      });
                      widget.onFilterChanged(filter);
                    },
                    backgroundColor: Colors.white,
                    selectedColor: Colors.blue,
                    checkmarkColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}