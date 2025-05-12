// Archivo: lib/services/auth_services/session_manager.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';

/// Clase utilitaria para manejar verificaciones de sesión y redirecciones
class SessionManager {
  /// Verifica si hay un error de sesión y redirige al login si es necesario
  static Future<bool> checkSessionAndRedirect(
      BuildContext context,
      String errorMessage,
      ) async {
    // Verificar si hay un error de sesión en el mensaje de error
    if (isAuthError(errorMessage) || isConnectionError(errorMessage)) {
      debugPrint('SessionManager: Error detectado, redirigiendo al login');

      // Limpiar los datos de la sesión
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();

      // Mensaje adecuado para mostrar en el login
      final message = isConnectionError(errorMessage)
          ? 'No se pudo conectar al servidor. Verifique su conexión e intente nuevamente.'
          : 'Su sesión ha expirado. Iniciando sesión nuevamente...';

      if (context.mounted) {
        // Navegar a la pantalla de login
        Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
                (route) => false,
            arguments: message
        );

        return true; // Redirección realizada
      }
    }

    return false; // No se requirió redirección
  }

  /// Verifica si el token actual es válido, si no, redirige al login
  static Future<bool> validateSession(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Si no hay sesión, redirigir inmediatamente
    if (!authProvider.isAuthenticated || authProvider.token == null) {
      if (context.mounted) {
        await authProvider.logout();

        Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
                (route) => false,
            arguments: 'Sesión no válida. Iniciando sesión...'
        );

        return false; // Sesión no válida
      }
    }

    return true; // Sesión válida
  }

  /// Verifica si un mensaje de error contiene indicaciones de error de autenticación
  static bool isAuthError(String errorMessage) {
    return errorMessage.contains("sesión ha expirado") ||
        errorMessage.contains("No autorizado") ||
        errorMessage.contains("no encontrado") ||
        errorMessage.contains("401") ||
        errorMessage.contains("403") ||
        errorMessage.contains("token");
  }

  /// Verifica si un mensaje de error contiene indicaciones de problemas de conexión
  static bool isConnectionError(String errorMessage) {
    return errorMessage.contains("conexión") ||
        errorMessage.contains("Connection") ||
        errorMessage.contains("internet") ||
        errorMessage.contains("refused") ||
        errorMessage.contains("SocketException") ||
        errorMessage.contains("No se pudo conectar") ||
        errorMessage.contains("timeout") ||
        errorMessage.contains("timed out");
  }
}