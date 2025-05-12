import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_services/auth_provider.dart';
import '../entity/analytics_report.dart';
import '../entity/inventory_snapshot.dart';
import '../services/analytics_provider.dart';
import '../services/inventory_comparison_provider.dart';
import 'report_detail_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  int? _centerId;
  List<String> _selectedCategories = [];
  PeriodType _selectedPeriodType = PeriodType.weekly;
  InventorySnapshot? _startSnapshot;
  InventorySnapshot? _endSnapshot;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    // Primero establecemos el estado inicial
    setState(() {
      _centerId = Provider.of<AuthProvider>(context, listen: false).centerId;
      _isLoading = false; // Empezamos con loading = false para evitar problemas
    });

    if (_centerId != null) {
      // Debemos usar Future.microtask para evitar llamar a Provider durante el build
      Future.microtask(() async {
        // Intentamos cargar los datos en segundo plano
        try {
          // Marcar como loading antes de cargar
          setState(() {
            _isLoading = true;
          });

          // Load existing analytics reports
          await Provider.of<AnalyticsProvider>(context, listen: false)
              .loadReports(_centerId!);

          // Load snapshots for selection
          await Provider.of<InventoryComparisonProvider>(context, listen: false)
              .loadInventorySnapshots(_centerId!);
        } catch (e) {
          debugPrint('Error al inicializar: $e');
        } finally {
          // Marcar como no loading al finalizar
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Análisis de Consumo'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Mis Reportes'),
            Tab(text: 'Crear Reporte'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _centerId == null
          ? _buildNoCenterView()
          : TabBarView(
        controller: _tabController,
        children: [
          _buildReportsTab(),
          _buildCreateReportTab(),
        ],
      ),
    );
  }

  Widget _buildNoCenterView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
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

  Widget _buildReportsTab() {
    return Consumer<AnalyticsProvider>(
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
                    'Error al cargar reportes',
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
                  Icons.analytics_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                const Text(
                  'No hay reportes analíticos',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Crea un reporte analítico para visualizar el consumo de productos',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    _tabController.animateTo(1);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Crear reporte'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        // Display list of reports
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: provider.reports.length,
          itemBuilder: (context, index) {
            final report = provider.reports[index];
            return _buildReportCard(report);
          },
        );
      },
    );
  }

  Widget _buildReportCard(AnalyticsReport report) {
    // Determine color based on period type
    final periodType = report.getPeriodTypeEnum();
    final color = periodType == PeriodType.weekly
        ? Colors.blue
        : Colors.green;

    // Get report statistics
    final totalCategories = report.categories.length;
    final maxConsumptionCategory = report.getMostConsumedCategory();
    final totalConsumption = report.totalConsumption.values.fold(0, (sum, value) => sum + value);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReportDetailScreen(report: report),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and icons
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      periodType == PeriodType.weekly
                          ? 'SEMANAL'
                          : 'MENSUAL',
                      style: const TextStyle(
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

              // Date and range
              Text(
                'Creado: ${report.getFormattedDate()}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Período: ${report.dateRange.getFormattedRange()}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),

              // Statistics
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    'Categorías',
                    totalCategories.toString(),
                    Icons.category,
                  ),
                  _buildStatColumn(
                    'Movimiento Total',
                    totalConsumption.toString(),
                    Icons.shopping_basket,
                  ),
                  _buildStatColumn(
                    'Mayor Movimiento',
                    maxConsumptionCategory != 'N/A'
                        ? maxConsumptionCategory.split(' ').first
                        : 'N/A',
                    Icons.trending_up,
                    valueColor: color,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon, {Color? valueColor}) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.blue,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
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

  Widget _buildCreateReportTab() {
    return Consumer2<InventoryComparisonProvider, AnalyticsProvider>(
      builder: (context, comparisonProvider, analyticsProvider, child) {
        if (comparisonProvider.isLoading || analyticsProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (comparisonProvider.snapshots.length < 2) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Se necesitan al menos 2 instantáneas',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Para generar un reporte de consumo, necesitas al menos dos instantáneas de inventario para comparar',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed('/inventory'),
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Crear instantáneas'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Get all available categories by combining categories from all snapshots
        final allCategories = <String>{};
        for (final snapshot in comparisonProvider.snapshots) {
          allCategories.addAll(snapshot.productCounts.keys);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and instructions
              const Text(
                'Nuevo Reporte Analítico',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Selecciona dos instantáneas y configura los parámetros para generar un reporte analítico de consumo.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Period type selection
              const Text(
                'Tipo de Análisis',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildPeriodTypeSelection(
                      title: 'Semanal',
                      icon: Icons.calendar_view_week,
                      isSelected: _selectedPeriodType == PeriodType.weekly,
                      onTap: () {
                        setState(() {
                          _selectedPeriodType = PeriodType.weekly;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPeriodTypeSelection(
                      title: 'Mensual',
                      icon: Icons.calendar_month,
                      isSelected: _selectedPeriodType == PeriodType.monthly,
                      onTap: () {
                        setState(() {
                          _selectedPeriodType = PeriodType.monthly;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Snapshot selection
              const Text(
                'Rango de Fechas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildSnapshotSelector(
                      'Instantánea Inicial',
                      _startSnapshot,
                      Colors.blue,
                          (snapshot) {
                        setState(() {
                          _startSnapshot = snapshot;
                        });
                      },
                      comparisonProvider.snapshots,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSnapshotSelector(
                      'Instantánea Final',
                      _endSnapshot,
                      Colors.green,
                          (snapshot) {
                        setState(() {
                          _endSnapshot = snapshot;
                        });
                      },
                      comparisonProvider.snapshots,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Category selection
              const Text(
                'Categorías a Analizar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Selecciona las categorías que deseas incluir en el análisis:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allCategories.map((category) {
                  final isSelected = _selectedCategories.contains(category);
                  return FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedCategories.add(category);
                        } else {
                          _selectedCategories.remove(category);
                        }
                      });
                    },
                    selectedColor: Colors.blue.shade100,
                    checkmarkColor: Colors.blue,
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              if (allCategories.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategories = [];
                        });
                      },
                      child: const Text('Deseleccionar todas'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategories = allCategories.toList();
                        });
                      },
                      child: const Text('Seleccionar todas'),
                    ),
                  ],
                ),
              const SizedBox(height: 24),

              // Report name (optional)
              TextField(
                decoration: InputDecoration(
                  labelText: 'Nombre del Reporte (opcional)',
                  hintText: 'Ej. Consumo semanal de abril',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) {
                  // Store name to use when generating the report
                },
              ),
              const SizedBox(height: 24),

              // Button to generate report
              Center(
                child: ElevatedButton.icon(
                  onPressed: _canGenerateReport()
                      ? () => _generateReport(analyticsProvider)
                      : null,
                  icon: const Icon(Icons.analytics),
                  label: const Text('Generar Reporte Analítico'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeriodTypeSelection({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? Colors.blue : Colors.grey.shade600,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue : Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSnapshotSelector(
      String label,
      InventorySnapshot? selectedSnapshot,
      Color color,
      Function(InventorySnapshot) onSelect,
      List<InventorySnapshot> snapshots,
      ) {
    return InkWell(
      onTap: () => _showSnapshotSelectionDialog(onSelect, snapshots),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: selectedSnapshot != null ? color : Colors.grey,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: selectedSnapshot != null ? color : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            selectedSnapshot != null
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedSnapshot.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  selectedSnapshot.getFormattedDate(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            )
                : Row(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 8),
                const Text(
                  'Seleccionar',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSnapshotSelectionDialog(
      Function(InventorySnapshot) onSelect,
      List<InventorySnapshot> snapshots,
      ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar instantánea'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: snapshots.length,
            itemBuilder: (context, index) {
              final snapshot = snapshots[index];
              return ListTile(
                title: Text(snapshot.name),
                subtitle: Text(snapshot.getFormattedDate()),
                onTap: () {
                  onSelect(snapshot);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  bool _canGenerateReport() {
    return _startSnapshot != null &&
        _endSnapshot != null &&
        _selectedCategories.isNotEmpty;
  }

  Future<void> _generateReport(AnalyticsProvider provider) async {
    if (_centerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo identificar el centro')),
      );
      return;
    }

    if (!_canGenerateReport()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa todos los campos requeridos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate that the start date is before the end date
    final startDate = DateTime.parse(_startSnapshot!.createdAt);
    final endDate = DateTime.parse(_endSnapshot!.createdAt);

    if (startDate.isAfter(endDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La fecha inicial debe ser anterior a la fecha final'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final report = await provider.generateConsumptionReport(
        centerId: _centerId!,
        startSnapshot: _startSnapshot!,
        endSnapshot: _endSnapshot!,
        periodType: _selectedPeriodType,
        selectedCategories: _selectedCategories,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (report != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reporte generado correctamente'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate to reports tab
          _tabController.animateTo(0);

          // Select the newly created report
          provider.selectReport(report);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar el reporte: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteReport(AnalyticsReport report) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar reporte'),
        content: Text(
          '¿Estás seguro de que deseas eliminar el reporte "${report.name}"?\n\n'
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
      await Provider.of<AnalyticsProvider>(
        context,
        listen: false,
      ).deleteReport(_centerId!, report.id);
    }
  }
}