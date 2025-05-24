import 'package:app_movil/inventory/services/product_data_provider.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../entities/analisysresult.dart';
import '../entity/inventory_difference.dart';
import '../entity/inventory_snapshot.dart';
import '../../services/config.dart';

class InventoryComparisonProvider with ChangeNotifier {
  final _baseUrl = '${AppConfig.getApiUrl()}/inventory/api';
  String? _authToken;

  List<InventorySnapshot> _snapshots = [];
  bool _isLoading = false;
  String _errorMessage = '';

  InventorySnapshot? _baseSnapshot;
  InventorySnapshot? _comparisonSnapshot;

  Map<String, InventoryDifference> _comparisonResults = {};

  ProductDataProvider? _productDataProvider;

  List<InventorySnapshot> get snapshots => _snapshots;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  InventorySnapshot? get baseSnapshot => _baseSnapshot;
  InventorySnapshot? get comparisonSnapshot => _comparisonSnapshot;
  Map<String, InventoryDifference> get comparisonResults => _comparisonResults;

  void setProductDataProvider(ProductDataProvider provider) {
    _productDataProvider = provider;
    _productDataProvider!.addListener(_handleProductDataChange);
    debugPrint("ProductDataProvider registered with InventoryComparisonProvider");
  }

  void disposeProductDataProvider() {
    if (_productDataProvider != null) {
      _productDataProvider!.removeListener(_handleProductDataChange);
      _productDataProvider = null;
    }
  }

  void _handleProductDataChange() {
    debugPrint("ProductDataProvider change detected in InventoryComparisonProvider");
    if (_productDataProvider != null && !_isLoading) {
      if (_baseSnapshot != null && _snapshots.isNotEmpty && _baseSnapshot!.id == _snapshots.first.id) {
        debugPrint("Updating selected snapshot with new product data");
        final updatedCounts = Map<String, int>.from(_productDataProvider!.currentProductCounts);
        _baseSnapshot = _baseSnapshot!.copyWith(productCounts: updatedCounts);
        notifyListeners();
      }
    }
  }


  void setAuthToken(String token) {
    _authToken = token;
  }

