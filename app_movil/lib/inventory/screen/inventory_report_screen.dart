import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../services/auth_services/auth_provider.dart';
import '../entity/inventory_report.dart';
import '../entity/inventory_snapshot.dart';
import '../services/inventory_comparison_provider.dart';
import '../services/inventory_report_provider.dart';
import '../services/inventory_report_sevices.dart';
import 'category_products_screen.dart';

class InventoryReportScreen extends StatefulWidget {
  final InventorySnapshot? selectedSnapshot;

  const InventoryReportScreen({
    Key? key,
    this.selectedSnapshot,
  }) : super(key: key);

  @override
  State<InventoryReportScreen> createState() => _InventoryReportScreenState();
}

class _InventoryReportScreenState extends State<InventoryReportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _centerId;
  bool _isLoading = true;
  Map<String, int> _customIdealCounts = {};
  Map<String, TextEditingController> _idealCountControllers = {};
  bool _configInitialized = false;
  bool _reportsLoaded = false;
  Set<String> _activeCategories = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() => _initialize());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _clearControllers();
    super.dispose();
  }

  void _clearControllers() {
    _idealCountControllers.forEach((_, controller) => controller.dispose());
    _idealCountControllers = {};
  }

  Future<void> _initialize() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _centerId = authProvider.centerId;

      if (_centerId != null) {
        try {
          await Provider.of<InventoryReportProvider>(context, listen: false)
              .loadReports(_centerId!);
          _reportsLoaded = true;
          _extractActiveCategoriesFromReports();
        } catch (e) {
          debugPrint('Error al cargar informes: $e');
        }

        await _loadSavedConfiguration();
        await _initializeControllers();
      }
    } catch (e) {
      debugPrint('Error en inicialización: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _extractActiveCategoriesFromReports() {
    try {
      final reportProvider = Provider.of<InventoryReportProvider>(context, listen: false);
      final reports = reportProvider.reports;

      _activeCategories = {};

      for (var report in reports) {
        for (var category in report.productRecommendations.keys) {
          _activeCategories.add(category);
        }
      }

      debugPrint('Categorías activas encontradas en informes: $_activeCategories');

      if (_activeCategories.isEmpty) {
        _loadActiveCategoriesFromSnapshots();
      }

      if (_activeCategories.isEmpty) {
        _activeCategories = InventoryReportService.defaultIdealCounts.keys.toSet();
        debugPrint('Usando categorías predeterminadas: $_activeCategories');
      }
    } catch (e) {
      debugPrint('Error al extraer categorías activas: $e');
    }
  }

  Future<void> _loadActiveCategoriesFromSnapshots() async {
    try {
      if (_centerId == null) return;

      final snapshotProvider = Provider.of<InventoryComparisonProvider>(context, listen: false);
      await snapshotProvider.loadInventorySnapshots(_centerId!);

      final snapshots = snapshotProvider.snapshots;

      for (var snapshot in snapshots) {
        for (var category in snapshot.productCounts.keys) {
          _activeCategories.add(category);
        }
      }

      debugPrint('Categorías activas encontradas en snapshots: $_activeCategories');
    } catch (e) {
      debugPrint('Error al cargar categorías desde snapshots: $e');
    }
  }

  Future<void> _loadSavedConfiguration() async {
    try {
      if (_centerId == null) return;

      final prefs = await SharedPreferences.getInstance();
      final savedConfig = prefs.getString('ideal_counts_${_centerId}');

      if (savedConfig != null && savedConfig.isNotEmpty) {
        debugPrint('Cargando configuración guardada');
        final Map<String, dynamic> savedMap = json.decode(savedConfig);

        // Filtrar solo las categorías activas
        final filteredConfig = savedMap.map(
          (key, value) => MapEntry(key, value is int ? value : int.tryParse(value.toString()) ?? 0)
        )..removeWhere((key, _) => !_activeCategories.contains(key));

        _customIdealCounts = filteredConfig;
        debugPrint('Configuración cargada (filtrada por categorías activas): $_customIdealCounts');
      } else {
        debugPrint('No se encontró configuración guardada');
        _customIdealCounts = {};
        for (var category in _activeCategories) {
          _customIdealCounts[category] = InventoryReportService.defaultIdealCounts[category] ?? 0;
        }
      }
    } catch (e) {
      debugPrint('Error al cargar configuración guardada: $e');
    }
  }

  Future<void> _saveConfiguration() async {
    try {
      if (_centerId == null) return;

      _updateCustomIdealCounts();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ideal_counts_${_centerId}', json.encode(_customIdealCounts));

      debugPrint('Configuración guardada: $_customIdealCounts');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración guardada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Error al guardar configuración: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar configuración: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _initializeControllers() async {
    _clearControllers();

    try {
      // Solo inicializar controladores para categorías activas
      for (var category in _activeCategories) {
        var value = _customIdealCounts[category] ?? 
                   InventoryReportService.defaultIdealCounts[category] ?? 0;
        
        _customIdealCounts[category] = value;
        _idealCountControllers[category] = TextEditingController(text: value.toString());
      }

      _configInitialized = true;

      if (mounted) {
        setState(() {});
      }

      debugPrint('Controladores inicializados para categorías: ${_idealCountControllers.keys}');
    } catch (e) {
      debugPrint('Error al inicializar controladores: $e');
    }
  }

  void _updateCustomIdealCounts() {
    final updatedCounts = <String, int>{};
    _idealCountControllers.forEach((category, controller) {
      final count = int.tryParse(controller.text);
      if (count != null) {
        updatedCounts[category] = count;
      }
    });

    _customIdealCounts = updatedCounts;
    debugPrint('Configuración actualizada: $_customIdealCounts');
  }

  Future<void> _generateReport(bool isEmergency) async {
    if (_centerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo identificar el centro'))
      );
      return;
    }

    // Asegurarse de usar la configuración más reciente
    _updateCustomIdealCounts();
    await _saveConfiguration();

    final inventorySnapshot = widget.selectedSnapshot ?? await _getLatestSnapshot();

    if (inventorySnapshot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay instantáneas de inventario disponibles'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('Generando informe con custom ideal counts: $_customIdealCounts');
      final report = await Provider.of<InventoryReportProvider>(context, listen: false)
          .generateReport(
        inventorySnapshot,
        isEmergency: isEmergency,
        customIdealCounts: _customIdealCounts, // Usar configuración actualizada
      );

      if (report != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Informe generado: ${report.name}'),
            backgroundColor: Colors.green,
          ),
        );

        try {
          await Provider.of<InventoryReportProvider>(context, listen: false)
              .loadReports(_centerId!);
          _reportsLoaded = true;
          _extractActiveCategoriesFromReports();
          await _initializeControllers();
        } catch (e) {
          debugPrint('Error al recargar informes: $e');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar informe: $e'),
            backgroundColor: Colors.red,
          ),
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

  Future<InventorySnapshot?> _getLatestSnapshot() async {
    final snapshotProvider = Provider.of<InventoryComparisonProvider>(context, listen: false);

    if (_centerId != null) {
      try {
        await snapshotProvider.loadInventorySnapshots(_centerId!);
      } catch (e) {
        debugPrint('Error al cargar instantáneas: $e');
      }
    }

    if (snapshotProvider.snapshots.isEmpty) {
      return null;
    }

    return snapshotProvider.snapshots.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informes de Inventario'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Informes'),
            Tab(text: 'Configuración'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar datos',
            onPressed: _isLoading
                ? null
                : () async {
              setState(() => _isLoading = true);
              try {
                _updateCustomIdealCounts();
                if (_centerId != null) {
                  await Provider.of<InventoryReportProvider>(context, listen: false)
                      .loadReports(_centerId!);
                  _reportsLoaded = true;
                }
              } catch (e) {
                debugPrint('Error al recargar datos: $e');
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildReportsTab(),
          _buildSettingsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
      onPressed: _isLoading ? null : _showGenerateReportDialog,
    backgroundColor: Colors.blue,
    icon: const Icon(Icons.add, color: Colors.white),
    label: const Text('Generar informe', style: TextStyle(color: Colors.white)),
    ),
    );
  }

  Widget _buildReportsTab() {
    return Consumer<InventoryReportProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
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
                    'Error al cargar informes',
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
                    onPressed: () {
                      if (_centerId != null) {
                        provider.loadReports(_centerId!);
                      }
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        if (provider.reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                const Text(
                  'No hay informes de inventario',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Genera un informe para ver recomendaciones de reposición',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _showGenerateReportDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('Generar informe'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (provider.priorityProducts.isNotEmpty) ...[
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.priority_high,
                              color: Colors.red[700],
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Productos Prioritarios',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Estos productos requieren atención inmediata:',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        ...provider.priorityProducts.entries.map((entry) {
                          final product = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4
                              ),
                              tileColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(color: Colors.red.shade200),
                              ),
                              leading: CircleAvatar(
                                backgroundColor: Colors.red,
                                child: Text(
                                  product.priority.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                product.category,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Actual: ${product.currentCount} | Ideal: ${product.idealCount}'),
                                  if (product.note.isNotEmpty)
                                    Text(
                                      product.note,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${product.replenishAmount}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const Text(
                                    'faltantes',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              onTap: () {
                                if (_centerId != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CategoryProductsScreen(
                                        category: product.category,
                                        centerId: _centerId!,
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        }).toList(),
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton.icon(
                            onPressed: () {
                              if (_centerId != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CategoryProductsScreen(
                                      showAllCategories: true,
                                      centerId: _centerId!,
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.list_alt),
                            label: const Text('Ver todas las categorías'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              const Text(
                'Informes Recientes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...provider.reports.map((report) => _buildReportCard(report)).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportCard(InventoryReport report) {
    int totalProducts = 0;
    int totalMissing = 0;
    int highPriorityCount = 0;

    report.productRecommendations.forEach((_, info) {
      totalProducts++;
      totalMissing += info.replenishAmount > 0 ? 1 : 0;
      highPriorityCount += info.priority >= 4 ? 1 : 0;
    });

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: report.isEmergency ? Colors.orange.shade50 : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showReportDetails(report),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (report.isEmergency)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'EMERGENCIA',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      report.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => _confirmDeleteReport(report),
                    color: Colors.red,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Eliminar',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Creado: ${report.getFormattedDate()}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildReportStat(
                    'Categorías',
                    totalProducts.toString(),
                    Icons.category,
                  ),
                  _buildReportStat(
                    'Por reponer',
                    totalMissing.toString(),
                    Icons.shopping_cart,
                  ),
                  _buildReportStat(
                    'Prioritarios',
                    highPriorityCount.toString(),
                    Icons.priority_high,
                    color: highPriorityCount > 0 ? Colors.red : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportStat(String label, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(
          icon,
          color: color ?? Colors.blue,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
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

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configuración de cantidades ideales',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Establece las cantidades ideales para cada categoría de producto. Estas cantidades se utilizarán para calcular las recomendaciones de reposición.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),

          if (!_configInitialized)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Cargando configuración...\nGenere un informe primero si no hay configuración disponible.",
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (_idealCountControllers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "No hay categorías configuradas. Se utilizarán valores predeterminados al generar informes.",
                textAlign: TextAlign.center,
              ),
            )
          else
            ..._idealCountControllers.entries.map((entry) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: entry.value,
                          decoration: InputDecoration(
                            labelText: 'Cantidad ideal para ${entry.key}',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            suffixText: 'unidades',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDeleteCategory(entry.key),
                        tooltip: 'Eliminar categoría',
                      ),
                    ],
                  ),
                ),
            ).toList(),

          const SizedBox(height: 24),

          if (_configInitialized)
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blue.shade100),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Añadir nueva categoría',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _showAddCategoryDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Añadir categoría'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),

          if (_configInitialized)
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Guardar configuración'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                onPressed: _saveConfiguration,
              ),
            ),

          const SizedBox(height: 24),

          const Card(
            elevation: 1,
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¿Cómo funciona?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'La prioridad de reposición se calcula automáticamente basándose en la diferencia entre la cantidad actual y la ideal:',
                    style: TextStyle(fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  Text('• Prioridad 1: Diferencia menor al 10%'),
                  Text('• Prioridad 2: Diferencia entre 10% y 30%'),
                  Text('• Prioridad 3: Diferencia entre 30% y 50%'),
                  Text('• Prioridad 4: Diferencia entre 50% y 75%'),
                  Text('• Prioridad 5: Diferencia mayor al 75%'),
                  SizedBox(height: 8),
                  Text(
                    'En modo emergencia, las prioridades se asignan según la importancia de cada categoría para situaciones críticas.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteCategory(String category) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text(
          '¿Estás seguro de que deseas eliminar la categoría "$category"?\n\n'
              'Esta acción no afectará a los informes existentes, pero la categoría no se incluirá en futuros informes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      setState(() {
        _idealCountControllers[category]?.dispose();
        _idealCountControllers.remove(category);
        _customIdealCounts.remove(category);
      });
      
      // Guardar los cambios
      await _saveConfiguration();
    }
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    final countController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Añadir nueva categoría'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la categoría',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: countController,
              decoration: const InputDecoration(
                labelText: 'Cantidad ideal',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              nameController.dispose();
              countController.dispose();
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('El nombre de la categoría no puede estar vacío'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (_idealCountControllers.containsKey(name)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Esta categoría ya existe'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              final count = int.tryParse(countController.text) ?? 0;

              Navigator.of(context).pop();

              setState(() {
                _idealCountControllers[name] = TextEditingController(text: count.toString());
                _customIdealCounts[name] = count;
                _activeCategories.add(name);
              });

              _saveConfiguration();

              nameController.dispose();
              countController.dispose();
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }

  Future<void> _showGenerateReportDialog() async {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generar informe'),
        content: const Text(
          '¿Qué tipo de informe deseas generar?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _generateReport(false);
            },
            child: const Text('Informe estándar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _generateReport(true);
            },
            child: const Text('Informe de emergencia'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteReport(InventoryReport report) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar informe'),
        content: Text(
          '¿Estás seguro de que deseas eliminar el informe "${report.name}"?\n\n'
              'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (result == true && mounted && _centerId != null) {
      try {
        await Provider.of<InventoryReportProvider>(
          context,
          listen: false,
        ).deleteReport(_centerId!, report.id);
      } catch (e) {
        debugPrint('Error al eliminar informe: $e');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar informe: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showReportDetails(InventoryReport report) {
    final recommendationsByPriority = report.getRecommendationsByPriority();

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
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Row(
                  children: [
                    if (report.isEmergency)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'EMERGENCIA',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        report.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Creado: ${report.getFormattedDate()}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 24),

                for (int priority = 5; priority >= 1; priority--) ...[
                  if (recommendationsByPriority[priority]!.isNotEmpty) ...[
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: _getPriorityColor(priority),
                          child: Text(
                            priority.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Prioridad $priority',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _getPriorityColor(priority),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    ...recommendationsByPriority[priority]!.map((entry) {
                      final product = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(product.category),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Actual: ${product.currentCount} | Ideal: ${product.idealCount}'),
                              if (product.note.isNotEmpty)
                                Text(
                                  product.note,
                                  style: const TextStyle(color: Colors.red),
                                ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${product.replenishAmount}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const Text(
                                'faltantes',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          tileColor: _getPriorityColor(priority).withOpacity(0.1),
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 16),
                  ],
                ],

                Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      if (_centerId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CategoryProductsScreen(
                              showAllCategories: true,
                              centerId: _centerId!,
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.category),
                    label: const Text('Ver todas las categorías'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 5:
        return Colors.red;
      case 4:
        return Colors.orange;
      case 3:
        return Colors.amber;
      case 2:
        return Colors.blue;
      case 1:
      default:
        return Colors.green;
    }
  }
}