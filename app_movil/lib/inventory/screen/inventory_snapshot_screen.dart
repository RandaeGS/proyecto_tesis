import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/auth_services/auth_provider.dart';
import '../../../services/images/images_provider.dart';
import '../services/inventory_comparison_provider.dart';
import '../services/product_data_provider.dart';
import 'inventory_comparison_screen.dart';

class InventorySnapshotScreen extends StatefulWidget {
  const InventorySnapshotScreen({Key? key}) : super(key: key);

  @override
  State<InventorySnapshotScreen> createState() => _InventorySnapshotScreenState();
}

class _InventorySnapshotScreenState extends State<InventorySnapshotScreen> {
  int? _centerId;
  bool _isLoading = true;
  final _snapshotNameController = TextEditingController();
  final _snapshotDescriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _snapshotNameController.dispose();
    _snapshotDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _centerId = authProvider.centerId;
      _isLoading = true; // Set loading state
    });

    if (_centerId != null) {
      try {
        // Initialize the product data provider first
        final productDataProvider = Provider.of<ProductDataProvider>(context, listen: false);
        await productDataProvider.loadProductData(_centerId!);

        // Link the product data provider to the inventory comparison provider
        final inventoryProvider = Provider.of<InventoryComparisonProvider>(context, listen: false);
        inventoryProvider.setProductDataProvider(productDataProvider);

        // Load existing snapshots
        await inventoryProvider.loadInventorySnapshots(_centerId!);

        // Sync data with image provider
        final imageProvider = Provider.of<ServerImageProvider>(context, listen: false);
        await imageProvider.loadCenterImages(_centerId!);
        await productDataProvider.syncWithImageProvider(imageProvider, _centerId!);
      } catch (e) {
        debugPrint('Error initializing data: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false; // Set loading state to false
          });
        }
      }
    } else {
      setState(() {
        _isLoading = false; // Set loading state to false
      });
    }
  }

