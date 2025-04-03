import 'package:flutter/material.dart';
import '../../entities/analisysresult.dart';
import 'dart:developer' as developer;

/// Diálogo para confirmar los resultados del análisis con diseño visualmente mejorado
class ConfirmationDialog {
  /// Traduce el nombre de un producto a un formato legible
  static String _translateProductName(String rawName) {
    // Limpiamos el nombre antes de la traducción
    final cleanName = rawName.trim().toLowerCase();

    // Mapa de traducciones
    final translations = {
      'beverage': 'Bebidas',
      'canned_food': 'Alimentos Enlatados',
      'canned': 'Alimentos Enlatados',
      'condiments': 'Condimentos',
      'dairy': 'Leches en Polvo',
      'crackers': 'Galletas',
      'crackers_cookies': 'Galletas',
      'cereal': 'Cereales',
      'pasta_noodles': 'Pastas y Fideos',
      'pasta': 'Pastas y Fideos',
      'noodles': 'Pastas y Fideos',
      'agua': 'Bebidas',
      'leche': 'Leches en Polvo',
      'galletas': 'Galletas',
      'pasta': 'Pastas y Fideos',
      'fideos': 'Pastas y Fideos',
      'cereales': 'Cereales',
      'galleta': 'Galletas',
      'enlatado': 'Alimentos Enlatados',
      'enlatados': 'Alimentos Enlatados',
      'latas': 'Alimentos Enlatados',
      'conservas': 'Alimentos Enlatados',
      'bebida': 'Bebidas',
      'bebidas': 'Bebidas',
      'condimento': 'Condimentos',
    };

    // Si está en el mapa de traducciones, devolver la traducción
    if (translations.containsKey(cleanName)) {
      return translations[cleanName]!;
    }

    // Si no está en el mapa, intentar buscar coincidencias parciales
    for (final key in translations.keys) {
      if (cleanName.contains(key)) {
        return translations[key]!;
      }
    }

    // Si no hay coincidencias, capitalizar la primera letra y devolver
    if (cleanName.isNotEmpty) {
      return cleanName[0].toUpperCase() + cleanName.substring(1);
    }

    return 'Producto Desconocido';
  }

  /// Muestra un diálogo para confirmar o rechazar los resultados del análisis
  static Future<bool?> show(BuildContext context, AnalysisResult result) {
    // Procesar y agrupar las detecciones por tipo de producto
    final Map<String, List<Map<String, dynamic>>> groupedDetections = {};
    final Map<String, int> productCounts = {};

    for (var detection in result.detecciones) {
      final className = detection['class'] ?? 'unknown';
      final translatedName = _translateProductName(className);

      if (!groupedDetections.containsKey(translatedName)) {
        groupedDetections[translatedName] = [];
      }

      groupedDetections[translatedName]!.add(detection);
      productCounts[translatedName] = (productCounts[translatedName] ?? 0) + 1;
    }

    // Obtener las categorías ordenadas por cantidad
    final categories = productCounts.keys.toList()
      ..sort((a, b) => productCounts[b]!.compareTo(productCounts[a]!));

    // Formatear la fecha en un formato más amigable
    String formattedDate = result.fechaCreacion;
    try {
      final dateTime = DateTime.parse(result.fechaCreacion);
      formattedDate = '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      developer.log('Error al parsear fecha: $e', name: 'ConfirmationDialog');
    }

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // Colores personalizados según el tipo de producto
        Color getColorForProduct(String product) {
          final productLower = product.toLowerCase();
          if (productLower.contains('bebida')) return Colors.blue;
          if (productLower.contains('enlatado')) return Colors.orange;
          if (productLower.contains('leche')) return Colors.cyan;
          if (productLower.contains('galleta')) return Colors.amber;
          if (productLower.contains('cereal')) return Colors.brown;
          if (productLower.contains('pasta') || productLower.contains('fideo')) return Colors.yellow.shade800;
          if (productLower.contains('condimento')) return Colors.red;
          return Colors.purple;
        }

        // Icono según el tipo de producto
        IconData getIconForProduct(String product) {
          final productLower = product.toLowerCase();
          if (productLower.contains('bebida')) return Icons.water_drop;
          if (productLower.contains('enlatado')) return Icons.lunch_dining;
          if (productLower.contains('leche')) return Icons.coffee;
          if (productLower.contains('galleta')) return Icons.cookie;
          if (productLower.contains('cereal')) return Icons.breakfast_dining;
          if (productLower.contains('pasta') || productLower.contains('fideo')) return Icons.ramen_dining;
          if (productLower.contains('condimento')) return Icons.kitchen;
          return Icons.inventory;
        }

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 5,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Encabezado con color de fondo
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Icon(Icons.inventory_2, color: Colors.blue),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Confirmar Resultados',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contenido principal
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Mensaje principal
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.help_outline, color: Colors.blue.shade700, size: 18),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      '¿Desea guardar estos resultados?',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Si confirma, estos productos se añadirán al inventario',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Tarjetas de información
                        Row(
                          children: [
                            _buildInfoCard(
                              icon: Icons.inventory_2,
                              title: 'Total',
                              value: '${result.numeroObjetos}',
                              color: Colors.green,
                            ),
                            const SizedBox(width: 8),
                            _buildInfoCard(
                              icon: Icons.timer,
                              title: 'Tiempo',
                              value: '${result.tiempoProcesamiento.toStringAsFixed(1)} s',
                              color: Colors.orange,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Detalles técnicos en un panel expandible
                        ExpansionTile(
                          title: const Text(
                            'Detalles técnicos',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          initiallyExpanded: false,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Column(
                                children: [
                                  _buildTechnicalDetail(
                                    'ID:',
                                    result.id,
                                    Icons.fingerprint,
                                  ),
                                  _buildTechnicalDetail(
                                    'Fecha:',
                                    formattedDate,
                                    Icons.calendar_today,
                                  ),
                                  _buildTechnicalDetail(
                                    'Modelo:',
                                    result.tipoModelo,
                                    Icons.model_training,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Productos detectados
                        const Text(
                          'Productos Detectados',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Mostrar productos agrupados por categoría
                        ...categories.map((category) {
                          final items = groupedDetections[category] ?? [];
                          final count = productCounts[category] ?? 0;
                          final color = getColorForProduct(category);
                          final icon = getIconForProduct(category);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 2,
                            child: ExpansionTile(
                              initiallyExpanded: true,
                              leading: CircleAvatar(
                                backgroundColor: color.withOpacity(0.2),
                                child: Icon(icon, color: color, size: 20),
                              ),
                              title: Text(
                                '$category ($count)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: items.map((item) {
                                      final confidence = item['confidence'] ?? 0.0;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              color: color,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                'Confianza: ${(confidence * 100).toStringAsFixed(0)}%',
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),

                  // Pie del diálogo con acciones
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.close),
                          label: const Text('Cancelar'),
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check),
                          label: const Text('Guardar'),
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Tarjeta de información con altura fija
  static Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        height: 80, // Altura fija para evitar problemas de layout
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Usar min para evitar expansion
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(), // Usar Spacer en lugar de Expanded
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Detalles técnicos con icono
  static Widget _buildTechnicalDetail(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          // Usar un ancho limitado para el label
          SizedBox(
            width: 50,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}