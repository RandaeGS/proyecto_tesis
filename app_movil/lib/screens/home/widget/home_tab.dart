import 'package:app_movil/screens/home/widget/quick_acces_button.dart';
import 'package:app_movil/screens/home/widget/welcome_banner.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../inventory/screen/analytics_screen.dart';
import '../../../inventory/screen/inventory_report_screen.dart';
import '../../../inventory/screen/manual_inventory/manual_inventory_screen.dart';
import '../../../services/auth_services/auth_provider.dart';
import '../../../utils/ui_utils.dart';
import '../../image_capture_screen.dart';
import '../../product_managment/product_screen_managment.dart';
import '../../user_management/user_list_screen.dart';
import 'error_message_widget.dart';
import 'feature_card.dart';

class HomeTab extends StatelessWidget {
  final dynamic user;
  final dynamic userCenter;
  final bool isAdmin;
  final String errorMessage;
  final VoidCallback onRefresh;
  final Color primaryColor;

  const HomeTab({
    Key? key,
    required this.user,
    required this.userCenter,
    required this.isAdmin,
    required this.errorMessage,
    required this.onRefresh,
    required this.primaryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        onRefresh();
      },
      color: primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner de bienvenida
              WelcomeBanner(user: user, userCenter: userCenter),

              // Mensaje de error si existe
              if (errorMessage.isNotEmpty)
                ErrorMessageWidget(
                  errorMessage: errorMessage,
                  onRetry: onRefresh,
                  onLoginRedirect: () {
                    // Implementar redireccionamiento al login
                    Navigator.of(context).pushReplacementNamed('/login');
                  },
                ),

              const SizedBox(height: 24),

              // Tarjetas de acceso rápido
              _buildQuickAccessSection(context),

              const SizedBox(height: 24),

              // Acciones principales
              _buildMainActionsSection(context, isAdmin),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccessSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Acceso Rápido',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            QuickAccessButton(
              icon: Icons.camera_alt_rounded,
              label: 'Capturar',
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
            QuickAccessButton(
              icon: Icons.inventory_2_rounded,
              label: 'Productos',
              color: Colors.green,
              onTap: () {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                if (authProvider.centerId == null) {
                  UIUtils.showNoCenterError(context);
                  return;
                }
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
            QuickAccessButton(
              icon: Icons.assignment_rounded,
              label: 'Informes',
              color: Colors.orange,
              onTap: () {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                if (authProvider.centerId == null) {
                  UIUtils.showNoCenterError(context);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const InventoryReportScreen(),
                  ),
                );
              },
            ),
            QuickAccessButton(
              icon: Icons.analytics_rounded,
              label: 'Análisis',
              color: Colors.blue,
              onTap: () {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                if (authProvider.centerId == null) {
                  UIUtils.showNoCenterError(context);
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AnalyticsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainActionsSection(BuildContext context, bool isAdmin) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Gestión del Centro',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        FeatureCard(
          title: 'Gestión de Productos',
          description: 'Visualizar y gestionar todos los productos detectados',
          icon: Icons.inventory_2_rounded,
          color: Colors.green,
          onTap: () {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            if (authProvider.centerId == null) {
              UIUtils.showNoCenterError(context);
              return;
            }
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

        FeatureCard(
          title: 'Gestión Manual de Inventario',
          description: 'Actualice inventario sin necesidad de imágenes',
          icon: Icons.edit_note_rounded,
          color: Colors.indigo,
          onTap: () {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            if (authProvider.centerId == null) {
              UIUtils.showNoCenterError(context);
              return;
            }
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

        FeatureCard(
          title: 'Informes de Reposición',
          description: 'Genere informes sobre productos que deben reponerse',
          icon: Icons.assignment_rounded,
          color: Colors.orange,
          onTap: () {
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
            if (authProvider.centerId == null) {
              UIUtils.showNoCenterError(context);
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const InventoryReportScreen(),
              ),
            );
          },
        ),

        if (isAdmin)
          FeatureCard(
            title: 'Gestión de Usuarios',
            description: 'Administre los usuarios del sistema',
            icon: Icons.people_rounded,
            color: Colors.purple,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserListScreen(),
                ),
              );
            },
          ),
      ],
    );
  }
}