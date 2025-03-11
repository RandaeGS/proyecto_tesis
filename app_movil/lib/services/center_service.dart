import 'package:flutter/material.dart';

import '../entities/center.dart' as app_center;
import '../entities/user.dart';
import 'core/api_client.dart';
import 'core/api_constants.dart';

/// Servicio para manejar operaciones relacionadas con centros
class CenterService {
  final ApiClient _apiClient = ApiClient();

  /// Obtiene todos los centros disponibles
  Future<List<app_center.Center>> getAllCenters() async {
    try {
      dynamic data;

      // Intentar primero con la ruta all-centers
      try {
        data = await _apiClient.get(
          ApiConstants.allCenters,
          entityName: 'Centros',
        );
      } catch (e) {
        debugPrint('Error con endpoint all-centers, intentando con la ruta alternativa: $e');
        // Si falla, intentar con la ruta centers
        data = await _apiClient.get(
          ApiConstants.centers,
          entityName: 'Centros',
        );
      }

      // Manejar diferentes estructuras de respuesta
      if (data is List) {
        return data.map((json) => app_center.Center.fromJson(json)).toList();
      } else if (data is Map && data.containsKey('results') && data['results'] is List) {
        return (data['results'] as List).map((json) => app_center.Center.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      debugPrint('Error en getAllCenters: $e');
      rethrow;
    }
  }

  /// Obtiene un centro por su ID
  Future<app_center.Center> getCenterById(int centerId) async {
    try {
      final endpoint = '${ApiConstants.centers}$centerId/';
      final data = await _apiClient.get(
        endpoint,
        entityName: 'Centro',
      );

      return app_center.Center.fromJson(data);
    } catch (e) {
      debugPrint('Error en getCenterById: $e');
      rethrow;
    }
  }

  /// Obtiene todos los usuarios de un centro
  Future<List<User>> getCenterUsers(int centerId) async {
    try {
      final endpoint = '${ApiConstants.centerUsers}$centerId/users/';
      final data = await _apiClient.get(
        endpoint,
        entityName: 'Centro',
      );

      if (data is List) {
        return data.map((json) => User.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      debugPrint('Error en getCenterUsers: $e');
      rethrow;
    }
  }

  /// Crea un nuevo centro
  Future<app_center.Center> createCenter({
    required String name,
    required String address,
  }) async {
    try {
      final data = await _apiClient.post(
        ApiConstants.centers,
        {
          'name': name,
          'address': address,
        },
        entityName: 'Centro',
      );

      return app_center.Center.fromJson(data);
    } catch (e) {
      debugPrint('Error en createCenter: $e');
      rethrow;
    }
  }

  /// Actualiza un centro existente
  Future<app_center.Center> updateCenter({
    required int centerId,
    required String name,
    required String address,
  }) async {
    try {
      final endpoint = '${ApiConstants.centers}$centerId/';
      final data = await _apiClient.put(
        endpoint,
        {
          'name': name,
          'address': address,
        },
        entityName: 'Centro',
      );

      return app_center.Center.fromJson(data);
    } catch (e) {
      debugPrint('Error en updateCenter: $e');
      rethrow;
    }
  }

  /// Elimina un centro
  Future<void> deleteCenter(int centerId) async {
    try {
      final endpoint = '${ApiConstants.centers}$centerId/';
      await _apiClient.delete(
        endpoint,
        entityName: 'Centro',
      );
    } catch (e) {
      debugPrint('Error en deleteCenter: $e');
      rethrow;
    }
  }
}