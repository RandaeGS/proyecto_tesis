import 'package:app_movil/screens/product_managment/product_screen_managment.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../inventory/screen/analytics_screen.dart';
import '../inventory/screen/inventory_report_screen.dart';
import '../inventory/screen/inventory_snapshot_screen.dart';
import '../inventory/screen/manual_inventory_screen.dart';
import '../inventory/services/analytics_provider.dart';
import '../inventory/services/inventory_comparison_provider.dart';
import '../inventory/services/inventory_report_provider.dart';
import '../inventory/services/product_data_provider.dart';
import '../services/auth_services/auth_provider.dart';
import '../services/auth_services/session_manager.dart';
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
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();

    // Siempre intentar cargar la información del centro desde el backend al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated) {
        _loadCenterInfo();
      } else {
        // Si no está autenticado, redirigir al login
        _redirectToLogin('No hay sesión activa');
      }
    });
  }

  // Método para redirigir al login
  Future<void> _redirectToLogin(String reason) async {
    debugPrint('Redirigiendo al login: $reason');

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();

    if (mounted) {
      // Navegar al login inmediatamente y resetear todas las rutas
      Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
              (route) => false,
          arguments: reason
      );
    }
  }

  Future<void> _loadCenterInfo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Primero intentamos cargar la información desde el provider de autenticación
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      try {
        await authProvider.refreshCenterInfo();
      } catch (e) {
        debugPrint('Error al actualizar información del centro: $e');

        String errorMsg = e.toString();

        // Verificar si es un error de conexión
        if (errorMsg.contains('conexión') ||
            errorMsg.contains('Connection') ||
            errorMsg.contains('internet') ||
            errorMsg.contains('refused') ||
            errorMsg.contains('SocketException')) {

          if (mounted) {
            // Redirección inmediata en caso de error de conexión
            await _redirectToLogin('No se pudo conectar al servidor. Verifique su conexión e intente nuevamente.');
            return; // Importante: salir del método inmediatamente
          }
        }

        // Si llegamos aquí, no es error de conexión - continuar con el flujo normal
        // pero guardar el mensaje de error para mostrarlo
        setState(() {
          _errorMessage = errorMsg;
        });
      }

      // Si no tenemos un centro, intentamos obtenerlo desde el UserProvider
      if (authProvider.userCenter == null) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);

        try {
          final centerId = await userProvider.getCurrentUserCenterId(context);

          // Verificar si hay error en userProvider
          if (userProvider.errorMessage.isNotEmpty) {
            // Verificar específicamente si es un error de conexión
            if (userProvider.errorMessage.contains('conexión') ||
                userProvider.errorMessage.contains('Connection') ||
                userProvider.errorMessage.contains('internet') ||
                userProvider.errorMessage.contains('refused') ||
                userProvider.errorMessage.contains('SocketException')) {

              if (mounted) {
                await _redirectToLogin('No se pudo conectar al servidor. Verifique su conexión e intente nuevamente.');
                return;
              }
            }

            // Si llegamos aquí, no es error de conexión,
            // pero hay otro tipo de error - guardarlo para mostrarlo
            setState(() {
              _errorMessage = userProvider.errorMessage;
            });
          }

          if (centerId != null) {
            debugPrint('Centro obtenido desde UserProvider: $centerId');

            // Intentar obtener y actualizar los detalles del centro
            if (userProvider.currentCenter != null) {
              // Notificar al AuthProvider sobre el nuevo centro
              await authProvider.updateCenterInfo(userProvider.currentCenter!);
              debugPrint('Información del centro actualizada: ${userProvider.currentCenter!.name}');
            }
          } else {
            // Si no se pudo obtener el centerId
            setState(() {
              _errorMessage = 'No se pudo obtener información del centro';
            });
          }
        } catch (e) {
          debugPrint('Error al obtener centerId: $e');

          // Verificar si es un error de conexión
          if (e.toString().contains('conexión') ||
              e.toString().contains('Connection') ||
              e.toString().contains('internet') ||
              e.toString().contains('refused') ||
              e.toString().contains('SocketException')) {

            if (mounted) {
              await _redirectToLogin('No se pudo conectar al servidor. Verifique su conexión e intente nuevamente.');
              return;
            }
          }

          // Si no es error de conexión, guardar el mensaje para mostrarlo
          setState(() {
            _errorMessage = e.toString();
          });
        }
      }

      // Asegurarnos de tener token configurado en todos los providers
      if (authProvider.isAuthenticated && authProvider.token != null) {
        // Initialize providers with auth token
        final token = authProvider.token!;
        Provider.of<InventoryComparisonProvider>(context, listen: false)
            .setAuthToken(token);
        Provider.of<InventoryReportProvider>(context, listen: false)
            .setAuthToken(token);
        Provider.of<AnalyticsProvider>(context, listen: false)
            .setAuthToken(token);
        // Initialize the product data provider with auth token
        Provider.of<ProductDataProvider>(context, listen: false)
            .setAuthToken(token);
      }

      // NUEVO: Si tenemos ID de centro, inicializar el product data provider
      if (authProvider.centerId != null) {
        try {
          debugPrint('Iniciando carga de datos del centro ${authProvider.centerId}');

          // Initialize the product data provider first
          final productDataProvider = Provider.of<ProductDataProvider>(context, listen: false);
          // Ensure it has auth token
          if (authProvider.token != null) {
            productDataProvider.setAuthToken(authProvider.token!);
          }

          // Cargar datos de productos
          try {
            await productDataProvider.loadProductData(authProvider.centerId!);
          } catch (e) {
            debugPrint('Error al cargar datos de productos: $e');

            // Verificar si es un error de conexión
            if (e.toString().contains('conexión') ||
                e.toString().contains('Connection') ||
                e.toString().contains('internet') ||
                e.toString().contains('refused') ||
                e.toString().contains('SocketException')) {

              if (mounted) {
                await _redirectToLogin('No se pudo conectar al servidor. Verifique su conexión e intente nuevamente.');
                return;
              }
            }

            // Si no es error de conexión, solo registrar el error
            // pero continuar con la carga de la pantalla principal
            setState(() {
              _errorMessage = 'Error al cargar datos de productos: $e';
            });
          }

          // After product data is loaded, then load other data
          final inventoryProvider = Provider.of<InventoryComparisonProvider>(context, listen: false);
          inventoryProvider.setProductDataProvider(productDataProvider);

          try {
            await inventoryProvider.loadInventorySnapshots(authProvider.centerId!);
          } catch (e) {
            debugPrint('Error al cargar instantáneas de inventario: $e');
            // Solo registrar el error, continuaremos cargando el resto de datos
            // No redirigir al login por este error
          }

          // Finally load reports
          final reportProvider = Provider.of<InventoryReportProvider>(context, listen: false);

          try {
            await reportProvider.loadReports(authProvider.centerId!);
          } catch (e) {
            debugPrint('Error al cargar informes: $e');
            // Solo registrar el error, continuaremos mostrando la pantalla
            // No redirigir al login por este error
          }

          debugPrint('Datos del centro cargados correctamente');
        } catch (e) {
          debugPrint('Error loading provider data: $e');
          setState(() {
            _errorMessage = e.toString();
          });
        }
      } else {
        // Si no hay centerId, mostrar un error pero no redirigir automáticamente
        setState(() {
          _errorMessage = 'No se pudo determinar el ID del centro';
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error al cargar información del centro: $e');

        // Verificar si es un error de conexión
        if (e.toString().contains('conexión') ||
            e.toString().contains('Connection') ||
            e.toString().contains('internet') ||
            e.toString().contains('refused') ||
            e.toString().contains('SocketException')) {

          await _redirectToLogin('No se pudo conectar al servidor. Verifique su conexión e intente nuevamente.');
          return;
        }

        // Si no es error de conexión, solo mostrar el error
        setState(() {
          _errorMessage = 'Error al cargar información: $e';
        });
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
                // Mostrar mensaje de error si existe
                if (_errorMessage.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Error',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _loadCenterInfo,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade700,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Reintentar'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  _redirectToLogin('Redirigiendo al login');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Ir a Login'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

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

                _buildOptionCard(
                  title: 'Gestión Manual de Inventario',
                  description: 'Actualizar y gestionar el inventario manualmente sin necesidad de imágenes',
                  icon: Icons.edit_note,
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

                    // Navegar a la pantalla de gestión manual de inventario
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
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
            ),
          ],
        );
      },
    );
  }
}