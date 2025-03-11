import 'package:flutter/material.dart';

import '../../entities/center.dart' as app_center;
import '../../entities/user.dart';
import '../core/api_client.dart';
import '../core/api_constants.dart';
import '../core/storage_services.dart';

/// Servicio para manejar la autenticación y operaciones relacionadas con usuarios
class AuthService {
  final ApiClient _apiClient = ApiClient();
  final StorageService _storageService = StorageService();

  /// Inicia sesión con email y contraseña
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      debugPrint('Iniciando sesión: $email');

      final data = await _apiClient.post(
        ApiConstants.login,
        {
          'email': email,
          'password': password,
        },
        entityName: 'Login',
      );

      // Guardar el token
      final String token = data['token'] as String;
      await _apiClient.saveToken(token);

      // Guardar la información del usuario
      final userData = data['user'] as Map<String, dynamic>;
      final user = User.fromJson(userData);
      await _storageService.saveUser(user);

      // Guardar información del centro si está disponible
      if (data.containsKey('center')) {
        final centerData = data['center'] as Map<String, dynamic>;
        final center = app_center.Center.fromJson(centerData);
        await _storageService.saveCenter(center);
      }

      return data;
    } catch (e) {
      debugPrint('Error de login: $e');
      rethrow;
    }
  }

  /// Registra un nuevo usuario y centro
  Future<Map<String, dynamic>> register({
    required String centerName,
    required String centerAddress,
    required String email,
    required String password,
    required String userName,
    required bool isSuperuser,
    required bool isStaff,
  }) async {
    try {
      final requestBody = {
        'center': {
          'name': centerName,
          'address': centerAddress,
        },
        'user': {
          'email': email,
          'password': password,
          'name': userName,
          'is_superuser': isSuperuser,
          'is_staff': isStaff,
        }
      };

      final data = await _apiClient.post(
        ApiConstants.register,
        requestBody,
        entityName: 'Registro',
      );

      // Guardar el token
      final String token = data['token'] as String;
      await _apiClient.saveToken(token);

      // Guardar la información del usuario
      final userData = data['user'] as Map<String, dynamic>;
      final user = User.fromJson(userData);
      await _storageService.saveUser(user);

      // Guardar información del centro
      if (data.containsKey('center')) {
        final centerData = data['center'] as Map<String, dynamic>;
        final center = app_center.Center.fromJson(centerData);
        await _storageService.saveCenter(center);
      }

      return data;
    } catch (e) {
      debugPrint('Error en registro: $e');
      rethrow;
    }
  }

  /// Obtiene los centros del usuario actual
  Future<List<app_center.Center>> getUserCenters() async {
    try {
      final data = await _apiClient.get(
        ApiConstants.currentUser,
        entityName: 'Usuario',
      );

      List<app_center.Center> centersList = [];

      // Manejar diferentes estructuras de respuesta
      if (data is Map && data.containsKey('centers') && data['centers'] is List) {
        final centersList = (data['centers'] as List)
            .map((centerData) => app_center.Center.fromJson(centerData))
            .toList();
        return centersList;
      } else {
        // Si el endpoint no devuelve los centros directamente,
        // podemos intentar obtenerlos a través de otro endpoint
        return await _getUserCentersById(data['email'] as String);
      }
    } catch (e) {
      debugPrint('Error al obtener centros del usuario: $e');
      rethrow;
    }
  }

  /// Obtiene los centros por ID de usuario
  Future<List<app_center.Center>> _getUserCentersById(String userId) async {
    try {
      final endpoint = '${ApiConstants.centerUsers}$userId/centers/';
      final data = await _apiClient.get(
        endpoint,
        entityName: 'Centros',
      );

      // Manejar diferentes estructuras de respuesta
      if (data is List) {
        return (data as List)
            .map((centerData) => app_center.Center.fromJson(centerData))
            .toList();
      } else if (data is Map && data.containsKey('centers') && data['centers'] is List) {
        return (data['centers'] as List)
            .map((centerData) => app_center.Center.fromJson(centerData))
            .toList();
      }

      return [];
    } catch (e) {
      debugPrint('Error al obtener centros por ID de usuario: $e');

      // Si falló, intentar con todos los centros
      try {
        return await _getAllCenters();
      } catch (_) {
        rethrow;
      }
    }
  }

  /// Obtiene todos los centros disponibles (fallback)
  Future<List<app_center.Center>> _getAllCenters() async {
    try {
      final data = await _apiClient.get(
        ApiConstants.centers,
        entityName: 'Centros',
      );

      if (data is List) {
        return (data as List)
            .map((centerData) => app_center.Center.fromJson(centerData))
            .toList();
      } else if (data is Map && data.containsKey('results') && data['results'] is List) {
        return (data['results'] as List)
            .map((centerData) => app_center.Center.fromJson(centerData))
            .toList();
      }

      return [];
    } catch (e) {
      debugPrint('Error al obtener todos los centros: $e');
      rethrow;
    }
  }

  /// Obtiene la información completa de un usuario por email
  Future<Map<String, dynamic>> getUserByEmail(String email) async {
    try {
      final endpoint = '${ApiConstants.userByEmail}$email/';
      return await _apiClient.get(
        endpoint,
        entityName: 'Usuario',
      );
    } catch (e) {
      debugPrint('Error al obtener usuario por email: $e');
      rethrow;
    }
  }

  /// Verifica si existe un token guardado
  Future<bool> isAuthenticated() async {
    final token = await _apiClient.getToken();
    return token != null && token.isNotEmpty;
  }

  /// Obtiene el token actual
  Future<String?> getToken() async {
    return await _apiClient.getToken();
  }

  /// Cierra la sesión actual
  Future<void> logout() async {
    await _apiClient.clearToken();
    await _storageService.clearUserData();
  }

  /// Obtiene el usuario guardado localmente
  Future<User?> getSavedUser() async {
    return await _storageService.getUser();
  }

  /// Obtiene el centro guardado localmente
  Future<app_center.Center?> getSavedCenter() async {
    return await _storageService.getCenter();
  }
}