import 'package:app_movil/screens/home/widget/stat_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../inventory/screen/inventory_snapshot_screen.dart';
import '../../../inventory/screen/manual_inventory/manual_inventory_screen.dart';
import '../../../inventory/services/inventory_report_provider.dart';
import '../../../inventory/services/product_data_provider.dart';
import '../../../services/auth_services/auth_provider.dart';
import '../../image_capture_screen.dart';
import '../../product_managment/product_screen_managment.dart';
import 'inventory_option.dart';
import 'no_permission_view.dart';


class InventoryTab extends StatelessWidget {
  const InventoryTab({Key? key}) : super(key: key);

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
              'Gestión de Inventario',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Controle y supervise todos los aspectos de su inventario',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),

            // Sección de Estadísticas de Inventario
            _buildStatisticsSection(context),

            const SizedBox(height: 24),

            // Sección de Opciones de Inventario
            _buildSectionTitle('Opciones de Inventario'),
            const SizedBox(height: 16),

            // Captura de imágenes
            InventoryOptionCard(
              title: 'Captura de Imágenes',
              subtitle: 'Tomar fotos para detección automática',
              icon: Icons.camera_alt_rounded,
              color: Colors.purple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ImageCaptureScreen(),
                  ),
                );
              },
            ),

            // Gestión manual
            InventoryOptionCard(
              title: 'Gestión Manual',
              subtitle: 'Actualice el inventario manualmente',
              icon: Icons.edit_note_rounded,
              color: Colors.indigo,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ManualInventoryManagementScreen(
                      centerId: authProvider.centerId!,
                    ),
                  ),
                );
              },
            ),

            // Instantáneas
            InventoryOptionCard(
              title: 'Instantáneas de Inventario',
              subtitle: 'Guarde y compare estados del inventario',
              icon: Icons.compare_arrows_rounded,
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

            // Productos
            InventoryOptionCard(
              title: 'Gestión de Productos',
              subtitle: 'Ver y gestionar productos detectados',
              icon: Icons.inventory_2_rounded,
              color: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductManagementScreen(
                      centerId: authProvider.centerId!,
                    ),
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

  Widget _buildStatisticsSection(BuildContext context) {
    final Color primaryColor = const Color(0xFF2c6bed);
    final authProvider = Provider.of<AuthProvider>(context);
    final productProvider = Provider.of<ProductDataProvider>(context);
    final reportProvider = Provider.of<InventoryReportProvider>(context);

    // Get total products count
    final totalProducts = productProvider.currentProductCounts.values.fold(0, (sum, count) => sum + count);

    // Get total categories count
    final totalCategories = productProvider.currentProductCounts.length;

    // Get priority items (with alerts)
    final priorityProducts = reportProvider.priorityProducts.length;

    // Refresh function
    void refreshData() async {
      if (authProvider.centerId != null) {
        // Show loading indicator or message if needed
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Actualizando datos...'))
        );

        // Refresh product data
        await productProvider.loadProductData(authProvider.centerId!);

        // Refresh reports
        await reportProvider.loadReports(authProvider.centerId!);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Datos actualizados correctamente'))
        );
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
                'Resumen de Inventario',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: primaryColor, size: 20),
                onPressed: refreshData,
                tooltip: 'Actualizar datos',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  value: totalProducts.toString(),
                  label: 'Productos',
                  icon: Icons.category_rounded,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  value: totalCategories.toString(),
                  label: 'Categorías',
                  icon: Icons.list_alt_rounded,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  value: priorityProducts.toString(),
                  label: 'Prioritarios',
                  icon: Icons.error_outline_rounded,
                  color: Colors.red,
                ),
              ),
            ],
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