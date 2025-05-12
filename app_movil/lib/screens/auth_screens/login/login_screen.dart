import 'package:app_movil/screens/auth_screens/login/widget/error_message_container.dart';
import 'package:app_movil/screens/auth_screens/login/widget/loading_screen.dart';
import 'package:app_movil/screens/auth_screens/login/widget/login_form.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/auth_services/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  final String? redirectMessage;

  const LoginScreen({
    super.key,
    this.redirectMessage,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? _redirectMessage;

  @override
  void initState() {
    super.initState();

    _redirectMessage = widget.redirectMessage;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Si hay un mensaje de redirección, mostrarlo
      if (_redirectMessage != null && _redirectMessage!.isNotEmpty) {
        _showRedirectMessage();
      }

      context.read<AuthProvider>().initializeAuth();
    });
  }

  void _showRedirectMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_redirectMessage!),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (!authProvider.isInitialized) {
      return const LoadingScreen();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo de la aplicación
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Image.asset(
                    'assets/images/logo.png',
                    height: 100,
                    width: 100,
                  ),
                ),

                const SizedBox(height: 16),
                const Text(
                  'Bienvenido',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Formulario de inicio de sesión
                LoginForm(
                  isLoading: authProvider.isLoading,
                  onLogin: (email, password) async {
                    try {
                      await authProvider.login(email, password);

                      // Verificar explícitamente el estado después del login
                      if (authProvider.isAuthenticated && mounted) {
                        // Navegar al home screen
                        Navigator.of(context).pushReplacementNamed('/home');
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),

                // Enlace para registrarse
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  child: const Text(
                    '¿No tienes cuenta? Regístrate aquí',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 16,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Mostrar mensaje de error si existe
                if (authProvider.errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ErrorMessageContainer(
                    message: authProvider.errorMessage,
                    type: ErrorType.error,
                  ),
                ],

                // Mostrar mensaje de redirección si existe
                if (_redirectMessage != null && _redirectMessage!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ErrorMessageContainer(
                    message: _redirectMessage!,
                    type: ErrorType.warning,
                    icon: Icons.info_outline,
                  ),
                ],

                // Enlace a la configuración
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/config');
                  },
                  icon: const Icon(Icons.settings, size: 16),
                  label: const Text('Configurar servidor'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}