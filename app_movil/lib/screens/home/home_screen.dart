import 'package:app_movil/screens/home/widget/admin_tab.dart';
import 'package:app_movil/screens/home/widget/home_tab.dart';
import 'package:app_movil/screens/home/widget/inventory_tab.dart';
import 'package:app_movil/screens/home/widget/profile_tab.dart';
import 'package:app_movil/screens/home/widget/reports_tab.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../inventory/services/analytics_provider.dart';
import '../../inventory/services/inventory_comparison_provider.dart';
import '../../inventory/services/inventory_report_provider.dart';
import '../../inventory/services/product_data_provider.dart';
import '../../services/auth_services/auth_provider.dart';
import '../../services/user_provider.dart';
import '../../utils/dialogs.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;
  String _errorMessage = '';
  int _selectedIndex = 0; // Para la navegación bottom bar

  // Colores para el tema
  final Color _primaryColor = const Color(0xFF2c6bed);
  final Color _secondaryColor = const Color(0xFF60a3f5);
  final Color _accentColor = const Color(0xFFffa726);
  final Color _backgroundColor = const Color(0xFFF5F7FA);

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
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 50,
              height: 50,
            ),
            const SizedBox(width: 6),
            const Text('Centro de Acopio'),
          ],
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar datos',
            onPressed: _isLoading ? null : _loadCenterInfo,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => DialogUtils.showLogoutConfirmation(context),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _primaryColor),
            const SizedBox(height: 16),
            const Text(
              'Cargando información...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      )
          : _buildBody(context, user, userCenter, isAdmin),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildBody(BuildContext context, dynamic user, dynamic userCenter, bool isAdmin) {
    // Estructura principal del cuerpo de la app
    return IndexedStack(
      index: _selectedIndex,
      children: [
        HomeTab(
          user: user,
          userCenter: userCenter,
          isAdmin: isAdmin,
          errorMessage: _errorMessage,
          onRefresh: _loadCenterInfo,
          primaryColor: _primaryColor,
        ), // Tab 0: Inicio
        InventoryTab(), // Tab 1: Inventario
        ReportsTab(),  // Tab 2: Reportes
        isAdmin ? AdminTab() : ProfileTab(),  // Tab 3: Admin o Perfil
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.user?.isSuperuser ?? false;

    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: _primaryColor,
      unselectedItemColor: Colors.grey,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 12),
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home_rounded),
          label: 'Inicio',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.inventory_2_rounded),
          label: 'Inventario',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.assignment_rounded),
          label: 'Reportes',
        ),
        BottomNavigationBarItem(
          icon: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person),
          label: isAdmin ? 'Admin' : 'Perfil',
        ),
      ],
    );
  }
}