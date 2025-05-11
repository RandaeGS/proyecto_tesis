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

  /// Sets the authentication token to use for API requests
  void setAuthToken(String token) {
    _authToken = token;
  }

  /// Loads all product data for a specific center
  Future<void> loadProductData(int centerId) async {
    if (_authToken == null) {
      _errorMessage = 'Auth token not set';
      debugPrint(_errorMessage);
      return;
    }

    _isLoading = true;
    // Don't call notifyListeners() yet to avoid errors during build

    try {
      debugPrint("Loading product data for center $centerId");

      // Step 1: Load latest detections
      await _loadLatestDetections(centerId);

      // Step 2: Load the latest inventory snapshot
      final latestSnapshot = await _loadLatestSnapshot(centerId);

      // Step 3: Merge data from detections and snapshot
      _mergeProductData(latestSnapshot);

      _lastUpdated = DateTime.now();
      _errorMessage = '';
    } catch (e) {
      _errorMessage = 'Error al cargar datos de productos: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      // Now it's safe to notify
      notifyListeners();
    }
  }

  /// Loads the latest confirmed detections from the server
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

        // Filter only confirmed detections
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

  /// Loads the latest inventory snapshot from the server
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
          // Sort by creation date (most recent first)
          snapshots.sort((a, b) =>
              DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at']))
          );

          final latestSnapshot = InventorySnapshot.fromJson(snapshots.first);
          debugPrint('Loaded latest snapshot: ${latestSnapshot.name}');

          // Debug: print the product counts in the snapshot
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

  /// Merges product data from detections and snapshot
  void _mergeProductData(InventorySnapshot? snapshot) {
    // Start with a clean slate
    _currentProductCounts = {};

    // First, add data from the latest snapshot if available
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

    // Then, add data from recent detections
    // Count items by class in the detection results
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

    // Update counts in the current products
    detectionCounts.forEach((category, count) {
      // If we already have this category from a snapshot, we should keep the max value
      if (_currentProductCounts.containsKey(category)) {
        _currentProductCounts[category] = Math.max(_currentProductCounts[category]!, count);
      } else {
        // Otherwise add the new category
        _currentProductCounts[category] = count;
      }
    });

    debugPrint('Final product count: ${_currentProductCounts.length} categories');
    debugPrint('Product data: $_currentProductCounts');
  }

  /// Updates the product counts directly and explicitly sends update notification
  void updateProductCounts(Map<String, int> newCounts) {
    // Make a deep copy to ensure we have a new reference
    _currentProductCounts = Map<String, int>.from(newCounts);
    _lastUpdated = DateTime.now();

    debugPrint('Product counts updated: $_currentProductCounts');

    // Trigger update explicitly
    notifyListeners();
  }

  /// Creates a new inventory snapshot with the current product counts
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

      // Use sourceDetectionIds if provided, otherwise use IDs from recentDetections
      final detectionIds = sourceDetectionIds ??
          _recentDetections.map((detection) => detection.id).toList();

      // Validate that we have product counts
      if (_currentProductCounts.isEmpty) {
        _errorMessage = 'No hay productos para guardar en la instantánea';
        debugPrint(_errorMessage);
        return false;
      }

      // Prepare data for API
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
        // Reload data to update everything
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

  /// Synchronizes the product data between providers
  Future<void> syncWithImageProvider(ServerImageProvider imageProvider, int centerId) async {
    try {
      _isLoading = true;
      notifyListeners();

      debugPrint('Syncing with image provider');

      // Get product counts from image provider (only confirmed)
      final imageCounts = imageProvider.getProductCounts(onlyConfirmed: true);

      debugPrint('Image provider counts: $imageCounts');

      // Create a copy of current counts for updating
      final updatedCounts = Map<String, int>.from(_currentProductCounts);

      // Update our current counts with this data
      imageCounts.forEach((category, count) {
        if (count > 0) {
          // If we already have this category, take the maximum
          if (updatedCounts.containsKey(category)) {
            updatedCounts[category] = Math.max(updatedCounts[category]!, count);
          } else {
            // Otherwise add the new category
            updatedCounts[category] = count;
          }
        }
      });

      // Update the product counts
      _currentProductCounts = updatedCounts;

      // Reload recent detections to ensure we have the latest
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