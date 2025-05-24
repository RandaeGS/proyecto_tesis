import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../entities/analisysresult.dart';
import '../entity/inventory_difference.dart';
import '../entity/inventory_snapshot.dart';

class InventoryComparisonService {
  static const String inventorySnapshotsKey = 'inventory_snapshots';

  Future<bool> saveInventorySnapshot(
      int centerId,
      String name,
      String description,
      Map<String, int> productCounts,
      List<AnalysisResult> sourceResults,
      ) async {
    try {
      final snapshots = await getInventorySnapshots(centerId);

      final newSnapshot = InventorySnapshot(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        description: description,
        centerId: centerId,
        createdAt: DateTime.now().toString(),
        productCounts: productCounts,
        sourceResultIds: sourceResults.map((r) => r.id).toList(),
      );

      snapshots.add(newSnapshot);

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

  Future<bool> deleteInventorySnapshot(int centerId, String snapshotId) async {
    try {
      final snapshots = await getInventorySnapshots(centerId);

      snapshots.removeWhere((snapshot) => snapshot.id == snapshotId);

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

  Map<String, InventoryDifference> compareInventorySnapshots(
      InventorySnapshot baseSnapshot,
      InventorySnapshot comparisonSnapshot,
      ) {
    final differences = <String, InventoryDifference>{};

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