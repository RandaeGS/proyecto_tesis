import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'inventory/screen/analytics_screen.dart';
import 'inventory/screen/inventory_report_screen.dart';
import 'inventory/screen/inventory_snapshot_screen.dart';
import 'inventory/services/analytics_provider.dart';
import 'inventory/services/inventory_comparison_provider.dart';
import 'inventory/services/inventory_report_provider.dart';
import 'inventory/services/product_data_provider.dart';
import 'screens/auth_screens/config_screen.dart';
import 'screens/auth_screens/login/login_screen.dart';
import 'screens/auth_screens/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/user_management/user_list_screen.dart';
import 'screens/image_capture_screen.dart';
import 'services/auth_services/auth_provider.dart';
import 'services/config.dart';
import 'services/deteccion_services/analysis_provider.dart';
import 'services/images/images_provider.dart';
import 'services/user_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize configuration
  await AppConfig.initializeConfig();
  debugPrint('API URL configurada: ${AppConfig.getApiUrl()}');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => AnalysisProvider()),
        ChangeNotifierProvider(create: (_) => ServerImageProvider()),
        // Add the central product data provider
        ChangeNotifierProvider(create: (_) => ProductDataProvider()),
        ChangeNotifierProvider(create: (_) => InventoryComparisonProvider()),
        ChangeNotifierProvider(create: (_) => InventoryReportProvider()),
        ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mi Centro',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: Consumer<AuthProvider>(
        builder: (ctx, auth, _) {
          // Initialize auth if not yet done
          if (!auth.isInitialized) {
            Future.microtask(() => auth.initializeAuth());
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // Set auth token in other providers when authenticated
          if (auth.isAuthenticated && auth.token != null) {
            // Initialize providers with auth token
            Provider.of<InventoryComparisonProvider>(context, listen: false)
                .setAuthToken(auth.token!);
            Provider.of<InventoryReportProvider>(context, listen: false)
                .setAuthToken(auth.token!);
            Provider.of<AnalyticsProvider>(context, listen: false)
                .setAuthToken(auth.token!);
            // Initialize the product data provider with auth token
            Provider.of<ProductDataProvider>(context, listen: false)
                .setAuthToken(auth.token!);
          }

          // Show home screen if authenticated, login screen otherwise
          if (auth.isAuthenticated) {
            // Verificar si hay errores de autenticación
            if (auth.errorMessage.isNotEmpty &&
                (auth.errorMessage.contains("sesión") ||
                    auth.errorMessage.contains("401") ||
                    auth.errorMessage.contains("No autorizado"))) {
              // Si hay error de autenticación, mostrar login con mensaje
              return LoginScreen(redirectMessage: auth.errorMessage);
            }
            return const HomeScreen();
          }

          // If not authenticated, show the login screen
          return const LoginScreen();
        },
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/users': (context) => const UserListScreen(),
        '/images': (context) => const ImageCaptureScreen(),
        '/config': (context) => const ConfigScreen(),
        '/inventory': (context) => const InventorySnapshotScreen(),
        '/reports': (context) => const InventoryReportScreen(),
        '/analytics': (context) => const AnalyticsScreen(),
      },
      // Usar onGenerateRoute para permitir pasar parámetros al login
      onGenerateRoute: (settings) {
        if (settings.name == '/login') {
          // Verificar si hay argumentos para el mensaje de redirección
          final args = settings.arguments;
          if (args != null && args is String) {
            return MaterialPageRoute(
              builder: (context) => LoginScreen(redirectMessage: args),
            );
          }
          return MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          );
        }
        return null;
      },
    );
  }
}