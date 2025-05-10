import 'package:flutter/material.dart';
import '../../services/images/images_provider.dart';
import '../entity/inventory_snapshot.dart';
import '../services/inventory_comparison_provider.dart';

/// Servicio para sincronizar el inventario entre la gestión manual y la detección por imágenes
class InventorySyncService {
  final ServerImageProvider imageProvider;
  final InventoryComparisonProvider inventoryProvider;

  InventorySyncService({
    required this.imageProvider,
    required this.inventoryProvider,
  });

  /// Sincroniza los resultados de las imágenes con el inventario actual
  /// y crea una nueva instantánea combinada
  Future<bool> syncInventoryWithImages(int centerId) async {
    try {
      // Obtener el inventario actual (la instantánea más reciente)
      await inventoryProvider.loadInventorySnapshots(centerId);
      final currentSnapshots = inventoryProvider.snapshots;

      // Obtener conteos de productos detectados en imágenes
      final Map<String, int> imageDetectedCounts = imageProvider.getProductCounts(onlyConfirmed: true);

      // Si no hay instantáneas previas, simplemente crear una nueva con los datos de imágenes
      if (currentSnapshots.isEmpty) {
        return await _createNewSnapshot(
          centerId,
          imageDetectedCounts,
          imageProvider.confirmedCenterDetections,
          'Instantánea inicial desde imágenes',
          'Generada automáticamente desde imágenes detectadas',
        );
      }

      // Obtener la instantánea más reciente
      final latestSnapshot = currentSnapshots.first;
      final Map<String, int> currentCounts = Map.from(latestSnapshot.productCounts);

      // Combinar los conteos manteniendo los valores más altos o agregando nuevas categorías
      final Map<String, int> combinedCounts = _combineInventoryCounts(currentCounts, imageDetectedCounts);

      // Crear una nueva instantánea con los conteos combinados
      return await _createNewSnapshot(
        centerId,
        combinedCounts,
        imageProvider.confirmedCenterDetections,
        'Sincronización de inventario',
        'Combinación de inventario manual y detecciones por imágenes',
      );
    } catch (e) {
      debugPrint('Error al sincronizar inventario: $e');
      return false;
    }
  }

  /// Actualiza el inventario desde las imágenes sin crear una nueva instantánea
  /// (útil para actualizar la vista sin guardar)
  Map<String, int> getUpdatedInventoryCounts(Map<String, int> currentCounts) {
    final Map<String, int> imageDetectedCounts = imageProvider.getProductCounts(onlyConfirmed: true);
    return _combineInventoryCounts(currentCounts, imageDetectedCounts);
  }

  /// Combina dos conjuntos de conteos de inventario, manteniendo los valores más altos
  /// o agregando nuevas categorías según sea necesario
  Map<String, int> _combineInventoryCounts(
      Map<String, int> baseCounts,
      Map<String, int> newCounts
      ) {
    final Map<String, int> result = Map.from(baseCounts);

    // Actualizar o agregar categorías desde los nuevos conteos
    newCounts.forEach((category, count) {
      if (!result.containsKey(category)) {
        // Si es una nueva categoría, agregarla
        result[category] = count;
      } else {
        // Si la categoría ya existe, quedarse con el valor más alto
        // Esto asume que las imágenes detectan productos adicionales, no reemplazos
        result[category] = result[category]! + count;
      }
    });

    return result;
  }

  /// Crea una nueva instantánea de inventario
  Future<bool> _createNewSnapshot(
      int centerId,
      Map<String, int> productCounts,
      List<dynamic> sourceResults,
      String name,
      String description,
      ) async {
    return await inventoryProvider.saveInventorySnapshot(
      centerId,
      name,
      description,
      productCounts,
      sourceResults,
    );
  }
}