// Update the _createSnapshot method to ensure consistent data
  Future<void> _createSnapshot() async {
    if (_centerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo identificar el centro'))
      );
      return;
    }

    // Mostrar diálogo para ingresar nombre y descripción
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _buildSnapshotDialog(),
    );

    if (result != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      // Use the product data provider to create the snapshot
      final productDataProvider = Provider.of<ProductDataProvider>(context, listen: false);

      // First make sure we have the latest data
      await productDataProvider.loadProductData(_centerId!);

      // Update from image detections
      final imageProvider = Provider.of<ServerImageProvider>(context, listen: false);
      await productDataProvider.syncWithImageProvider(imageProvider, _centerId!);

      // Create the snapshot directly using the ProductDataProvider
      final success = await productDataProvider.createInventorySnapshot(
        _centerId!,
        _snapshotNameController.text,
        _snapshotDescriptionController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                success
                    ? 'Instantánea de inventario creada correctamente'
                    : 'Error al crear instantánea de inventario'
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );

        // Reload the snapshots
        if (success) {
          final inventoryProvider = Provider.of<InventoryComparisonProvider>(context, listen: false);
          await inventoryProvider.loadInventorySnapshots(_centerId!);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildSnapshotDialog() {
    return AlertDialog(
      title: const Text('Nueva instantánea de inventario'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _snapshotNameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la instantánea',
                hintText: 'Ej. Inventario inicial Mayo 2025',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _snapshotDescriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: 'Ej. Inventario después de la donación mensual',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_snapshotNameController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('El nombre es obligatorio'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            Navigator.of(context).pop(true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instantáneas de inventario'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              if (_centerId != null) {
                // Refresh all data in the correct order
                final productDataProvider = Provider.of<ProductDataProvider>(context, listen: false);
                await productDataProvider.loadProductData(_centerId!);

                await Provider.of<InventoryComparisonProvider>(
                  context,
                  listen: false,
                ).loadInventorySnapshots(_centerId!);
              }
            },
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _centerId == null
          ? _buildNoCenterView()
          : _buildSnapshotsView(),
      floatingActionButton: _centerId == null
          ? null
          : FloatingActionButton(
        onPressed: _createSnapshot,
        backgroundColor: Colors.blue,
        tooltip: 'Crear nueva instantánea',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildNoCenterView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'No se puede identificar el centro',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Por favor, asegúrate de que estás asignado a un centro',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Volver'),
          ),
        ],
      ),
    );
  }

  Widget _buildSnapshotsView() {
    return Consumer2<InventoryComparisonProvider, ProductDataProvider>(
      builder: (context, provider, productDataProvider, child) {
        if (provider.isLoading || productDataProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.errorMessage.isNotEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Error al cargar instantáneas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.errorMessage,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      if (_centerId != null) {
                        await provider.loadInventorySnapshots(_centerId!);
                      }
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        if (provider.snapshots.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                const Text(
                  'No hay instantáneas de inventario',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Crea una instantánea para comenzar a comparar inventarios a lo largo del tiempo',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _createSnapshot,
                  icon: const Icon(Icons.add),
                  label: const Text('Crear instantánea inicial'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        // Mostrar lista de instantáneas
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información del inventario actual
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.inventory,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Inventario Actual',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Mostrar un resumen del inventario actual desde el ProductDataProvider
                      Text(
                        'Categorías: ${productDataProvider.currentProductCounts.length}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total de productos: ${productDataProvider.currentProductCounts.values.fold(0, (prev, count) => prev + count)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Última actualizacion: ${_formatDateTime(productDataProvider.lastUpdated)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),

                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _createSnapshot,
                        icon: const Icon(Icons.add),
                        label: const Text('Crear instantánea'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Cabecera con información
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Instantáneas de inventario',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Las instantáneas te permiten guardar el estado del inventario en un momento específico para comparar cambios a lo largo del tiempo.',
                        style: TextStyle(fontSize: 14),
                      ),
                      if (provider.snapshots.length >= 2) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const InventoryComparisonScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.compare_arrows),
                          label: const Text('Comparar inventarios'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Text(
                'Instantáneas guardadas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Lista de instantáneas
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: provider.snapshots.length,
                itemBuilder: (context, index) {
                  final snapshot = provider.snapshots[index];

                  // Contar categorías y productos
                  final totalProducts = snapshot.productCounts.values
                      .fold(0, (sum, count) => sum + count);
                  final totalCategories = snapshot.productCounts.keys.length;

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Cabecera con título e iconos
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  snapshot.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _confirmDeleteSnapshot(snapshot),
                                tooltip: 'Eliminar',
                              ),
                            ],
                          ),

                          // Fecha
                          Text(
                            'Creado: ${snapshot.getFormattedDate()}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),

                          // Descripción si existe
                          if (snapshot.description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              snapshot.description,
                              style: const TextStyle(
                                fontSize: 14,
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Estadísticas
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatItem(
                                  'Productos',
                                  totalProducts.toString(),
                                  Icons.shopping_bag_outlined,
                                ),
                              ),
                              Expanded(
                                child: _buildStatItem(
                                  'Categorías',
                                  totalCategories.toString(),
                                  Icons.category_outlined,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Botón para ver detalles
                          OutlinedButton.icon(
                            onPressed: () => _showSnapshotDetails(snapshot),
                            icon: const Icon(Icons.visibility_outlined),
                            label: const Text('Ver detalles'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.blue,
          size: 24,
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

  Future<void> _confirmDeleteSnapshot(dynamic snapshot) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar instantánea'),
        content: Text(
          '¿Estás seguro de que deseas eliminar la instantánea "${snapshot.name}"?\n\n'
              'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (result == true && mounted && _centerId != null) {
      await Provider.of<InventoryComparisonProvider>(
        context,
        listen: false,
      ).deleteInventorySnapshot(_centerId!, snapshot.id);
    }
  }

  void _showSnapshotDetails(dynamic snapshot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                snapshot.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Creado: ${snapshot.getFormattedDate()}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),

              if (snapshot.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  snapshot.description,
                  style: const TextStyle(fontSize: 16),
                ),
              ],

              const SizedBox(height: 24),
              const Text(
                'Detalle de productos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Lista de productos
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: snapshot.productCounts.length,
                  itemBuilder: (context, index) {
                    final category = snapshot.productCounts.keys.elementAt(index);
                    final count = snapshot.productCounts[category] ?? 0;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.primaries[index % Colors.primaries.length],
                        child: Text(
                          category.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(category),
                      trailing: Text(
                        count.toString(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Format DateTime to a readable string
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}