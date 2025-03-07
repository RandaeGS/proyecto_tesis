import 'package:app_movil/screens/auth_screens/config_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_services/auth_provider.dart';
import 'screens/auth_screens/login_screen.dart';
import 'screens/auth_screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/user_management/user_list_screen.dart';
import 'screens/image_capture_screen.dart';
import 'services/config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar la configuración
  await AppConfig.initializeConfig();
  print('API URL configurada: ${AppConfig.getApiUrl()}');

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
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
      title: 'Mi Aplicación',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: Consumer<AuthProvider>(
        builder: (ctx, auth, _) {
          // Inicializar auth si aún no se ha hecho
          if (!auth.isInitialized) {
            Future.microtask(() => auth.initializeAuth());
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // Si el usuario está autenticado, mostrar la pantalla principal
          if (auth.isAuthenticated) {
            return const HomeScreen();
          }

          // Si no está autenticado, mostrar la pantalla de inicio de sesión
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
      },
    );
  }
}
