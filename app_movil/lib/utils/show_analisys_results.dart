import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'dart:convert';
import '../entities/analisysresult.dart';

/// Clase que proporciona un diálogo elegante para mostrar resultados de análisis
class AnalysisResultsDialog {
  /// Muestra un diálogo con los resultados del análisis formateados visualmente
  static void show(BuildContext context, AnalysisResult result) {
    // Registrar la respuesta original para debug

    // Procesar los resultados para mostrar de forma más legible
    List<Map<String, dynamic>> processedResults = [];

    // Intentar parsear como JSON primero
    try {
      // Si está formateado como JSON, intentar decodificarlo
      final jsonData = json.decode(result.resultados);

      if (jsonData is Map<String, dynamic> && jsonData.containsKey('detections')) {
        final detections = jsonData['detections'] as List;

        // Crear un mapa de conteo por clase
        final Map<String, int> countByClass = {};
        final Map<String, double> confidenceSum = {};

        for (var detection in detections) {
          final Map<String, dynamic> det = detection as Map<String, dynamic>;
          final String className = det['class'] as String;
          final double confidence = (det['confidence'] as num).toDouble();

          // Contar ocurrencias y sumar confianza de cada clase
          countByClass[className] = (countByClass[className] ?? 0) + 1;
          confidenceSum[className] = (confidenceSum[className] ?? 0.0) + confidence;
        }

        // Convertir el mapa de conteo a la lista de resultados procesados
        countByClass.forEach((className, count) {
          processedResults.add({
            'count': count,
            'product': _translateProductName(className),
            'confidence': confidenceSum[className]! / count, // Calcular el promedio
          });
        });

        developer.log('Classes encontradas: ${countByClass.keys.join(', ')}',
            name: 'AnalysisResultsDialog');
      } else {
        developer.log('JSON no tiene formato esperado', name: 'AnalysisResultsDialog');
      }
    } catch (e) {
      // Si falla el parsing JSON, intentar métodos alternativos
      processedResults = _parseTextResults(result.resultados);
    }

    // Si no se pudo parsear, mostrar resultado literal
    if (processedResults.isEmpty) {
      developer.log('No se pudieron parsear los resultados. Mostrando datos crudos.',
          name: 'AnalysisResultsDialog');

      final String cleanedText = result.resultados
          .replaceAll('{', '')
          .replaceAll('}', '')
          .replaceAll('"', '')
          .replaceAll(':', ' ')
          .replaceAll(',', '')
          .replaceAll('[', '')
          .replaceAll(']', '');

      // Buscar clases en el texto crudo
      final List<String> potentialClasses = [
        'crackers', 'cereal', 'canned', 'canned_food', 'dairy',
        'beverage', 'pasta_noodles', 'condiments'
      ];

      for (var className in potentialClasses) {
        if (cleanedText.contains(className)) {
          processedResults.add({
            'count': 1, // Como no podemos determinar exactamente, utilizamos 1
            'product': _translateProductName(className),
            'confidence': 0.0,
          });
        }
      }
    }

    // Ordenar resultados por cantidad (mayor a menor)
    processedResults.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    // Calcular el total de productos
    final totalProducts = processedResults.fold<int>(
        0, (sum, item) => sum + (item['count'] as int));
    developer.log('Total de productos: $totalProducts', name: 'AnalysisResultsDialog');

    // Formatear la fecha en un formato más amigable
    String formattedDate = result.fechaCreacion;
    try {
      final dateTime = DateTime.parse(result.fechaCreacion);
      formattedDate = '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      developer.log('Error al parsear fecha: $e', name: 'AnalysisResultsDialog');
      // Mantener el formato original si no se puede parsear
    }

    // Usar un AlertDialog para asegurar que se ajuste mejor a diferentes tamaños de pantalla
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 5,
        // Usar un widget de tamaño limitado para evitar desbordamientos
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(dialogContext).size.height * 0.8,
            maxWidth: MediaQuery.of(dialogContext).size.width * 0.9,
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
                        child: Icon(Icons.analytics, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Resultados del Análisis',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(dialogContext),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
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
                      // Información general en tarjetas
                      Row(
                        children: [
                          _buildInfoCard(
                            icon: Icons.inventory_2,
                            title: 'Total',
                            value: totalProducts.toString(),
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

                      // Resultados del inventario con visualización gráfica
                      const Text(
                        'Inventario Detectado',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Lista de productos con barras visuales
                      if (processedResults.isNotEmpty)
                        ...processedResults.map((item) => _buildProductBar(
                          dialogContext,
                          product: item['product'] as String,
                          count: item['count'] as int,
                          total: totalProducts,
                          confidence: item['confidence'] as double? ?? 0.0,
                        ))
                      else
                        const Text(
                          'No se detectaron productos específicos',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),

                // Pie del diálogo con acciones
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // OutlinedButton.icon(
                      //   icon: const Icon(Icons.save_alt),
                      //   label: const Text('Guardar'),
                      //   onPressed: () {
                      //     // Implementar funcionalidad para guardar el reporte
                      //     Navigator.pop(dialogContext);
                      //     ScaffoldMessenger.of(dialogContext).showSnackBar(
                      //       const SnackBar(content: Text('Reporte guardado')),
                      //     );
                      //   },
                      // ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Aceptar'),
                        onPressed: () => Navigator.pop(dialogContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
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
      ),
    );
  }

  /// Intenta parsear el texto de resultados en varios formatos
  static List<Map<String, dynamic>> _parseTextResults(String text) {
    final results = <Map<String, dynamic>>[];

    // Intento 1: Líneas con formato "n:clase"
    final formatoNumeroClase = RegExp(r'(\d+)\s*:\s*([a-zA-Z_]+)');
    var matches = formatoNumeroClase.allMatches(text);

    for (var match in matches) {
      final count = int.tryParse(match.group(1) ?? '0') ?? 0;
      final className = match.group(2) ?? '';

      if (count > 0 && className.isNotEmpty) {
        results.add({
          'count': count,
          'product': _translateProductName(className),
          'confidence': 0.0,
        });
      }
    }

    // Si encontramos resultados, retornarlos
    if (results.isNotEmpty) return results;

    // Intento 2: Buscar menciones de clases directamente
    final classRegex = RegExp(r'"class"\s*:\s*"([^"]+)"');
    matches = classRegex.allMatches(text);

    // Contar las ocurrencias de cada clase
    final Map<String, int> classCounts = {};
    for (var match in matches) {
      final className = match.group(1) ?? '';
      if (className.isNotEmpty) {
        classCounts[className] = (classCounts[className] ?? 0) + 1;
      }
    }

    // Convertir conteos a resultados
    classCounts.forEach((className, count) {
      results.add({
        'count': count,
        'product': _translateProductName(className),
        'confidence': 0.0,
      });
    });

    return results;
  }

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

  // Barra visual para cada producto
  static Widget _buildProductBar(
      BuildContext context, {
        required String product,
        required int count,
        required int total,
        double confidence = 0.0,
      }) {
    final double percentage = total > 0 ? count / total : 0;
    // Calcular un ancho máximo seguro para la barra
    final double maxBarWidth = MediaQuery.of(context).size.width * 0.5;

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

    final color = getColorForProduct(product);

    // Icono según el tipo de producto
    IconData getIconForProduct(String product) {
      final productLower = product.toLowerCase();
      if (productLower.contains('bebida')) return Icons.water_drop;
      if (productLower.contains('enlatado')) return Icons.lunch_dining;
      if (productLower.contains('leche')) return Icons.coffee;
      if (productLower.contains('galleta')) return Icons.cookie;
      if (productLower.contains('cereal')) return Icons.breakfast_dining;
      if (productLower.contains('pasta') || productLower.contains('fideo')) return Icons.ramen_dining;
      if (productLower.contains('condimento')) return Icons.breakfast_dining_sharp;
      return Icons.inventory;
    }

    // Texto de confianza formateado
    final String confidenceText = confidence > 0
        ? ' (${(confidence * 100).toStringAsFixed(0)}%)'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Importante: evitar expansión infinita
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      getIconForProduct(product),
                      size: 16,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        product,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$count unidades$confidenceText',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Stack(
            children: [
              // Barra de fondo
              Container(
                height: 10,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              // Barra de progreso con ancho máximo controlado
              Container( // Usando Container en lugar de AnimatedContainer para reducir complejidad
                height: 10,
                width: maxBarWidth * percentage,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(5),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}