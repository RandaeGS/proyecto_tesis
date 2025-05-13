import 'package:flutter/material.dart';
import '../../../inventory/services/inventory_comparison_provider.dart';
import '../../../inventory/services/product_data_provider.dart';
import '../../../services/images/images_provider.dart';
import '../widget/reconciliation_history_widget.dart';

/// Estructura para representar un conflicto de reconciliación
class ReconciliationConflict {
  final String category;
  final int currentInventoryCount;
  final int detectedCount;
  final String imageId;

  ReconciliationConflict({
    required this.category,
    required this.currentInventoryCount,
    required this.detectedCount,
    required this.imageId,
  });
}

/// Tipos de acción de reconciliación
enum ReconciliationAction {
  add,       // Añadir a existencias
  replace,   // Reemplazar cantidad actual
  ignore     // Ignorar la detección
}

/// Estructura para representar una decisión de reconciliación
class ReconciliationDecision {
  final ReconciliationConflict conflict;
  final ReconciliationAction action;

  ReconciliationDecision({
    required this.conflict,
    required this.action,
  });
}

/// Servicio para reconciliar los datos entre el inventario manual y las detecciones de imágenes
class InventoryReconciliationService {
  final ServerImageProvider imageProvider;
  final ProductDataProvider productDataProvider;
  final InventoryComparisonProvider inventoryProvider;

  InventoryReconciliationService({
    required this.imageProvider,
    required this.productDataProvider,
    required this.inventoryProvider,
  });

  /// Identifica conflictos entre detecciones de imágenes y el inventario manual
  Future<List<ReconciliationConflict>> identifyConflicts() async {
    final List<ReconciliationConflict> conflicts = [];

    // Obtener los productos detectados en imágenes (solo los confirmados)
    final Map<String, int> detectedCounts = imageProvider.getProductCounts(onlyConfirmed: true);

    // Obtener el inventario manual actual
    final Map<String, int> inventoryCounts = Map.from(productDataProvider.currentProductCounts);

    // Comprobar conflictos
    detectedCounts.forEach((category, detectedCount) {
      final currentCount = inventoryCounts[category] ?? 0;

      // Determinar si hay un conflicto significativo (por ejemplo, si la diferencia es >10%)
      if (currentCount > 0) {
        // Encontrar el ID de imagen para esta categoría
        String imageId = '';
        for (var detection in imageProvider.confirmedCenterDetections) {
          for (var item in detection.detecciones) {
            if (item['class'] == category) {
              imageId = detection.imageId ?? '';
              break;
            }
          }
          if (imageId.isNotEmpty) break;
        }

        conflicts.add(ReconciliationConflict(
          category: category,
          currentInventoryCount: currentCount,
          detectedCount: detectedCount,
          imageId: imageId,
        ));
      } else {
        // Si no existe en el inventario actual, también es un conflicto
        String imageId = '';
        for (var detection in imageProvider.confirmedCenterDetections) {
          for (var item in detection.detecciones) {
            if (item['class'] == category) {
              imageId = detection.imageId ?? '';
              break;
            }
          }
          if (imageId.isNotEmpty) break;
        }

        conflicts.add(ReconciliationConflict(
          category: category,
          currentInventoryCount: 0,
          detectedCount: detectedCount,
          imageId: imageId,
        ));
      }
    });

    return conflicts;
  }

  /// Realiza la reconciliación según la decisión del usuario
  Future<bool> reconcileInventory(
      BuildContext context,
      int centerId,
      List<ReconciliationDecision> decisions,
      ) async {
    try {
      // Obtener el inventario actual
      final Map<String, int> updatedCounts = Map.from(productDataProvider.currentProductCounts);
      bool hasChanges = false;

      // Aplicar las decisiones de reconciliación
      for (var decision in decisions) {
        switch (decision.action) {
          case ReconciliationAction.add:
            updatedCounts[decision.conflict.category] =
                (updatedCounts[decision.conflict.category] ?? 0) + decision.conflict.detectedCount;
            hasChanges = true;
            break;

          case ReconciliationAction.replace:
            updatedCounts[decision.conflict.category] = decision.conflict.detectedCount;
            hasChanges = true;
            break;

          case ReconciliationAction.ignore:
          // No hacer nada
            break;
        }
      }

      if (hasChanges) {
        // Actualizar el inventario con los nuevos conteos
        productDataProvider.updateProductCounts(updatedCounts);

        // Guardar una instantánea del inventario actualizado
        final snapshotName = 'Reconciliacion - ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
        final snapshotDesc = 'Actualizacion por reconciliación con imágenes';

        await inventoryProvider.saveInventorySnapshot(
          centerId,
          snapshotName,
          snapshotDesc,
          updatedCounts,
          imageProvider.confirmedCenterDetections.map((d) => d.id).toList(),
        );

        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error al reconciliar inventario: $e');
      return false;
    }
  }

  /// Registra una decisión de reconciliación en el historial (para futuras auditorías)
  Future<void> logReconciliationDecision(
      int centerId,
      ReconciliationDecision decision,
      ) async {
    try {
      // Registrar en el log de depuración
      debugPrint('Reconciliación para ${decision.conflict.category}: '
          '${decision.action.toString().split('.').last} - '
          'Inventario: ${decision.conflict.currentInventoryCount}, '
          'Detectado: ${decision.conflict.detectedCount}');

      // Registrar en el historial persistente
      // Importamos la función desde reconciliation_history_widget.dart
      await saveReconciliationHistory(centerId, [decision]);
    } catch (e) {
      debugPrint('Error al registrar decisión de reconciliación: $e');
    }
  }
}