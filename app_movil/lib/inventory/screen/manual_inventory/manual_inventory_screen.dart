import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../entity/inventory_snapshot.dart';
import '../../services/inventory_comparison_provider.dart';
import '../../services/inventory_report_provider.dart';
import '../../services/inventory_report_sevices.dart';
import '../../services/product_data_provider.dart';
import 'component/inventory_category_item.dart';
import 'component/inventory_empty_state.dart';
import 'component/inventory_filter_bar.dart';
import 'component/inventory_info_banner.dart';

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
  String _searchQuery = '';
  String _filterCategory = 'Todas';

  @override
  void initState() {
    super.initState();
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
      final productDataProvider = Provider.of<ProductDataProvider>(context, listen: false);
      await productDataProvider.loadProductData(widget.centerId);
      _productCounts = Map.from(productDataProvider.currentProductCounts);

      if (_productCounts.isEmpty) {
        final snapshotProvider = Provider.of<InventoryComparisonProvider>(context, listen: false);
        await snapshotProvider.loadInventorySnapshots(widget.centerId);

        if (snapshotProvider.snapshots.isNotEmpty) {
          _currentSnapshot = snapshotProvider.snapshots.first;
          _productCounts = Map.from(_currentSnapshot!.productCounts);
        } else {
          _productCounts = Map.from(InventoryReportService.defaultIdealCounts);
          _productCounts.forEach((key, value) => _productCounts[key] = 0);
        }
      }

      _initializeControllers();
    } catch (e) {
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
      _isSaving = true;
    });

    try {
      Map<String, int> updatedCounts = {};
      _editControllers.forEach((category, controller) {
        updatedCounts[category] = int.tryParse(controller.text) ?? 0;
      });

      final productDataProvider = Provider.of<ProductDataProvider>(context, listen: false);
      productDataProvider.updateProductCounts(updatedCounts);

      final snapshotProvider = Provider.of<InventoryComparisonProvider>(context, listen: false);
      snapshotProvider.setProductDataProvider(productDataProvider);

      final snapshotName = 'Actualizacion Manual - ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
      final snapshotDesc = 'Actualizacion manual del inventario';

      final success = await snapshotProvider.saveSnapshotFromProductData(
        widget.centerId,
        snapshotName,
        snapshotDesc,
      );

      if (success) {
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

        await _fullReload();
      } else {
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

  Future<void> _fullReload() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final productDataProvider = Provider.of<ProductDataProvider>(context, listen: false);
      await productDataProvider.loadProductData(widget.centerId);

      final inventoryProvider = Provider.of<InventoryComparisonProvider>(context, listen: false);
      await inventoryProvider.loadInventorySnapshots(widget.centerId);

      try {
        final reportProvider = Provider.of<InventoryReportProvider>(context, listen: false);
        await reportProvider.loadReports(widget.centerId);
      } catch (e) {}

      _productCounts = Map.from(productDataProvider.currentProductCounts);
      _initializeControllers();
    } catch (e) {
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

      _newCategoryController.clear();
      _newCategoryCountController.clear();
    });

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

  List<MapEntry<String, int>> _getFilteredItems() {
    var items = _productCounts.entries.toList();

    if (_searchQuery.isNotEmpty) {
      items = items
          .where((entry) => entry.key.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    if (_filterCategory != 'Todas') {
      items = items
          .where((entry) => _getCategoryType(entry.key) == _filterCategory)
          .toList();
    }

    return items;
  }

  String _getCategoryType(String category) {
    final lowerCategory = category.toLowerCase();

    if (lowerCategory.contains('bebida')) return 'Bebidas';
    if (lowerCategory.contains('enlatado')) return 'Alimentos';
    if (lowerCategory.contains('leche')) return 'Lácteos';
    if (lowerCategory.contains('galleta')) return 'Snacks';
    if (lowerCategory.contains('cereal')) return 'Cereales';
    if (lowerCategory.contains('pasta') || lowerCategory.contains('fideo')) return 'Pastas';
    if (lowerCategory.contains('condimento')) return 'Condimentos';

    return 'Otros';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Productos'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Ver historial',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => InventoryHistoryScreen(centerId: widget.centerId),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sincronizar',
            onPressed: () async {
              setState(() => _isLoading = true);
              try {
                await _fullReload();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Datos sincronizados correctamente'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al sincronizar: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                setState(() => _isLoading = false);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
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
            Consumer<ProductDataProvider>(
              builder: (context, provider, child) => InventoryInfoBanner(
                title: 'Gestión Manual de Inventario',
                lastUpdate: _formatDateTime(provider.lastUpdated),
                categoryCount: _productCounts.length.toString(),
              ),
            ),

            InventoryFilterBar(
              onSearchChanged: (value) => setState(() => _searchQuery = value),
              onFilterChanged: (value) => setState(() => _filterCategory = value),
              filterOptions: const ['Todas', 'Bebidas', 'Alimentos', 'Lácteos', 'Snacks', 'Cereales', 'Pastas', 'Condimentos', 'Otros'],
            ),

            Expanded(
              child: _getFilteredItems().isEmpty
                  ? const InventoryEmptyState(
                message: 'No se encontraron productos con los filtros actuales',
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _getFilteredItems().length,
                itemBuilder: (context, index) {
                  final entry = _getFilteredItems()[index];
                  final category = entry.key;
                  final controller = _editControllers[category]!;

                  return InventoryCategoryItem(
                    category: category,
                    controller: controller,
                    onDecrease: () {
                      int currentValue = int.tryParse(controller.text) ?? 0;
                      if (currentValue > 0) {
                        controller.text = (currentValue - 1).toString();
                        setState(() => _hasChanges = true);
                      }
                    },
                    onIncrease: () {
                      int currentValue = int.tryParse(controller.text) ?? 0;
                      controller.text = (currentValue + 1).toString();
                      setState(() => _hasChanges = true);
                    },
                    onDelete: () => _showDeleteConfirmation(category),
                  );
                },
              ),
            ),

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
}

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
    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<InventoryComparisonProvider>(context, listen: false);
      await provider.loadInventorySnapshots(widget.centerId);
    } catch (e) {
    } finally {
      setState(() => _isLoading = false);
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
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_outlined,
                      size: 72,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No hay registros de inventario',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Guarda cambios en el inventario para crear una nueva instantánea',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.snapshots.length,
            itemBuilder: (context, index) {
              final snapshot = provider.snapshots[index];
              final totalProducts = snapshot.productCounts.values
                  .fold(0, (sum, count) => sum + count);
              final totalCategories = snapshot.productCounts.length;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () => _showSnapshotDetailsDialog(context, snapshot),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.inventory_2_outlined,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    snapshot.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Fecha: ${snapshot.getFormattedDate()}',
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