import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../inventory/entity/analytics_report.dart';
import '../../../inventory/entity/inventory_report.dart';
import '../../../inventory/screen/analytics_screen.dart';
import '../../../inventory/screen/inventory_report_screen.dart';
import '../../../inventory/screen/inventory_snapshot_screen.dart';
import '../../../inventory/services/analytics_provider.dart';
import '../../../inventory/services/inventory_comparison_provider.dart';
import '../../../inventory/services/inventory_report_provider.dart';
import '../../../services/auth_services/auth_provider.dart';
import 'no_permission_view.dart';
import 'recent_report_item.dart';
import 'report_option_card.dart';

class ReportsTab extends StatelessWidget {
  const ReportsTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.centerId == null) {
      return const NoPermissionView(message: 'No tiene un centro asignado');
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título con estilo
            const Text(
              'Reportes y Análisis',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Genere informes y analice datos para tomar mejores decisiones',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),

            // Sección de Reportes recientes
            _buildRecentReportsSection(context),

            const SizedBox(height: 24),

            // Sección de Opciones de Reportes
            _buildSectionTitle('Tipos de Reportes'),
            const SizedBox(height: 16),

            // Informes de reposición
            ReportOptionCard(
              title: 'Informes de Reposición',
              subtitle: 'Productos que necesitan reponerse',
              icon: Icons.assignment_rounded,
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const InventoryReportScreen(),
                  ),
                );
              },
            ),

            // Análisis de consumo
            ReportOptionCard(
              title: 'Análisis de Consumo',
              subtitle: 'Estadísticas de consumo por período',
              icon: Icons.analytics_rounded,
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AnalyticsScreen(),
                  ),
                );
              },
            ),

            // Historial de instantáneas
            ReportOptionCard(
              title: 'Historial de Instantáneas',
              subtitle: 'Comparar estados de inventario',
              icon: Icons.history_rounded,
              color: Colors.teal,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const InventorySnapshotScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentReportsSection(BuildContext context) {
    final Color primaryColor = const Color(0xFF2c6bed);
    final reportProvider = Provider.of<InventoryReportProvider>(context);
    final analyticsProvider = Provider.of<AnalyticsProvider>(context);
    final snapshotProvider = Provider.of<InventoryComparisonProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    // Get most recent inventory reports
    final inventoryReports = reportProvider.reports;

    // Get most recent analytics reports
    final analyticsReports = analyticsProvider.reports;

    // Get most recent snapshots
    final snapshots = snapshotProvider.snapshots;

    // Combined list of all recent activities for sorting
    List<Map<String, dynamic>> combinedReports = [];

    // Add inventory reports
    for (var report in inventoryReports) {
      combinedReports.add({
        'type': 'inventory',
        'data': report,
        'date': DateTime.parse(report.createdAt),
      });
    }

    // Add analytics reports
    for (var report in analyticsReports) {
      combinedReports.add({
        'type': 'analytics',
        'data': report,
        'date': DateTime.parse(report.createdAt),
      });
    }

    // Add snapshots
    for (var snapshot in snapshots) {
      combinedReports.add({
        'type': 'snapshot',
        'data': snapshot,
        'date': DateTime.parse(snapshot.createdAt),
      });
    }

    // Sort by date (most recent first)
    combinedReports.sort((a, b) => b['date'].compareTo(a['date']));

    // Take only the 3 most recent reports
    final recentReports = combinedReports.take(3).toList();

    // Refresh data function
    void refreshData() async {
      if (authProvider.centerId != null) {
        // Show loading indicator or message
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Actualizando reportes...'))
        );

        // Refresh all providers
        await reportProvider.loadReports(authProvider.centerId!);
        await analyticsProvider.loadReports(authProvider.centerId!);
        await snapshotProvider.loadInventorySnapshots(authProvider.centerId!);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reportes actualizados correctamente'))
        );
      }
    }

    // Format date from DateTime
    String _formatDate(DateTime date) {
      final now = DateTime.now();

      if (date.year == now.year && date.month == now.month && date.day == now.day) {
        return 'Hoy, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (date.year == now.year && date.month == now.month && date.day == now.day - 1) {
        return 'Ayer, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else {
        return '${date.day} ${_getMonthAbbr(date.month)}, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reportes Recientes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.refresh, color: primaryColor, size: 20),
                    onPressed: refreshData,
                    tooltip: 'Actualizar reportes',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      // Ver todos los reportes
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const InventoryReportScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Ver todos',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (recentReports.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Column(
                  children: [
                    Icon(Icons.assignment_outlined, size: 40, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'No hay reportes recientes',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Cree un reporte o instantánea para visualizarlo aquí',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: List.generate(recentReports.length, (index) {
                final report = recentReports[index];
                final type = report['type'];
                final data = report['data'];
                final date = report['date'] as DateTime;

                if (type == 'inventory') {
                  final inventoryReport = data as InventoryReport;
                  final priorityCount = inventoryReport.getPriorityProducts().length;

                  return Column(
                    children: [
                      RecentReportItem(
                        title: inventoryReport.name,
                        date: _formatDate(date),
                        detail: priorityCount > 0
                            ? '$priorityCount productos prioritarios'
                            : 'Reporte de reposición',
                        color: Colors.orange,
                      ),
                      if (index < recentReports.length - 1)
                        const Divider(height: 24),
                    ],
                  );
                } else if (type == 'analytics') {
                  final analyticsReport = data as AnalyticsReport;
                  final categoryCount = analyticsReport.categories.length;

                  return Column(
                    children: [
                      RecentReportItem(
                        title: analyticsReport.name,
                        date: _formatDate(date),
                        detail: 'Análisis de $categoryCount categorías',
                        color: Colors.blue,
                      ),
                      if (index < recentReports.length - 1)
                        const Divider(height: 24),
                    ],
                  );
                } else {
                  // Must be a snapshot
                  final snapshot = data;
                  final productCount = snapshot.productCounts.values.fold(0, (sum, value) => sum + value);

                  return Column(
                    children: [
                      RecentReportItem(
                        title: snapshot.name,
                        date: _formatDate(date),
                        detail: '$productCount productos registrados',
                        color: Colors.teal,
                      ),
                      if (index < recentReports.length - 1)
                        const Divider(height: 24),
                    ],
                  );
                }
              }),
            ),
        ],
      ),
    );
  }

  String _getMonthAbbr(int month) {
    const months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return months[month - 1];
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}