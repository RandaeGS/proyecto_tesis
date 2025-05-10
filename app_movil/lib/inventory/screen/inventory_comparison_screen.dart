import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../entity/inventory_difference.dart';
import '../services/inventory_comparison_provider.dart';
import '../services/inventory_comparison_services.dart';
import '../entity/inventory_snapshot.dart';

class InventoryComparisonScreen extends StatefulWidget {
  const InventoryComparisonScreen({Key? key}) : super(key: key);

  @override
  State<InventoryComparisonScreen> createState() => _InventoryComparisonScreenState();
}

class _InventoryComparisonScreenState extends State<InventoryComparisonScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comparar inventarios'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Limpiar selecciones y resultados
              Provider.of<InventoryComparisonProvider>(
                context,
                listen: false,
              ).clearComparison();
            },
            tooltip: 'Limpiar selección',
          ),
        ],
      ),
      body: Consumer<InventoryComparisonProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.snapshots.length < 2) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.compare_arrows,
                      size: 64,
                      color: Colors.grey[400],
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
                        'Crea al menos 2 instantáneas de inventario para poder compararlas',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Volver'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              // Selección de instantáneas
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selecciona 2 instantáneas para comparar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSnapshotSelector(
                            context,
                            'Instantánea base',
                            provider.baseSnapshot,
                            Colors.blue,
                                (snapshot) => provider.selectBaseSnapshot(snapshot),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSnapshotSelector(
                            context,
                            'Instantánea comparación',
                            provider.comparisonSnapshot,
                            Colors.green,
                                (snapshot) => provider.selectComparisonSnapshot(snapshot),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Resultados de la comparación
              if (provider.baseSnapshot != null &&
                  provider.comparisonSnapshot != null &&
                  provider.comparisonResults.isNotEmpty)
                Expanded(
                  child: _buildComparisonResults(context, provider),
                )
              else if (provider.baseSnapshot != null &&
                  provider.comparisonSnapshot != null)
                const Expanded(
                  child: Center(
                    child: Text('Comparando inventarios...'),
                  ),
                )
              else
                const Expanded(
                  child: Center(
                    child: Text('Selecciona dos instantáneas para ver la comparación'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSnapshotSelector(
      BuildContext context,
      String label,
      InventorySnapshot? selectedSnapshot,
      Color color,
      Function(InventorySnapshot) onSelect,
      ) {
    return InkWell(
      onTap: () => _showSnapshotSelectionDialog(context, onSelect),
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
      BuildContext context,
      Function(InventorySnapshot) onSelect,
      ) {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer<InventoryComparisonProvider>(
          builder: (context, provider, child) {
            return AlertDialog(
              title: const Text('Seleccionar instantánea'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: provider.snapshots.length,
                  itemBuilder: (context, index) {
                    final snapshot = provider.snapshots[index];
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
            );
          },
        );
      },
    );
  }

  Widget _buildComparisonResults(
      BuildContext context,
      InventoryComparisonProvider provider,
      ) {
    if (provider.comparisonResults.isEmpty) {
      return const Center(
        child: Text('No hay resultados de comparación disponibles'),
      );
    }

    // Formatear fechas para mostrarlas en la cabecera
    final baseDate = provider.baseSnapshot!.getFormattedDate();
    final comparisonDate = provider.comparisonSnapshot!.getFormattedDate();

    // Organizar las diferencias para mostrarlas
    final differences = provider.comparisonResults.values.toList();

    // Separar aumentos, disminuciones y sin cambios
    final increases = differences.where((d) => d.difference > 0).toList();
    final decreases = differences.where((d) => d.difference < 0).toList();
    final noChanges = differences.where((d) => d.difference == 0).toList();

    // Ordenar por magnitud del cambio (de mayor a menor)
    increases.sort((a, b) => b.difference.compareTo(a.difference));
    decreases.sort((a, b) => a.difference.compareTo(b.difference)); // Negativo primero

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Resumen de la comparación
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumen de la comparación',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_month,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[800],
                            ),
                            children: [
                              const TextSpan(
                                text: 'Comparando ',
                              ),
                              TextSpan(
                                text: provider.baseSnapshot!.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const TextSpan(
                                text: ' con ',
                              ),
                              TextSpan(
                                text: provider.comparisonSnapshot!.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      children: [
                        TextSpan(text: 'Del $baseDate al $comparisonDate'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Estadísticas de cambios
                  Row(
                    children: [
                      _buildChangeStatistic(
                        'Aumentos',
                        increases.length,
                        Icons.arrow_upward,
                        Colors.green,
                      ),
                      _buildChangeStatistic(
                        'Disminuciones',
                        decreases.length,
                        Icons.arrow_downward,
                        Colors.red,
                      ),
                      _buildChangeStatistic(
                        'Sin cambios',
                        noChanges.length,
                        Icons.remove,
                        Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Productos con aumento
          if (increases.isNotEmpty) ...[
            _buildChangeSection(
              'Productos con aumento',
              increases,
              Colors.green,
              Icons.arrow_upward,
            ),
            const SizedBox(height: 24),
          ],

          // Productos con disminución
          if (decreases.isNotEmpty) ...[
            _buildChangeSection(
              'Productos con disminución',
              decreases,
              Colors.red,
              Icons.arrow_downward,
            ),
            const SizedBox(height: 24),
          ],

          // Productos sin cambios
          if (noChanges.isNotEmpty) ...[
            _buildChangeSection(
              'Productos sin cambios',
              noChanges,
              Colors.grey,
              Icons.remove,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChangeStatistic(
      String label,
      int count,
      IconData icon,
      Color color,
      ) {
    return Expanded(
      child: Card(
        color: color.withOpacity(0.1),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            children: [
              Icon(
                icon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChangeSection(
      String title,
      List<InventoryDifference> items,
      Color color,
      IconData icon,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => _buildDifferenceItem(item, color)),
      ],
    );
  }

  Widget _buildDifferenceItem(InventoryDifference difference, Color color) {
    // Calcular el texto de cambio
    final change = difference.difference.abs();
    final changeText = difference.difference > 0
        ? '+$change'
        : difference.difference < 0
        ? '-$change'
        : '0';

    // Calcular la barra de progreso
    double progressValue = 0.0;
    if (difference.initialCount > 0 && difference.currentCount > 0) {
      progressValue = difference.currentCount /
          (difference.initialCount > difference.currentCount
              ? difference.initialCount
              : difference.currentCount);
    } else if (difference.initialCount == 0 && difference.currentCount > 0) {
      progressValue = 1.0;
    } else if (difference.initialCount > 0 && difference.currentCount == 0) {
      progressValue = 0.0;
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    difference.category,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    changeText,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${difference.initialCount} → ${difference.currentCount} unidades',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            if (difference.percentageChange != 'N/A')
              Text(
                'Cambio: ${difference.percentageChange}',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                ),
              ),
            const SizedBox(height: 8),
            // Barra de progreso
            Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                Container(
                  height: 10,
                  width: MediaQuery.of(context).size.width * 0.7 * progressValue,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}