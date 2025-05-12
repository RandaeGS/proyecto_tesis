import 'package:app_movil/screens/home/widget/recent_report_item.dart';
import 'package:app_movil/screens/home/widget/report_option_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../inventory/screen/analytics_screen.dart';
import '../../../inventory/screen/inventory_report_screen.dart';
import '../../../inventory/screen/inventory_snapshot_screen.dart';
import '../../../services/auth_services/auth_provider.dart';
import 'no_permission_view.dart';

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
          const SizedBox(height: 12),

          // Lista de reportes recientes (simulados)
          const RecentReportItem(
            title: 'Informe de Reposición',
            date: 'Hoy, 10:30 AM',
            detail: '12 productos por reponer',
            color: Colors.orange,
          ),
          const Divider(height: 24),
          const RecentReportItem(
            title: 'Instantánea de Inventario',
            date: 'Ayer, 5:15 PM',
            detail: '46 productos registrados',
            color: Colors.teal,
          ),
          const Divider(height: 24),
          const RecentReportItem(
            title: 'Análisis Mensual',
            date: '12 May, 8:45 AM',
            detail: 'Consumo por categoría',
            color: Colors.blue,
          ),
        ],
      ),
    );
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