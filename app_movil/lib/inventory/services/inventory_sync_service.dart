import 'package:flutter/material.dart';
import '../../services/images/images_provider.dart';
import '../entity/inventory_snapshot.dart';
import '../services/inventory_comparison_provider.dart';

/// Service for synchronizing inventory between image detection and manual inventory
class InventorySyncService {
  final ServerImageProvider imageProvider;
  final InventoryComparisonProvider inventoryProvider;

  InventorySyncService({
    required this.imageProvider,
    required this.inventoryProvider,
  });

  /// Synchronizes image detection results with current inventory
  /// and creates a new combined snapshot
  Future<bool> syncInventoryWithImages(int centerId) async {
    try {
      // Get current inventory (most recent snapshot)
      await inventoryProvider.loadInventorySnapshots(centerId);
      final currentSnapshots = inventoryProvider.snapshots;

      // Get product counts detected in images
      final Map<String, int> imageDetectedCounts = imageProvider.getProductCounts(onlyConfirmed: true);

      // If there are no previous snapshots, just create a new one with image data
      if (currentSnapshots.isEmpty) {
        return await _createNewSnapshot(
          centerId,
          imageDetectedCounts,
          imageProvider.confirmedCenterDetections,
          'Instantánea inicial desde imágenes',
          'Generada automáticamente desde imágenes detectadas',
        );
      }

      // Get the most recent snapshot
      final latestSnapshot = currentSnapshots.first;
      final Map<String, int> currentCounts = Map.from(latestSnapshot.productCounts);

      // Combine counts keeping the highest values or adding new categories
      final Map<String, int> combinedCounts = _combineInventoryCounts(currentCounts, imageDetectedCounts);

      // Create a new snapshot with combined counts
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

  /// Updates inventory from images without creating a new snapshot
  /// (useful for updating the view without saving)
  Map<String, int> getUpdatedInventoryCounts(Map<String, int> currentCounts) {
    final Map<String, int> imageDetectedCounts = imageProvider.getProductCounts(onlyConfirmed: true);
    return _combineInventoryCounts(currentCounts, imageDetectedCounts);
  }

  /// Combines two sets of inventory counts, keeping the highest values
  /// or adding new categories as needed
  Map<String, int> _combineInventoryCounts(
      Map<String, int> baseCounts,
      Map<String, int> newCounts
      ) {
    final Map<String, int> result = Map.from(baseCounts);

    // Update or add categories from new counts
    newCounts.forEach((category, count) {
      if (!result.containsKey(category)) {
        // If it's a new category, add it
        result[category] = count;
      } else {
        // If the category already exists, add the values
        // This assumes the images detect additional products, not replacements
        result[category] = result[category]! + count;
      }
    });

    return result;
  }

  /// Creates a new inventory snapshot
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