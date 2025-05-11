import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../entity/inventory_snapshot.dart';
import '../services/inventory_comparison_provider.dart';
import '../services/inventory_report_provider.dart';
import '../services/inventory_report_sevices.dart';
import '../services/product_data_provider.dart';

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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Avoid calling setState during build
    Future.microtask(() => _loadInventoryData());
  }

  @override
  void dispose() {
    _editControllers.forEach((_, controller) => controller.dispose());
    _newCategoryController.dispose();
    _newCategoryCountController.dispose();
    super.dispose();
  }

  Future<void> _loadInventoryData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint("Loading inventory data for center: ${widget.centerId}");

      // First try to get data from the product data provider
      final productDataProvider = Provider.of<ProductDataProvider>(context, listen: false);

      // Reload product data to ensure it's up to date
      await productDataProvider.loadProductData(widget.centerId);

      // Get the current product counts
      _productCounts = Map.from(productDataProvider.currentProductCounts);
      debugPrint("Loaded product counts from provider: $_productCounts");

      // If counts are empty, try loading from the latest snapshot
      if (_productCounts.isEmpty) {
        debugPrint("Product counts empty, trying to load from latest snapshot");
        // Load the latest snapshot
        final snapshotProvider = Provider.of<InventoryComparisonProvider>(context, listen: false);
        await snapshotProvider.loadInventorySnapshots(widget.centerId);

        if (snapshotProvider.snapshots.isNotEmpty) {
          _currentSnapshot = snapshotProvider.snapshots.first; // La más reciente
          _productCounts = Map.from(_currentSnapshot!.productCounts);
          debugPrint("Loaded product counts from snapshot: $_productCounts");
        } else {
          // Si no hay instantáneas, cargar categorías predeterminadas
          debugPrint("No snapshots found, using default categories");
          _productCounts = Map.from(InventoryReportService.defaultIdealCounts);
          _productCounts.forEach((key, value) => _productCounts[key] = 0); // Inicializar con 0
        }
      }

      // Inicializar los controladores para cada categoría
      _initializeControllers();
    } catch (e) {
      debugPrint("Error loading inventory data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _initializeControllers() {
    // Dispose old controllers first
    _editControllers.forEach((_, controller) => controller.dispose());
    _editControllers = {};

    // Create new controllers for each category
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

    debugPrint("Initialized ${_editControllers.length} controllers for categories");
  }

  Future<void> _saveInventory() async {
    if (!_formKey.currentState!.validate()) {
      debugPrint("Form validation failed");
      return;
    }

    setState(() {
      _isLoading = true;
      _isSaving = true;
    });

    try {
      debugPrint("Saving inventory changes");

      // Collect updated counts from controllers
      Map<String, int> updatedCounts = {};
      _editControllers.forEach((category, controller) {
        updatedCounts[category] = int.tryParse(controller.text) ?? 0;
      });

      debugPrint("Updated counts to save: $updatedCounts");

      // Update the central product data provider
      final productDataProvider = Provider.of<ProductDataProvider>(context, listen: false);
      productDataProvider.updateProductCounts(updatedCounts);

      // Create a new snapshot with the updated values
      final snapshotProvider = Provider.of<InventoryComparisonProvider>(context, listen: false);
      snapshotProvider.setProductDataProvider(productDataProvider);

      final snapshotName = 'Actualizacion Manual - ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
      final snapshotDesc = 'Actualizacion manual del inventario';

      debugPrint("Creating new snapshot with name: $snapshotName");
      final success = await snapshotProvider.saveSnapshotFromProductData(
        widget.centerId,
        snapshotName,
        snapshotDesc,
      );

      if (success) {
        debugPrint("Snapshot created successfully");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Inventario actualizado correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }

        setState(() {
          _hasChanges = false;
        });

        // Completely reload data to ensure UI is updated
        await _fullReload();
      } else {
        debugPrint("Failed to create snapshot");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo actualizar el inventario'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Error saving inventory: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _isSaving = false;
      });
    }
  }

  // Complete reload of all data
  Future<void> _fullReload() async {
    debugPrint("Performing full reload of data");

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // First reload product data
      final productDataProvider = Provider.of<ProductDataProvider>(context, listen: false);
      await productDataProvider.loadProductData(widget.centerId);

      // Then reload inventory snapshots
      final inventoryProvider = Provider.of<InventoryComparisonProvider>(context, listen: false);
      await inventoryProvider.loadInventorySnapshots(widget.centerId);

      // Then reload reports
      try {
        final reportProvider = Provider.of<InventoryReportProvider>(context, listen: false);
        await reportProvider.loadReports(widget.centerId);
      } catch (e) {
        debugPrint('Error refreshing reports: $e');
      }

      // Get the updated counts
      _productCounts = Map.from(productDataProvider.currentProductCounts);

      // Reinitialize controllers
      _initializeControllers();

      debugPrint("Full reload completed, product counts: $_productCounts");
    } catch (e) {
      debugPrint("Error during full reload: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al recargar datos: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
          // Botón para sincronizar con detecciones
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sincronizar con detecciones',
            onPressed: () async {
              setState(() {
                _isLoading = true;
              });

              try {
                await _fullReload();

                // Notify user
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Datos sincronizados correctamente con las detecciones'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al sincronizar datos: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                setState(() {
                  _isLoading = false;
                });
              }
            },
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar datos',
            onPressed: _fullReload,
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
                        Consumer<ProductDataProvider>(
                          builder: (context, provider, child) {
                            return Text(
                              'Última actualizacion: ${_formatDateTime(provider.lastUpdated)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Categorías activas: ${_productCounts.length}',
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
                    child: _isSaving
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton.icon(
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

  // Format DateTime to a readable string
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load the snapshots when the screen opens
      final provider = Provider.of<InventoryComparisonProvider>(context, listen: false);
      await provider.loadInventorySnapshots(widget.centerId);
    } catch (e) {
      debugPrint("Error loading snapshot history: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de Inventario'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<InventoryComparisonProvider>(
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