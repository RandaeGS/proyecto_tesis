import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as Math;

import '../../entities/analisysresult.dart';
import '../../services/config.dart';
import '../../services/images/images_provider.dart';
import '../entity/inventory_snapshot.dart';


/// A central provider for product data across the app
class ProductDataProvider with ChangeNotifier {
  final _baseUrl = '${AppConfig.getApiUrl()}';
  String? _authToken;

  Map<String, int> _currentProductCounts = {};
  List<AnalysisResult> _recentDetections = [];
  bool _isLoading = false;
  String _errorMessage = '';
  DateTime _lastUpdated = DateTime.now();

  // Getters
  Map<String, int> get currentProductCounts => _currentProductCounts;
  List<AnalysisResult> get recentDetections => _recentDetections;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  DateTime get lastUpdated => _lastUpdated;

  void setAuthToken(String token) {
    _authToken = token;
  }

  Future<void> loadProductData(int centerId) async {
    if (_authToken == null) {
      _errorMessage = 'Auth token not set';
      debugPrint(_errorMessage);
      return;
    }

    _isLoading = true;

    try {
      debugPrint("Loading product data for center $centerId");

      await _loadLatestDetections(centerId);

      final latestSnapshot = await _loadLatestSnapshot(centerId);

      _mergeProductData(latestSnapshot);

      _lastUpdated = DateTime.now();
      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'Error al cargar datos de productos: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadLatestDetections(int centerId) async {
    try {
      final url = Uri.parse('$_baseUrl/api/detecciones/by-center/?center_id=$centerId');

      debugPrint("Fetching detections from $url");

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> detections = json.decode(response.body);

        _recentDetections = detections
            .where((detection) => detection['confirmed'] == true)
            .map((detection) => AnalysisResult.fromJson(detection))
            .toList();

        debugPrint('Loaded ${_recentDetections.length} confirmed detections');
      } else {
        debugPrint('Error loading detections: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading detections: $e');
    }
  }

  Future<InventorySnapshot?> _loadLatestSnapshot(int centerId) async {
    try {
      final url = Uri.parse('$_baseUrl/inventory/api/snapshots/by_center/?center_id=$centerId');

      debugPrint("Fetching snapshots from $url");

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> snapshots = json.decode(response.body);

        if (snapshots.isNotEmpty) {
          snapshots.sort((a, b) =>
              DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at']))
          );

          final latestSnapshot = InventorySnapshot.fromJson(snapshots.first);
          debugPrint('Loaded latest snapshot: ${latestSnapshot.name}');

          debugPrint('Snapshot product counts: ${latestSnapshot.productCounts}');

          return latestSnapshot;
        } else {
          debugPrint('No snapshots found for center $centerId');
        }
      } else {
        debugPrint('Error loading snapshots: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading snapshots: $e');
    }

    return null;
  }

  void _mergeProductData(InventorySnapshot? snapshot) {
    _currentProductCounts = {};

    if (snapshot != null) {
      if (snapshot.productCounts.isNotEmpty) {
        snapshot.productCounts.forEach((category, count) {
          if (count > 0) {
            _currentProductCounts[category] = count;
          }
        });
        debugPrint('Added ${_currentProductCounts.length} products from snapshot: ${snapshot.productCounts}');
      } else {
        debugPrint('Snapshot has empty product counts: ${snapshot.id} - ${snapshot.name}');
      }
    } else {
      debugPrint('No snapshot data available');
    }


    Map<String, int> detectionCounts = {};

    for (var detection in _recentDetections) {
      for (var item in detection.detecciones) {
        final category = item['class']?.toString() ?? '';
        if (category.isNotEmpty) {
          detectionCounts[category] = (detectionCounts[category] ?? 0) + 1;
        }
      }
    }

    debugPrint('Detection counts: $detectionCounts');

    detectionCounts.forEach((category, count) {
      if (_currentProductCounts.containsKey(category)) {
        _currentProductCounts[category] = Math.max(_currentProductCounts[category]!, count);
      } else {
        _currentProductCounts[category] = count;
      }
    });

    debugPrint('Final product count: ${_currentProductCounts.length} categories');
    debugPrint('Product data: $_currentProductCounts');
  }

  void updateProductCounts(Map<String, int> newCounts) {
    _currentProductCounts = Map<String, int>.from(newCounts);
    _lastUpdated = DateTime.now();

    debugPrint('Product counts updated: $_currentProductCounts');

    notifyListeners();
  }

  Future<bool> createInventorySnapshot(
      int centerId,
      String name,
      String description,
      {List<String>? sourceDetectionIds}
      ) async {
    if (_authToken == null) {
      _errorMessage = 'Auth token not set';
      debugPrint(_errorMessage);
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final url = Uri.parse('$_baseUrl/inventory/api/snapshots/');

      final detectionIds = sourceDetectionIds ??
          _recentDetections.map((detection) => detection.id).toList();

      if (_currentProductCounts.isEmpty) {
        _errorMessage = 'No hay productos para guardar en la instantánea';
        debugPrint(_errorMessage);
        return false;
      }

      final data = {
        'name': name,
        'description': description,
        'center': centerId,
        'product_counts': _currentProductCounts,
        'source_detections': detectionIds,
      };

      debugPrint('Creating snapshot with data: $data');

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
        await loadProductData(centerId);
        return true;
      } else {
        _errorMessage = 'Error al guardar instantánea: ${response.statusCode} - ${response.body}';
        debugPrint(_errorMessage);
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error al guardar instantánea: $e';
      debugPrint(_errorMessage);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> syncWithImageProvider(ServerImageProvider imageProvider, int centerId) async {
    try {
      _isLoading = true;
      notifyListeners();

      debugPrint('Syncing with image provider');

      final imageCounts = imageProvider.getProductCounts(onlyConfirmed: true);

      debugPrint('Image provider counts: $imageCounts');

      final updatedCounts = Map<String, int>.from(_currentProductCounts);

      imageCounts.forEach((category, count) {
        if (count > 0) {
          if (updatedCounts.containsKey(category)) {
            updatedCounts[category] = Math.max(updatedCounts[category]!, count);
          } else {
            updatedCounts[category] = count;
          }
        }
      });

      _currentProductCounts = updatedCounts;

      await _loadLatestDetections(centerId);

      _lastUpdated = DateTime.now();

      debugPrint('Sync complete. Updated product counts: $_currentProductCounts');
    } catch (e) {
      debugPrint('Error syncing with image provider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}