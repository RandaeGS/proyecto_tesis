import 'package:app_movil/screens/product_managment/product_screen_managment.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../inventory/screen/analytics_screen.dart';
import '../inventory/screen/inventory_report_screen.dart';
import '../inventory/screen/inventory_snapshot_screen.dart';
import '../services/auth_services/auth_provider.dart';
import '../services/deteccion_services/image_analisys_service.dart';
import '../services/user_provider.dart';
import 'image_capture_screen.dart';
import 'user_management/user_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Siempre intentar cargar la información del centro desde el backend al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated) {
        _loadCenterInfo();
      }
    });
  }

  // Cargar información del centro desde el backend
  Future<void> _loadCenterInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Primero intentamos cargar la información desde el provider de autenticación
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.refreshCenterInfo();

      // Si no tenemos un centro, intentamos obtenerlo desde el UserProvider
      if (authProvider.userCenter == null) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final centerId = await userProvider.getCurrentUserCenterId(context);

        if (centerId != null) {
          debugPrint('Centro obtenido desde UserProvider: $centerId');

          // Intentar obtener y actualizar los detalles del centro
          if (userProvider.currentCenter != null) {
            // Notificar al AuthProvider sobre el nuevo centro
            await authProvider.updateCenterInfo(userProvider.currentCenter!);

            debugPrint('Información del centro actualizada: ${userProvider.currentCenter!.name}');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar información del centro: $e'),
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final userCenter = authProvider.userCenter;
    final isAdmin = user?.isSuperuser ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Centro'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Botón para recargar información del centro
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar centro',
            onPressed: _isLoading ? null : _loadCenterInfo,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutConfirmation(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Información del usuario
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
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Colors.blue.shade100,
                              radius: 30,
                              child: Text(
                                user?.name.isNotEmpty == true
                                    ? user!.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user?.name ?? 'Usuario',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    user?.email ?? 'email@example.com',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isAdmin
                                        ? 'Administrador'
                                        : 'Usuario estándar',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isAdmin
                                          ? Colors.blue
                                          : Colors.grey.shade700,
                                      fontWeight: isAdmin
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Mostrar información del centro si está disponible
                        if (userCenter != null) ...[
                          const Divider(height: 24),
                          Text(
                            'Centro de acopio:',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.business,
                                size: 18,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  userCenter.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 18,
                                color: Colors.grey.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  userCenter.address,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Título de sección
                Text(
                  'Menú Principal',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),

                const SizedBox(height: 16),

                // Opciones disponibles para todos los usuarios
                _buildOptionCard(
                  title: 'Imágenes',
                  description: 'Capturar y visualizar imágenes',
                  icon: Icons.camera_alt,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ImageCaptureScreen(),
                      ),
                    );
                  },
                ),

                _buildOptionCard(
                  title: 'Gestión de Productos',
                  description: 'Visualizar y gestionar productos detectados',
                  icon: Icons.inventory,
                  onTap: () {
                    // Verificar que el usuario tenga un centro asignado
                    if (authProvider.centerId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No tiene un centro asignado'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Obtener el ID del centro del usuario
                    final int currentCenterId = authProvider.centerId!;

                    // Navegar a la pantalla de gestión
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductManagementScreen(
                          centerId: currentCenterId,
                        ),
                      ),
                    );
                  },
                ),

                // Opción de Instantáneas de Inventario
                _buildOptionCard(
                  title: 'Instantáneas de Inventario',
                  description: 'Guardar y comparar estados del inventario a lo largo del tiempo',
                  icon: Icons.compare_arrows,
                  onTap: () {
                    // Verificar que el usuario tenga un centro asignado
                    if (authProvider.centerId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No tiene un centro asignado'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Navegar a la pantalla de instantáneas de inventario
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const InventorySnapshotScreen(),
                      ),
                    );
                  },
                ),

                // NUEVA OPCIÓN: Informes de Reposición
                _buildOptionCard(
                  title: 'Informes de Reposición',
                  description: 'Generar informes sobre qué productos deben reponerse',
                  icon: Icons.assignment,
                  onTap: () {
                    // Verificar que el usuario tenga un centro asignado
                    if (authProvider.centerId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No tiene un centro asignado'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Navegar a la pantalla de informes
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const InventoryReportScreen(),
                      ),
                    );
                  },
                ),

                _buildOptionCard(
                  title: 'Análisis de Consumo',
                  description: 'Generar reportes analíticos sobre el consumo de productos por categoría y período',
                  icon: Icons.analytics,
                  onTap: () {
                    // Verificar que el usuario tenga un centro asignado
                    if (authProvider.centerId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No tiene un centro asignado'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Navegar a la pantalla de análisis
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AnalyticsScreen(),
                      ),
                    );
                  },
                ),

                // Opciones adicionales para administradores
                if (isAdmin) ...[
                  const SizedBox(height: 8),
                  ..._buildAdminOptions(context),
                ],

                // Agregar espacio adicional al final para evitar problemas con el último elemento
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAdminOptions(BuildContext context) {
    return [
      _buildOptionCard(
        title: 'Gestión de Usuarios',
        description: 'Crear, ver, actualizar y eliminar usuarios del sistema',
        icon: Icons.people,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UserListScreen(),
            ),
          );
        },
      ),

      // Aquí se pueden agregar más opciones en el futuro
    ];
  }

  Widget _buildOptionCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.blue,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text('¿Está seguro que desea cerrar sesión?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Cerrar sesión'),
              onPressed: () async {
                Navigator.of(context).pop();
                await Provider.of<AuthProvider>(context, listen: false)
                    .logout();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/');
                }
              },
            ),
          ],
        );
      },
    );
  }
}