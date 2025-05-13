// Este es un componente que podemos añadir a la pantalla ManualInventoryManagementScreen
// para mostrar un historial de reconciliaciones
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../services/inventory_reconciliation_service.dart';

class ReconciliationHistoryWidget extends StatefulWidget {
  final int centerId;

  const ReconciliationHistoryWidget({
    Key? key,
    required this.centerId,
  }) : super(key: key);

  @override
  State<ReconciliationHistoryWidget> createState() => _ReconciliationHistoryWidgetState();
}

class _ReconciliationHistoryWidgetState extends State<ReconciliationHistoryWidget> {
  bool _isLoading = true;
  List<ReconciliationHistoryItem> _historyItems = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('reconciliation_history_${widget.centerId}');

      if (historyJson != null && historyJson.isNotEmpty) {
        final List<dynamic> itemsJson = jsonDecode(historyJson);
        _historyItems = itemsJson
            .map((item) => ReconciliationHistoryItem.fromJson(item))
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));  // Ordenar por fecha descendente
      }
    } catch (e) {
      debugPrint('Error al cargar historial de reconciliación: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _historyItems.isEmpty
        ? const Center(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'No hay historial de reconciliaciones',
          style: TextStyle(
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    )
        : ListView.builder(
      itemCount: _historyItems.length,
      itemBuilder: (context, index) {
        final item = _historyItems[index];
        return _buildHistoryItem(item);
      },
    );
  }

  Widget _buildHistoryItem(ReconciliationHistoryItem item) {
    // Determinar el icono y color según la acción
    IconData actionIcon;
    Color actionColor;

    switch (item.action) {
      case 'add':
        actionIcon = Icons.add_circle_outline;
        actionColor = Colors.green;
        break;
      case 'replace':
        actionIcon = Icons.swap_horizontal_circle_outlined;
        actionColor = Colors.orange;
        break;
      case 'ignore':
        actionIcon = Icons.do_not_disturb_alt_outlined;
        actionColor = Colors.grey;
        break;
      default:
        actionIcon = Icons.help_outline;
        actionColor = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: actionColor.withOpacity(0.2),
          child: Icon(actionIcon, color: actionColor),
        ),
        title: Text(
          item.category,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatTimestamp(item.timestamp),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              _getActionDescription(item),
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }

  String _getActionDescription(ReconciliationHistoryItem item) {
    switch (item.action) {
      case 'add':
        return 'Añadió ${item.detectedCount} unidades al inventario (antes: ${item.inventoryCount})';
      case 'replace':
        final diff = item.detectedCount - item.inventoryCount;
        final changeText = diff > 0
            ? 'aumento de $diff'
            : diff < 0
            ? 'reducción de ${diff.abs()}'
            : 'sin cambios';
        return 'Estableció ${item.detectedCount} unidades ($changeText)';
      case 'ignore':
        return 'Ignoró ${item.detectedCount} unidades detectadas';
      default:
        return 'Acción desconocida';
    }
  }
}

/// Clase para representar un elemento del historial de reconciliación
class ReconciliationHistoryItem {
  final String category;
  final int inventoryCount;
  final int detectedCount;
  final String action;
  final String timestamp;
  final String? imageId;

  ReconciliationHistoryItem({
    required this.category,
    required this.inventoryCount,
    required this.detectedCount,
    required this.action,
    required this.timestamp,
    this.imageId,
  });

  /// Crea una instancia desde un mapa JSON
  factory ReconciliationHistoryItem.fromJson(Map<String, dynamic> json) {
    return ReconciliationHistoryItem(
      category: json['category'] ?? '',
      inventoryCount: json['inventoryCount'] ?? 0,
      detectedCount: json['detectedCount'] ?? 0,
      action: json['action'] ?? '',
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
      imageId: json['imageId'],
    );
  }

  /// Convierte la instancia a un mapa JSON
  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'inventoryCount': inventoryCount,
      'detectedCount': detectedCount,
      'action': action,
      'timestamp': timestamp,
      if (imageId != null) 'imageId': imageId,
    };
  }

  /// Crea una instancia a partir de una decisión de reconciliación
  factory ReconciliationHistoryItem.fromDecision(ReconciliationDecision decision) {
    return ReconciliationHistoryItem(
      category: decision.conflict.category,
      inventoryCount: decision.conflict.currentInventoryCount,
      detectedCount: decision.conflict.detectedCount,
      action: decision.action.toString().split('.').last,
      timestamp: DateTime.now().toIso8601String(),
      imageId: decision.conflict.imageId,
    );
  }
}

/// Función para guardar el historial de reconciliación
Future<void> saveReconciliationHistory(
    int centerId,
    List<ReconciliationDecision> decisions,
    ) async {
  try {
    final prefs = await SharedPreferences.getInstance();

    // Cargar historial existente
    List<ReconciliationHistoryItem> historyItems = [];
    final historyJson = prefs.getString('reconciliation_history_$centerId');

    if (historyJson != null && historyJson.isNotEmpty) {
      final List<dynamic> itemsJson = jsonDecode(historyJson);
      historyItems = itemsJson.map((item) => ReconciliationHistoryItem.fromJson(item)).toList();
    }

    // Añadir nuevas decisiones al historial
    for (var decision in decisions) {
      historyItems.add(ReconciliationHistoryItem.fromDecision(decision));
    }

    // Limitar el historial a las últimas 100 entradas
    if (historyItems.length > 100) {
      historyItems = historyItems.sublist(historyItems.length - 100);
    }

    // Guardar historial actualizado
    final updatedHistoryJson = jsonEncode(historyItems.map((item) => item.toJson()).toList());
    await prefs.setString('reconciliation_history_$centerId', updatedHistoryJson);

  } catch (e) {
    debugPrint('Error al guardar historial de reconciliación: $e');
  }
}