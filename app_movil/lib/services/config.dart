// Archivo: lib/services/config.dart
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  // Valores por defecto - Actualizado con tu IP real
  static String _apiIp = '10.0.0.6';
  static String _apiPort = '8080';
  static bool _isConfigLoaded = false;
                                                                                                                                                        
  // URL para emuladores Android (10.0.2.2 es localhost desde el emulador)
  static const String emulatorBaseUrl = 'http://localhost:8080';

  // Determinar qué URL usar
  static String getApiUrl() {
    if (!_isConfigLoaded) {
      // Si aún no se ha cargado la configuración, intentamos cargarla
      // (esto es asíncrono, así que por ahora regresamos el valor por defecto)
      _loadConfig();
    }

    return 'http://$_apiIp:$_apiPort';
  }

  // Método para actualizar la URL de la API
  static void updateApiUrl(String ip, String port) {
    _apiIp = ip;
    _apiPort = port;
    _isConfigLoaded = true;
  }

  // Método para cargar la configuración de SharedPreferences
  static Future<void> _loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIp = prefs.getString('api_ip');
      final savedPort = prefs.getString('api_port');

      if (savedIp != null && savedPort != null) {
        _apiIp = savedIp;
        _apiPort = savedPort;
      }

      _isConfigLoaded = true;
    } catch (e) {
      print('Error cargando configuración: $e');
    }
  }

  // Método para inicializar la configuración al inicio de la app
  static Future<void> initializeConfig() async {
    await _loadConfig();
    print('API URL Configurada: ${getApiUrl()}');
  }
}