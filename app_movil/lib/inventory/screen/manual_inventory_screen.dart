import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../entity/inventory_snapshot.dart';
import '../services/inventory_comparison_provider.dart';
import '../services/inventory_report_provider.dart';
import '../services/inventory_report_sevices.dart';

class ManualInventoryManagementScreen extends StatefulWidget {
  final int centerId;

  const ManualInventoryManagementScreen({
    Key? key,
    required this.centerId,
  }) : super(key: key);

  @override
  State<ManualInventoryManagementScreen> createState() => _ManualInventoryManagementScreenState();
}

class _ManualInventoryManagementScreenState extends State<ManualInventoryManagementScreen> {
  bool _isLoading = true;
  InventorySnapshot? _currentSnapshot;
  Map<String, int> _productCounts = {};
  Map<String, TextEditingController> _editControllers = {};
  final _formKey = GlobalKey<FormState>();
  final _newCategoryController = TextEditingController();
  final _newCategoryCountController = TextEditingController();
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadInventoryData();
  }

  @override
  void dispose() {
    _editControllers.forEach((_, controller) => controller.dispose());
    _newCategoryController.dispose();
    _newCategoryCountController.dispose();
    super.dispose();
  }

  Future<void> _loadInventoryData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Intentar cargar la instantánea más reciente
      final snapshotProvider = Provider.of<InventoryComparisonProvider>(context, listen: false);
      await snapshotProvider.loadInventorySnapshots(widget.centerId);

      if (snapshotProvider.snapshots.isNotEmpty) {
        _currentSnapshot = snapshotProvider.snapshots.first; // La más reciente
        _productCounts = Map.from(_currentSnapshot!.productCounts);
      } else {
        // Si no hay instantáneas, cargar categorías predeterminadas
        _productCounts = Map.from(InventoryReportService.defaultIdealCounts);
        _productCounts.forEach((key, value) => _productCounts[key] = 0); // Inicializar con 0
      }

      // Inicializar los controladores para cada categoría
      _initializeControllers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar datos: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _initializeControllers() {
    _editControllers.forEach((_, controller) => controller.dispose());
    _editControllers = {};

    _productCounts.forEach((category, count) {
      _editControllers[category] = TextEditingController(text: count.toString());
      _editControllers[category]!.addListener(() {
        final newValue = int.tryParse(_editControllers[category]!.text) ?? 0;
        if (newValue != _productCounts[category]) {
          setState(() {
            _hasChanges = true;
          });
        }
      });
    });
  }

  Future<void> _saveInventory() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Actualizar los valores desde los controladores
      Map<String, int> updatedCounts = {};
      _editControllers.forEach((category, controller) {
        updatedCounts[category] = int.tryParse(controller.text) ?? 0;
      });

      // Crear una nueva instantánea con los valores actualizados
      final snapshotProvider = Provider.of<InventoryComparisonProvider>(context, listen: false);
      final snapshotName = 'Actualización Manual - ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
      final snapshotDesc = 'Actualización manual del inventario';

      final success = await snapshotProvider.saveInventorySnapshot(
        widget.centerId,
        snapshotName,
        snapshotDesc,
        updatedCounts,
        [], // No hay resultados de análisis de imágenes
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inventario actualizado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _hasChanges = false;
        });

        // Recargar datos
        await _loadInventoryData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo actualizar el inventario'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addNewCategory() {
    final categoryName = _newCategoryController.text.trim();
    final countText = _newCategoryCountController.text.trim();

    if (categoryName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre de la categoría no puede estar vacío')),
      );
      return;
    }

    if (_productCounts.containsKey(categoryName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta categoría ya existe')),
      );
      return;
    }

    int count = 0;
    if (countText.isNotEmpty) {
      count = int.tryParse(countText) ?? 0;
    }

    setState(() {
      _productCounts[categoryName] = count;
      _editControllers[categoryName] = TextEditingController(text: count.toString());
      _hasChanges = true;

      // Limpiar los controladores
      _newCategoryController.clear();
      _newCategoryCountController.clear();
    });

    // Cerrar el diálogo
    Navigator.of(context).pop();
  }

  void _showAddCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Nueva Categoría'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _newCategoryController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la categoría',
                hintText: 'Ej. Bebidas, Galletas, etc.',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newCategoryCountController,
              decoration: const InputDecoration(
                labelText: 'Cantidad inicial (opcional)',
                hintText: '0',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: _addNewCategory,
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(String category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Categoría'),
        content: Text('¿Estás seguro de eliminar la categoría "$category"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _productCounts.remove(category);
                _editControllers[category]?.dispose();
                _editControllers.remove(category);
                _hasChanges = true;
              });
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showSnapshotHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => InventoryHistoryScreen(centerId: widget.centerId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión Manual de Inventario'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Botón para ver historial
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Ver historial',
            onPressed: _showSnapshotHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: Column(
          children: [
            // Panel informativo
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.shade50,
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Gestión Manual de Inventario',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentSnapshot != null
                              ? 'Última actualización: ${_currentSnapshot!.getFormattedDate()}'
                              : 'No hay registros previos',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Lista de productos
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _productCounts.length,
                itemBuilder: (context, index) {
                  final category = _productCounts.keys.elementAt(index);
                  final controller = _editControllers[category]!;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Ícono
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getCategoryIcon(category),
                              color: Colors.blue,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Nombre de categoría
                          Expanded(
                            child: Text(
                              category,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          // Control de cantidad
                          SizedBox(
                            width: 140,
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () {
                                    int currentValue = int.tryParse(controller.text) ?? 0;
                                    if (currentValue > 0) {
                                      controller.text = (currentValue - 1).toString();
                                      setState(() {
                                        _hasChanges = true;
                                      });
                                    }
                                  },
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: controller,
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 8,
                                      ),
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Requerido';
                                      }
                                      if (int.tryParse(value) == null) {
                                        return 'Número inválido';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () {
                                    int currentValue = int.tryParse(controller.text) ?? 0;
                                    controller.text = (currentValue + 1).toString();
                                    setState(() {
                                      _hasChanges = true;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Botón de eliminar
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _showDeleteConfirmation(category),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Botones de acción
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showAddCategoryDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar Categoría'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _hasChanges ? _saveInventory : null,
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar Cambios'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                    ),
                  ),
                ],
              ),
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
}

// Esta pantalla muestra el historial de instantáneas de inventario
class InventoryHistoryScreen extends StatefulWidget {
  final int centerId;

  const InventoryHistoryScreen({
    Key? key,
    required this.centerId,
  }) : super(key: key);

  @override
  State<InventoryHistoryScreen> createState() => _InventoryHistoryScreenState();
}

class _InventoryHistoryScreenState extends State<InventoryHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Inventario'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Consumer<InventoryComparisonProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.snapshots.isEmpty) {
            return const Center(child: Text('No hay registros de inventario'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.snapshots.length,
            itemBuilder: (context, index) {
              final snapshot = provider.snapshots[index];

              // Contar productos y categorías
              final totalProducts = snapshot.productCounts.values
                  .fold(0, (sum, count) => sum + count);
              final totalCategories = snapshot.productCounts.length;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () {
                    // Mostrar diálogo con detalles
                    _showSnapshotDetailsDialog(context, snapshot);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                snapshot.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Fecha: ${snapshot.getFormattedDate()}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatColumn(
                              'Categorías',
                              totalCategories.toString(),
                              Icons.category_outlined,
                            ),
                            _buildStatColumn(
                              'Productos',
                              totalProducts.toString(),
                              Icons.inventory_2_outlined,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          size: 24,
          color: Colors.blue,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _showSnapshotDetailsDialog(BuildContext context, InventorySnapshot snapshot) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(snapshot.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fecha: ${snapshot.getFormattedDate()}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              if (snapshot.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Descripción: ${snapshot.description}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Contenido del inventario:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...snapshot.productCounts.entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key),
                    Text(
                      '${entry.value}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}