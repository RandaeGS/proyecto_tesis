import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/api_client.dart';
import '../core/api_constants.dart';

/// Clase para representar datos de una imagen del servidor
class ServerImage {
  final String id;
  final String file;
  final String takenAt;
  final String takenBy;
  final int centerId;
  final bool processed;
  final Map<String, dynamic> metadata;

  ServerImage({
    required this.id,
    required this.file,
    required this.takenAt,
    required this.centerId,
    this.takenBy = '',
    this.processed = false,
    this.metadata = const {},
  });

  factory ServerImage.fromJson(Map<String, dynamic> json) {
    return ServerImage(
      id: json['id'].toString(),
      file: json['file'] ?? '',
      takenAt: json['taken_at'] ?? '',
      takenBy: json['taken_by']?.toString() ?? '',
      centerId: json['center'] is int ? json['center'] : int.tryParse(json['center'].toString()) ?? 0,
      processed: json['processed'] ?? false,
      metadata: json['metadata'] is Map ? Map<String, dynamic>.from(json['metadata']) : {},
    );
  }
}

/// Servicio para manejar operaciones relacionadas con imágenes
class ImageService {
  final ApiClient _apiClient = ApiClient();

  // Método para acceder al ApiClient (necesario para el ServerImageProvider)
  ApiClient getApiClient() {
    return _apiClient;
  }

  /// Obtiene todas las imágenes de un centro específico
  Future<List<ServerImage>> getCenterImages(int centerId) async {
    try {
      final endpoint = '${ApiConstants.centers}$centerId/images/';
      debugPrint('Obteniendo imágenes del centro: $endpoint');

      final data = await _apiClient.get(
        endpoint,
        entityName: 'Imágenes del centro',
      );

      if (data is List) {
        return data.map((json) => ServerImage.fromJson(json)).toList();
      } else if (data is Map && data.containsKey('results') && data['results'] is List) {
        return (data['results'] as List).map((json) => ServerImage.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      debugPrint('Error en getCenterImages: $e');
      rethrow;
    }
  }

  /// Obtiene todas las imágenes disponibles (para admins)
  Future<List<ServerImage>> getAllImages() async {
    try {
      final data = await _apiClient.get(
        ApiConstants.images,
        entityName: 'Imágenes',
      );

      if (data is List) {
        return data.map((json) => ServerImage.fromJson(json)).toList();
      } else if (data is Map && data.containsKey('results') && data['results'] is List) {
        return (data['results'] as List).map((json) => ServerImage.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      debugPrint('Error en getAllImages: $e');
      rethrow;
    }
  }

  /// Obtiene las detecciones de una imagen específica
  Future<List<Map<String, dynamic>>> getImageDetections(String imageId) async {
    try {
      final endpoint = '${ApiConstants.images}$imageId/detecciones/';
      debugPrint('Obteniendo detecciones de imagen: $endpoint');

      final data = await _apiClient.get(
        endpoint,
        entityName: 'Detecciones de imagen',
      );

      if (data is List) {
        return List<Map<String, dynamic>>.from(data);
      }

      return [];
    } catch (e) {
      debugPrint('Error en getImageDetections: $e');
      rethrow;
    }
  }

  /// Sube una nueva imagen al servidor
  Future<ServerImage> uploadImage(
      String imagePath,
      int centerId,
      {Map<String, String>? additionalFields}
      ) async {
    try {
      final fields = {
        'center': centerId.toString(),
        ...?additionalFields,
      };

      final endpoint = ApiConstants.uploadImage;
      debugPrint('Subiendo imagen al centro $centerId: $endpoint');

      final data = await _apiClient.uploadFile(
        endpoint,
        imagePath,
        'file', // Este debería ser el nombre del campo en tu API
        fields,
        entityName: 'Imagen',
      );

      return ServerImage.fromJson(data);
    } catch (e) {
      debugPrint('Error en uploadImage: $e');
      rethrow;
    }
  }

  /// Elimina una imagen del servidor
  Future<void> deleteImage(String imageId) async {
    try {
      final endpoint = '${ApiConstants.images}$imageId/';
      await _apiClient.delete(
        endpoint,
        entityName: 'Imagen',
      );
    } catch (e) {
      debugPrint('Error en deleteImage: $e');
      rethrow;
    }
  }

  /// Obtiene la URL completa de una imagen
  String getImageUrl(String filePath) {
    final apiClient = ApiClient();
    final baseUrl = apiClient.baseUrl;

    // Si ya es una URL completa, devolverla
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return filePath;
    }

    // Si es una ruta relativa, construir la URL completa
    // Eliminar la barra inicial si existe
    if (filePath.startsWith('/')) {
      filePath = filePath.substring(1);
    }

    return '$baseUrl/$filePath';
  }
}