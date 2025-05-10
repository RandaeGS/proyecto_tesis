import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../entities/analisysresult.dart';
import '../inventory_snapshot.dart';

/// Servicio para manejar la comparación de inventarios a lo largo del tiempo
class InventoryComparisonService {
  static const String inventorySnapshotsKey = 'inventory_snapshots';

  /// Guarda una instantánea del inventario actual
  Future<bool> saveInventorySnapshot(
      int centerId,
      String name,
      String description,
      Map<String, int> productCounts,
      List<AnalysisResult> sourceResults,
      ) async {
    try {
      // Obtener snapshots existentes
      final snapshots = await getInventorySnapshots(centerId);

      // Crear un nuevo snapshot
      final newSnapshot = InventorySnapshot(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        description: description,
        centerId: centerId,
        createdAt: DateTime.now().toString(),
        productCounts: productCounts,
        sourceResultIds: sourceResults.map((r) => r.id).toList(),
      );

      // Agregar el nuevo snapshot a la lista
      snapshots.add(newSnapshot);

      // Guardar la lista actualizada
      final prefs = await SharedPreferences.getInstance();
      final snapshotsJson = snapshots.map((s) => s.toJson()).toList();
      await prefs.setString(
          '${inventorySnapshotsKey}_$centerId',
          jsonEncode(snapshotsJson)
      );

      return true;
    } catch (e) {
      debugPrint('Error al guardar snapshot de inventario: $e');
      return false;
    }
  }

  /// Obtiene todas las instantáneas de inventario para un centro
  Future<List<InventorySnapshot>> getInventorySnapshots(int centerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final snapshotsString = prefs.getString('${inventorySnapshotsKey}_$centerId');

      if (snapshotsString == null || snapshotsString.isEmpty) {
        return [];
      }

      final List<dynamic> snapshotsJson = jsonDecode(snapshotsString);
      return snapshotsJson
          .map((json) => InventorySnapshot.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error al obtener snapshots de inventario: $e');
      return [];
    }
  }

  /// Elimina una instantánea de inventario
  Future<bool> deleteInventorySnapshot(int centerId, String snapshotId) async {
    try {
      // Obtener todos los snapshots
      final snapshots = await getInventorySnapshots(centerId);

      // Remover el snapshot con el ID especificado
      snapshots.removeWhere((snapshot) => snapshot.id == snapshotId);

      // Guardar la lista actualizada
      final prefs = await SharedPreferences.getInstance();
      final snapshotsJson = snapshots.map((s) => s.toJson()).toList();
      await prefs.setString(
          '${inventorySnapshotsKey}_$centerId',
          jsonEncode(snapshotsJson)
      );

      return true;
    } catch (e) {
      debugPrint('Error al eliminar snapshot de inventario: $e');
      return false;
    }
  }

  /// Compara dos instantáneas de inventario y devuelve las diferencias
  Map<String, InventoryDifference> compareInventorySnapshots(
      InventorySnapshot baseSnapshot,
      InventorySnapshot comparisonSnapshot,
      ) {
    final differences = <String, InventoryDifference>{};

    // Combinar todas las categorías de productos de ambos snapshots
    final allCategories = {...baseSnapshot.productCounts.keys, ...comparisonSnapshot.productCounts.keys};

    for (final category in allCategories) {
      final baseCount = baseSnapshot.productCounts[category] ?? 0;
      final currentCount = comparisonSnapshot.productCounts[category] ?? 0;
      final difference = currentCount - baseCount;

      differences[category] = InventoryDifference(
        category: category,
        initialCount: baseCount,
        currentCount: currentCount,
        difference: difference,
        percentageChange: baseCount > 0
            ? (difference / baseCount * 100).toStringAsFixed(1) + '%'
            : 'N/A',
      );
    }

    return differences;
  }
}

/// Modelo para representar la diferencia en el inventario de un producto
class InventoryDifference {
  final String category;
  final int initialCount;
  final int currentCount;
  final int difference;
  final String percentageChange;

  InventoryDifference({
    required this.category,
    required this.initialCount,
    required this.currentCount,
    required this.difference,
    required this.percentageChange,
  });
}