import 'package:flutter/material.dart';

import '../entities/user.dart';
import 'core/api_client.dart';
import 'core/api_constants.dart';

/// Servicio para manejar operaciones relacionadas con usuarios
class UserService {
  final ApiClient _apiClient = ApiClient();

  /// Obtiene todos los usuarios
  Future<List<User>> getAllUsers() async {
    try {
      final data = await _apiClient.get(
        ApiConstants.users,
        entityName: 'Usuarios',
      );

      if (data is List) {
        return data.map((json) => User.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      debugPrint('Error en getAllUsers: $e');

      // Si falla, intentar con la búsqueda
      try {
        return await searchUsers('');
      } catch (_) {
        rethrow;
      }
    }
  }

  /// Obtiene un usuario por su ID (email)
  Future<User> getUserById(String userId) async {
    try {
      final endpoint = '${ApiConstants.users}$userId/';
      final data = await _apiClient.get(
        endpoint,
        entityName: 'Usuario',
      );

      return User.fromJson(data);
    } catch (e) {
      debugPrint('Error en getUserById: $e');
      rethrow;
    }
  }

  /// Crea un nuevo usuario
  Future<User> createUser({
    required String email,
    required String password,
    required String name,
    required bool isSuperuser,
    required bool isStaff,
    int? centerId,
  }) async {
    try {
      final Map<String, dynamic> requestBody = {
        'email': email,
        'password': password,
        'name': name,
        'is_superuser': isSuperuser,
        'is_staff': isStaff,
      };

      // Añadir centerId si está disponible
      if (centerId != null) {
        requestBody['center_id'] = centerId;
      }

      final data = await _apiClient.post(
        ApiConstants.createUser,
        requestBody,
        entityName: 'Usuario',
      );

      // Manejar diferentes estructuras de respuesta
      if (data is Map<String, dynamic> && data.containsKey('data')) {
        return User.fromJson(data['data']);
      } else {
        return User.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error en createUser: $e');
      rethrow;
    }
  }

  /// Actualiza un usuario existente
  Future<User> updateUser({
    required String userId,
    required String name,
    required bool isSuperuser,
    required bool isStaff,
  }) async {
    try {
      final endpoint = '${ApiConstants.users}$userId/';
      final data = await _apiClient.put(
        endpoint,
        {
          'name': name,
          'is_superuser': isSuperuser,
          'is_staff': isStaff,
        },
        entityName: 'Usuario',
      );

      // Manejar diferentes estructuras de respuesta
      if (data is Map<String, dynamic> && data.containsKey('data')) {
        return User.fromJson(data['data']);
      } else {
        return User.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error en updateUser: $e');
      rethrow;
    }
  }

  /// Actualiza la contraseña de un usuario
  Future<void> resetPassword({
    required String userId,
    required String newPassword,
  }) async {
    try {
      final endpoint = '${ApiConstants.users}$userId/';
      await _apiClient.patch(
        endpoint,
        {
          'password': newPassword,
        },
        entityName: 'Usuario',
      );
    } catch (e) {
      debugPrint('Error en resetPassword: $e');
      rethrow;
    }
  }

  /// Elimina un usuario
  Future<void> deleteUser(String userId) async {
    try {
      final endpoint = '${ApiConstants.users}$userId/';
      await _apiClient.delete(
        endpoint,
        entityName: 'Usuario',
      );
    } catch (e) {
      debugPrint('Error en deleteUser: $e');
      rethrow;
    }
  }

  /// Busca usuarios por una consulta
  Future<List<User>> searchUsers(String query) async {
    try {
      final endpoint = '${ApiConstants.users}search/?q=$query';
      final data = await _apiClient.get(
        endpoint,
        entityName: 'Usuarios',
      );

      if (data is List) {
        return data.map((json) => User.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      debugPrint('Error en searchUsers: $e');
      rethrow;
    }
  }

  /// Asigna un usuario a un centro
  Future<User> assignUserToCenter({
    required String userId,
    required int centerId,
  }) async {
    try {
      final endpoint = '${ApiConstants.users}$userId/assign-center/';
      final data = await _apiClient.put(
        endpoint,
        {
          'center_id': centerId.toString(),
        },
        entityName: 'Usuario',
      );

      // Manejar diferentes estructuras de respuesta
      if (data is Map<String, dynamic> && data.containsKey('data')) {
        return User.fromJson(data['data']);
      } else {
        return User.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error en assignUserToCenter: $e');
      rethrow;
    }
  }

  /// Elimina un usuario de un centro
  Future<User> removeUserFromCenter({
    required String userId,
    required int centerId,
  }) async {
    try {
      final endpoint = '${ApiConstants.users}$userId/remove-center/';
      final data = await _apiClient.put(
        endpoint,
        {
          'center_id': centerId,
        },
        entityName: 'Usuario',
      );

      // Manejar diferentes estructuras de respuesta
      if (data is Map<String, dynamic> && data.containsKey('data')) {
        return User.fromJson(data['data']);
      } else {
        return User.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error en removeUserFromCenter: $e');
      rethrow;
    }
  }



  /// Obtiene un usuario por su email con información completa (incluye centros)
  Future<Map<String, dynamic>> getUserByEmail(String email) async {
    try {
      final endpoint = '${ApiConstants.userByEmail}$email/';
      debugPrint('Consultando información completa del usuario: $endpoint');

      final data = await _apiClient.get(
        endpoint,
        entityName: 'Usuario',
      );

      if (data is Map<String, dynamic>) {
        debugPrint('Información del usuario recibida: ${data.keys}');
        if (data.containsKey('centers')) {
          debugPrint('Centros encontrados: ${data['centers'].length}');
        }
        return data;
      }

      throw 'Formato de respuesta inesperado';
    } catch (e) {
      debugPrint('Error en getUserByEmail: $e');
      rethrow;
    }
  }
}