import 'package:flutter/material.dart';
import '../../entities/analisysresult.dart';
import 'inventory_comparison_services.dart';
import '../inventory_snapshot.dart';

class InventoryComparisonProvider with ChangeNotifier {
  final InventoryComparisonService _comparisonService = InventoryComparisonService();

  List<InventorySnapshot> _snapshots = [];
  bool _isLoading = false;
  String _errorMessage = '';

  // Instantáneas seleccionadas para comparación
  InventorySnapshot? _baseSnapshot;
  InventorySnapshot? _comparisonSnapshot;

  // Resultados de la comparación
  Map<String, InventoryDifference> _comparisonResults = {};

  // Getters
  List<InventorySnapshot> get snapshots => _snapshots;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  InventorySnapshot? get baseSnapshot => _baseSnapshot;
  InventorySnapshot? get comparisonSnapshot => _comparisonSnapshot;
  Map<String, InventoryDifference> get comparisonResults => _comparisonResults;

  /// Carga las instantáneas de inventario para un centro específico
  Future<void> loadInventorySnapshots(int centerId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _snapshots = await _comparisonService.getInventorySnapshots(centerId);

      // Ordenar por fecha de creación (más recientes primero)
      _snapshots.sort((a, b) =>
          DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt))
      );

      // Resetear selecciones
      _baseSnapshot = null;
      _comparisonSnapshot = null;
      _comparisonResults = {};

    } catch (e) {
      _errorMessage = 'Error al cargar instantáneas de inventario: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Guarda una nueva instantánea de inventario
  Future<bool> saveInventorySnapshot(
      int centerId,
      String name,
      String description,
      Map<String, int> productCounts,
      List<dynamic> sourceResults,
      ) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      // Convertir la lista dinámica a una lista de AnalysisResult
      final List<AnalysisResult> typedResults = [];
      for (final result in sourceResults) {
        if (result is AnalysisResult) {
          typedResults.add(result);
        }
      }

      final success = await _comparisonService.saveInventorySnapshot(
        centerId,
        name,
        description,
        productCounts,
        typedResults,
      );

      if (success) {
        await loadInventorySnapshots(centerId);
      } else {
        _errorMessage = 'No se pudo guardar la instantánea de inventario';
      }

      return success;
    } catch (e) {
      _errorMessage = 'Error al guardar instantánea de inventario: $e';
      debugPrint(_errorMessage);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Elimina una instantánea de inventario
  Future<bool> deleteInventorySnapshot(int centerId, String snapshotId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final success = await _comparisonService.deleteInventorySnapshot(
        centerId,
        snapshotId,
      );

      if (success) {
        // Actualizar la lista local
        _snapshots.removeWhere((snapshot) => snapshot.id == snapshotId);

        // Si alguna de las instantáneas seleccionadas fue eliminada, reiniciarlas
        if (_baseSnapshot?.id == snapshotId) {
          _baseSnapshot = null;
        }

        if (_comparisonSnapshot?.id == snapshotId) {
          _comparisonSnapshot = null;
        }

        // Si ya no hay dos instantáneas seleccionadas, limpiar resultados
        if (_baseSnapshot == null || _comparisonSnapshot == null) {
          _comparisonResults = {};
        }
      } else {
        _errorMessage = 'No se pudo eliminar la instantánea de inventario';
      }

      return success;
    } catch (e) {
      _errorMessage = 'Error al eliminar instantánea de inventario: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Selecciona la instantánea base para comparación
  void selectBaseSnapshot(InventorySnapshot snapshot) {
    _baseSnapshot = snapshot;
    _comparisonResults = {}; // Resetear resultados
    notifyListeners();

    // Si ya está seleccionada la instantánea de comparación, realizar la comparación
    if (_comparisonSnapshot != null) {
      compareSnapshots();
    }
  }

  /// Selecciona la instantánea de comparación
  void selectComparisonSnapshot(InventorySnapshot snapshot) {
    _comparisonSnapshot = snapshot;
    _comparisonResults = {}; // Resetear resultados
    notifyListeners();

    // Si ya está seleccionada la instantánea base, realizar la comparación
    if (_baseSnapshot != null) {
      compareSnapshots();
    }
  }

  /// Realiza la comparación entre las instantáneas seleccionadas
  void compareSnapshots() {
    if (_baseSnapshot == null || _comparisonSnapshot == null) {
      _errorMessage = 'Debes seleccionar dos instantáneas para comparar';
      notifyListeners();
      return;
    }

    _comparisonResults = _comparisonService.compareInventorySnapshots(
      _baseSnapshot!,
      _comparisonSnapshot!,
    );

    notifyListeners();
  }

  /// Limpia las selecciones y resultados de comparación
  void clearComparison() {
    _baseSnapshot = null;
    _comparisonSnapshot = null;
    _comparisonResults = {};
    notifyListeners();
  }
}