  Future<void> loadInventorySnapshots(int centerId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final url = Uri.parse('$_baseUrl/snapshots/by_center/?center_id=$centerId');

      debugPrint("Loading inventory snapshots from $url");

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> snapshotsJson = json.decode(response.body);

        debugPrint("Received ${snapshotsJson.length} snapshots");

        if (snapshotsJson.isNotEmpty) {
          debugPrint("First snapshot data: ${snapshotsJson.first}");
        }

        _snapshots = snapshotsJson.map((json) => InventorySnapshot.fromJson(json)).toList();

        _snapshots.sort((a, b) =>
            DateTime.parse(b.createdAt).compareTo(DateTime.parse(a.createdAt))
        );

        if (_snapshots.isNotEmpty) {
          final firstSnapshot = _snapshots.first;
          debugPrint("First snapshot: ${firstSnapshot.name}, Products: ${firstSnapshot.productCounts}");
        }

        if (_baseSnapshot != null && !_snapshots.any((s) => s.id == _baseSnapshot!.id)) {
          _baseSnapshot = null;
        }

        if (_comparisonSnapshot != null && !_snapshots.any((s) => s.id == _comparisonSnapshot!.id)) {
          _comparisonSnapshot = null;
        }

        if (_baseSnapshot == null || _comparisonSnapshot == null) {
          _comparisonResults = {};
        }
      } else {
        _errorMessage = 'Error al cargar instantáneas: ${response.statusCode}';
        debugPrint(_errorMessage);
      }
    } catch (e) {
      _errorMessage = 'Error al cargar instantáneas de inventario: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
      final url = Uri.parse('$_baseUrl/snapshots/');

      final List<String> sourceResultIds = [];
      for (final result in sourceResults) {
        if (result is AnalysisResult) {
          sourceResultIds.add(result.id);
        } else if (result is String) {
          sourceResultIds.add(result);
        }
      }

      if (productCounts.isEmpty) {
        _errorMessage = 'Error: No hay productos para guardar en la instantánea';
        debugPrint(_errorMessage);
        return false;
      }

      final filteredCounts = Map<String, int>.from(productCounts);
      filteredCounts.removeWhere((key, value) => value <= 0);

      if (filteredCounts.isEmpty) {
        _errorMessage = 'Error: No hay productos con cantidades válidas para guardar';
        debugPrint(_errorMessage);
        return false;
      }

      debugPrint('Sending snapshot data: Product counts: $filteredCounts, Sources: $sourceResultIds');

      final data = {
        'name': name,
        'description': description,
        'center': centerId,
        'product_counts': filteredCounts,
        'source_detections': sourceResultIds,
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: json.encode(data),
      );

      if (response.statusCode == 201) {
        debugPrint('Snapshot created successfully: ${response.body}');

        await Future.delayed(const Duration(milliseconds: 500));

        await loadInventorySnapshots(centerId);

        if (_productDataProvider != null) {
          await _productDataProvider!.loadProductData(centerId);
        }

        return true;
      } else {
        _errorMessage = 'Error al guardar instantánea: ${response.statusCode} - ${response.body}';
        debugPrint(_errorMessage);
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error al guardar instantánea de inventario: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveSnapshotFromProductData(
      int centerId,
      String name,
      String description,
      ) async {
    if (_productDataProvider == null) {
      _errorMessage = 'Product data provider not available';
      notifyListeners();
      return false;
    }

    final productCounts = Map<String, int>.from(_productDataProvider!.currentProductCounts);
    final sourceResults = _productDataProvider!.recentDetections;

    if (productCounts.isEmpty) {
      debugPrint('Warning: No product counts available in the product data provider');
      for (var detection in sourceResults) {
        for (var item in detection.detecciones) {
          final category = item['class']?.toString() ?? '';
          if (category.isNotEmpty) {
            productCounts[category] = (productCounts[category] ?? 0) + 1;
          }
        }
      }

      if (productCounts.isEmpty) {
        _errorMessage = 'Error: No hay productos para guardar en la instantánea';
        notifyListeners();
        return false;
      }
    }

    return await saveInventorySnapshot(
      centerId,
      name,
      description,
      productCounts,
      sourceResults.map((result) => result.id).toList(),
    );
  }

  Future<bool> deleteInventorySnapshot(int centerId, String snapshotId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final url = Uri.parse('$_baseUrl/snapshots/$snapshotId/');

      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 204) {
        _snapshots.removeWhere((snapshot) => snapshot.id == snapshotId);

        if (_baseSnapshot?.id == snapshotId) {
          _baseSnapshot = null;
        }

        if (_comparisonSnapshot?.id == snapshotId) {
          _comparisonSnapshot = null;
        }

        if (_baseSnapshot == null || _comparisonSnapshot == null) {
          _comparisonResults = {};
        }

        notifyListeners();
        return true;
      } else {
        _errorMessage = 'No se pudo eliminar la instantánea: ${response.statusCode}';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error al eliminar instantánea de inventario: $e';
      debugPrint(_errorMessage);
      _isLoading = false;
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectBaseSnapshot(InventorySnapshot snapshot) {
    _baseSnapshot = snapshot;
    _comparisonResults = {}; // Reset results
    notifyListeners();

    if (_comparisonSnapshot != null) {
      compareSnapshots();
    }
  }

  void selectComparisonSnapshot(InventorySnapshot snapshot) {
    _comparisonSnapshot = snapshot;
    _comparisonResults = {}; // Reset results
    notifyListeners();

    if (_baseSnapshot != null) {
      compareSnapshots();
    }
  }

  void compareSnapshots() {
    if (_baseSnapshot == null || _comparisonSnapshot == null) {
      _errorMessage = 'Debes seleccionar dos instantáneas para comparar';
      notifyListeners();
      return;
    }

    _comparisonResults = _compareInventorySnapshots(
      _baseSnapshot!,
      _comparisonSnapshot!,
    );

    notifyListeners();
  }

  Map<String, InventoryDifference> _compareInventorySnapshots(
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

  void clearComparison() {
    _baseSnapshot = null;
    _comparisonSnapshot = null;
    _comparisonResults = {};
    notifyListeners();
  }

  InventorySnapshot? getLatestSnapshot() {
    if (_snapshots.isEmpty) return null;
    return _snapshots.first;
  }
}