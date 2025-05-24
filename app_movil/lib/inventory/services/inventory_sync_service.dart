import 'package:flutter/material.dart';
import '../../services/images/images_provider.dart';
import '../services/inventory_comparison_provider.dart';

class InventorySyncService {
  final ServerImageProvider imageProvider;
  final InventoryComparisonProvider inventoryProvider;

  InventorySyncService({
    required this.imageProvider,
    required this.inventoryProvider,
  });


  Future<bool> syncInventoryWithImages(int centerId) async {
    try {
      await inventoryProvider.loadInventorySnapshots(centerId);
      final currentSnapshots = inventoryProvider.snapshots;

      final Map<String, int> imageDetectedCounts = imageProvider.getProductCounts(onlyConfirmed: true);

      if (currentSnapshots.isEmpty) {
        return await _createNewSnapshot(
          centerId,
          imageDetectedCounts,
          imageProvider.confirmedCenterDetections,
          'Instantánea inicial desde imágenes',
          'Generada automáticamente desde imágenes detectadas',
        );
      }

      final latestSnapshot = currentSnapshots.first;
      final Map<String, int> currentCounts = Map.from(latestSnapshot.productCounts);

      final Map<String, int> combinedCounts = _combineInventoryCounts(currentCounts, imageDetectedCounts);

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


  Map<String, int> getUpdatedInventoryCounts(Map<String, int> currentCounts) {
    final Map<String, int> imageDetectedCounts = imageProvider.getProductCounts(onlyConfirmed: true);
    return _combineInventoryCounts(currentCounts, imageDetectedCounts);
  }


  Map<String, int> _combineInventoryCounts(
      Map<String, int> baseCounts,
      Map<String, int> newCounts
      ) {
    final Map<String, int> result = Map.from(baseCounts);

    newCounts.forEach((category, count) {
      if (!result.containsKey(category)) {
        result[category] = count;
      } else {
        result[category] = result[category]! + count;
      }
    });

    return result;
  }

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