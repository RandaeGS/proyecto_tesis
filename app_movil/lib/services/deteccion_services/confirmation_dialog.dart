import 'package:flutter/material.dart';
import '../../entities/analisysresult.dart';
import 'dart:developer' as developer;

/// Diálogo para confirmar los resultados del análisis con capacidad de edición
class ConfirmationDialog {
  /// Traduce el nombre de un producto a un formato legible
  static String _translateProductName(String rawName) {
    // Limpiamos el nombre antes de la traducción
    final cleanName = rawName.trim().toLowerCase();

    // Mapa de traducciones
    final translations = {
      'beverage': 'Bebidas',
      'canned_food': 'Enlatados',
      'canned': 'Enlatados',
      'condiments': 'Condimentos',
      'dairy': 'Lácteos',
      'crackers': 'Galletas',
      'crackers_cookies': 'Galletas',
      'cereal': 'Cereales',
      'pasta_noodles': 'Pastas',
      'pasta': 'Pastas',
      'noodles': 'Fideos',
      'agua': 'Bebidas',
      'leche': 'Lácteos',
      'galletas': 'Galletas',
      'pasta': 'Pastas',
      'fideos': 'Fideos',
      'cereales': 'Cereales',
      'galleta': 'Galletas',
      'enlatado': 'Enlatados',
      'enlatados': 'Enlatados',
      'latas': 'Enlatados',
      'conservas': 'Enlatados',
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

    return 'Otro';
  }

  /// Obtiene el nombre original de clase a partir del nombre traducido
  static String _getOriginalClassName(String translatedName,
      Map<String, List<Map<String, dynamic>>> groupedDetections) {
    // Si tenemos detecciones para esta categoría, usamos el nombre de clase original
    // de la primera detección
    if (groupedDetections.containsKey(translatedName) &&
        groupedDetections[translatedName]!.isNotEmpty) {
      return groupedDetections[translatedName]![0]['class'] ?? translatedName;
    }

    // Si no tenemos detecciones originales, tratamos de hacer una traducción inversa
    final reverseTranslations = {
      'Bebidas': 'beverage',
      'Enlatados': 'canned_food',
      'Alimentos Enlatados': 'canned_food',
      'Lácteos': 'dairy',
      'Galletas': 'crackers_cookies',
      'Cereales': 'cereal',
      'Pastas': 'pasta_noodles',
      'Fideos': 'pasta_noodles',
      'Condimentos': 'condiments',
      // resto de traducciones inversas...
    };

    return reverseTranslations[translatedName] ?? translatedName;
  }

  /// Muestra un diálogo para confirmar o rechazar los resultados del análisis
  /// Ahora permite editar la cantidad de productos y guarda correctamente las modificaciones
  static Future<Map<String, dynamic>?> show(BuildContext context,
      AnalysisResult result) {
    // Procesar y agrupar las detecciones por tipo de producto
    final Map<String, List<Map<String, dynamic>>> groupedDetections = {};
    final Map<String, int> productCounts = {};
    final Map<String, int> editedCounts = {
    }; // Para guardar las cantidades editadas

    // Rastrear detecciones originales para mantener sus propiedades
    final List<Map<String, dynamic>> originalDetections = List.from(
        result.detecciones);

    for (var detection in originalDetections) {
      final className = detection['class'] ?? 'unknown';
      final translatedName = _translateProductName(className);

      if (!groupedDetections.containsKey(translatedName)) {
        groupedDetections[translatedName] = [];
      }

      groupedDetections[translatedName]!.add(detection);
      productCounts[translatedName] = (productCounts[translatedName] ?? 0) + 1;
      // Inicializar conteo editable con los valores originales
      editedCounts[translatedName] = (editedCounts[translatedName] ?? 0) + 1;
    }

    // Obtener las categorías ordenadas por cantidad
    final categories = productCounts.keys.toList()
      ..sort((a, b) => productCounts[b]!.compareTo(productCounts[a]!));

    // Formatear la fecha en un formato más amigable
    String formattedDate = result.fechaCreacion;
    try {
      final dateTime = DateTime.parse(result.fechaCreacion);
      formattedDate =
      '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime
          .hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      developer.log('Error al parsear fecha: $e', name: 'ConfirmationDialog');
    }

    // Variable para el recuento total editable
    int totalEditedCount = result.detecciones.length;

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        // Obtener el tamaño de la pantalla para hacer el diálogo responsive
        final screenSize = MediaQuery
            .of(context)
            .size;
        final isSmallScreen = screenSize.width < 360;

        // Estado para manejar los conteos editados
        return StatefulBuilder(
          builder: (context, setState) {
            // Funciones para incrementar/decrementar contadores
            void incrementCount(String category) {
              setState(() {
                editedCounts[category] = (editedCounts[category] ?? 0) + 1;
                totalEditedCount++;
              });
            }

            void decrementCount(String category) {
              if ((editedCounts[category] ?? 0) > 0) {
                setState(() {
                  editedCounts[category] = (editedCounts[category] ?? 0) - 1;
                  totalEditedCount--;
                });
              }
            }

            // Funciones de color e icono
            Color getColorForProduct(String product) {
              final productLower = product.toLowerCase();
              if (productLower.contains('bebida')) return Colors.blue;
              if (productLower.contains('enlatado')) return Colors.orange;
              if (productLower.contains('lácteo')) return Colors.cyan;
              if (productLower.contains('galleta')) return Colors.amber;
              if (productLower.contains('cereal')) return Colors.brown;
              if (productLower.contains('pasta') ||
                  productLower.contains('fideo')) return Colors.yellow.shade800;
              if (productLower.contains('condimento')) return Colors.red;
              return Colors.purple;
            }

            IconData getIconForProduct(String product) {
              final productLower = product.toLowerCase();
              if (productLower.contains('bebida')) return Icons.water_drop;
              if (productLower.contains('enlatado')) return Icons.lunch_dining;
              if (productLower.contains('lácteo')) return Icons.coffee;
              if (productLower.contains('galleta')) return Icons.cookie;
              if (productLower.contains('cereal'))
                return Icons.breakfast_dining;
              if (productLower.contains('pasta') ||
                  productLower.contains('fideo')) return Icons.ramen_dining;
              if (productLower.contains('condimento')) return Icons.kitchen;
              return Icons.inventory;
            }

            // Función para confirmar y enviar los cambios
            void confirmWithEdits() {
              // Crear nuevas detecciones basadas en conteos editados
              List<Map<String, dynamic>> newDetections = [];

              for (var category in editedCounts.keys) {
                final count = editedCounts[category] ?? 0;
                if (count > 0) {
                  // Buscar todas las detecciones originales de esta categoría
                  final originals = groupedDetections[category] ?? [];

                  // Obtener el nombre de clase original para esta categoría
                  final originalClassName = _getOriginalClassName(
                      category, groupedDetections);

                  // Si hay detecciones originales, usamos sus propiedades
                  if (originals.isNotEmpty) {
                    // Añadir tantas detecciones como indique el contador editado
                    for (int i = 0; i < count; i++) {
                      // Si hay suficientes originales, usar sus propiedades
                      // Si no, clonar la primera detección
                      Map<String, dynamic> detection;
                      if (i < originals.length) {
                        detection = Map<String, dynamic>.from(originals[i]);
                      } else {
                        detection = Map<String, dynamic>.from(originals[0]);
                        // Generar un bbox diferente para no tener objetos exactamente superpuestos
                        if (detection.containsKey('bbox')) {
                          var bbox = Map<String, dynamic>.from(
                              detection['bbox']);
                          // Ligero desplazamiento para no superponer completamente
                          bbox['x1'] = (bbox['x1'] as double) + (i -
                              originals.length + 1) * 5;
                          bbox['y1'] = (bbox['y1'] as double) + (i -
                              originals.length + 1) * 5;
                          bbox['x2'] = (bbox['x2'] as double) + (i -
                              originals.length + 1) * 5;
                          bbox['y2'] = (bbox['y2'] as double) + (i -
                              originals.length + 1) * 5;
                          detection['bbox'] = bbox;
                        }
                      }
                      newDetections.add(detection);
                    }
                  } else {
                    // Si no hay originales pero el usuario añadió de esta categoría,
                    // crear una detección básica
                    for (int i = 0; i < count; i++) {
                      final detection = {
                        'class': originalClassName,
                        'confidence': 0.7, // Confianza por defecto
                        'bbox': {
                          'x1': 100.0 + (i * 20),
                          'y1': 100.0 + (i * 20),
                          'x2': 200.0 + (i * 20),
                          'y2': 200.0 + (i * 20),
                        }
                      };
                      newDetections.add(detection);
                    }
                  }
                }
              }

              // Crear una copia de los resultados con las nuevas detecciones
              Map<String, dynamic> modifiedResults = {
                'detections': newDetections,
                'count': newDetections.length,
              };

              // También añadiremos la distribución de categorías actualizada
              Map<String, int> categoryDistribution = {};

              for (var detection in newDetections) {
                final category = detection['class'] as String? ?? 'unknown';
                categoryDistribution[category] =
                    (categoryDistribution[category] ?? 0) + 1;
              }

              modifiedResults['category_distribution'] = categoryDistribution;

              // Encontrar la categoría predominante
              String? predominantCategory;
              int maxCount = 0;
              categoryDistribution.forEach((category, count) {
                if (count > maxCount) {
                  maxCount = count;
                  predominantCategory = category;
                }
              });

              modifiedResults['predominant_category'] = predominantCategory;

              // Añadir información adicional del resultado original
              // para mantener compatibilidad
              modifiedResults['model_type'] = result.modeloUsado;
              modifiedResults['model_path'] = result.tipoModelo;

              // Devolver los resultados modificados para que sean procesados por el llamador
              Navigator.of(context).pop({
                'modified_detections': newDetections,
                'modified_results': modifiedResults
              });
            }

            // Función para cancelar (corregida)
            void cancelDialog() {
              Navigator.of(context).pop(null);
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 5,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery
                      .of(context)
                      .size
                      .height * 0.8,
                  maxWidth: MediaQuery
                      .of(context)
                      .size
                      .width * 0.95,
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
                              child: Icon(
                                  Icons.inventory_2, color: Colors.blue),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Confirmar Resultados',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isSmallScreen ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Contenido principal
                      Padding(
                        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Mensaje principal con instrucción de edición
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
                                      Icon(Icons.edit,
                                          color: Colors.blue.shade700,
                                          size: isSmallScreen ? 16 : 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Edite las cantidades',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: isSmallScreen ? 14 : 15,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (!isSmallScreen) const SizedBox(height: 4),
                                  Padding(
                                    padding: EdgeInsets.only(
                                        left: isSmallScreen ? 0 : 26),
                                    child: Text(
                                      'Use + y - para ajustar productos',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 12 : 13,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Tarjetas de información
                            Row(
                              children: [
                                _buildInfoCard(
                                  icon: Icons.inventory_2,
                                  title: 'Total',
                                  value: '$totalEditedCount',
                                  color: Colors.green,
                                  isSmallScreen: isSmallScreen,
                                ),
                                const SizedBox(width: 8),
                                _buildInfoCard(
                                  icon: Icons.timer,
                                  title: 'Tiempo',
                                  value: '${result.tiempoProcesamiento
                                      .toStringAsFixed(1)}s',
                                  color: Colors.orange,
                                  isSmallScreen: isSmallScreen,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Productos detectados con edición
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Productos',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 15 : 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (!isSmallScreen)
                                  Text(
                                    'Edite cantidades',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Detalles técnicos en un panel expandible
                            ExpansionTile(
                              title: Text(
                                'Detalles técnicos',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 13 : 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              initiallyExpanded: false,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: Column(
                                    children: [
                                      _buildTechnicalDetail(
                                        'ID:',
                                        result.id,
                                        Icons.fingerprint,
                                        isSmallScreen: isSmallScreen,
                                      ),
                                      _buildTechnicalDetail(
                                        'Fecha:',
                                        formattedDate,
                                        Icons.calendar_today,
                                        isSmallScreen: isSmallScreen,
                                      ),
                                      _buildTechnicalDetail(
                                        'Modelo:',
                                        result.tipoModelo,
                                        Icons.model_training,
                                        isSmallScreen: isSmallScreen,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Mostrar productos agrupados por categoría con controles de edición
                            ...categories.map((category) {
                              final items = groupedDetections[category] ?? [];
                              final originalCount = productCounts[category] ??
                                  0;
                              final count = editedCounts[category] ?? 0;
                              final color = getColorForProduct(category);
                              final icon = getIconForProduct(category);
                              final hasBeenModified = count != originalCount;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 2,
                                child: Padding(
                                  padding: EdgeInsets.all(
                                      isSmallScreen ? 8.0 : 12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment
                                        .start,
                                    children: [
                                      // Layout adaptativo para productos
                                      if (isSmallScreen)
                                      // Layout para pantallas pequeñas - apilado verticalmente
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment
                                              .start,
                                          children: [
                                            // Información del producto
                                            Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 16,
                                                  backgroundColor: color
                                                      .withOpacity(0.2),
                                                  child: Icon(
                                                      icon, color: color,
                                                      size: 16),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment
                                                        .start,
                                                    children: [
                                                      Text(
                                                        category,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight
                                                              .bold,
                                                          fontSize: 14,
                                                        ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      if (hasBeenModified)
                                                        Text(
                                                          'Original: $originalCount',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color: Colors.grey
                                                                .shade600,
                                                            fontStyle: FontStyle
                                                                .italic,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            // Controles de edición centrados
                                            Center(
                                              child: _buildCompactCountControls(
                                                category,
                                                count,
                                                hasBeenModified,
                                                decrementCount,
                                                incrementCount,
                                                isSmallScreen: true,
                                              ),
                                            ),
                                          ],
                                        )
                                      else
                                      // Layout para pantallas normales - horizontal
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              backgroundColor: color
                                                  .withOpacity(0.2),
                                              child: Icon(
                                                  icon, color: color, size: 20),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment
                                                    .start,
                                                children: [
                                                  Text(
                                                    category,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight
                                                          .bold,
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  if (hasBeenModified)
                                                    Text(
                                                      'Original: $originalCount',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey
                                                            .shade600,
                                                        fontStyle: FontStyle
                                                            .italic,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),

                                            // Controles de edición de cantidad compactos
                                            _buildCompactCountControls(
                                              category,
                                              count,
                                              hasBeenModified,
                                              decrementCount,
                                              incrementCount,
                                            ),
                                          ],
                                        ),

                                      // Solo mostrar detalles si hay elementos
                                      if (count > 0) ...[
                                        const SizedBox(height: 8),
                                        const Divider(height: 1),
                                        const SizedBox(height: 4),
                                        if (!isSmallScreen)
                                          Text(
                                            'Detalles:',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        if (items.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 4, top: 4),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.check_circle,
                                                  color: color,
                                                  size: isSmallScreen ? 14 : 16,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    'Confianza: ${_calculateAverageConfidence(
                                                        items)}%',
                                                    style: TextStyle(
                                                        fontSize: isSmallScreen
                                                            ? 12
                                                            : 14),
                                                    overflow: TextOverflow
                                                        .ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),

                            // Pie del diálogo con acciones
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 16,
                                  horizontal: isSmallScreen ? 8 : 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  // Botón CANCELAR CORREGIDO
                                  OutlinedButton.icon(
                                    icon: Icon(Icons.close,
                                        size: isSmallScreen ? 16 : 20),
                                    label: Text('Cancelar', style: TextStyle(
                                        fontSize: isSmallScreen ? 12 : 14)),
                                    onPressed: cancelDialog,
                                    // Usar la función correcta
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isSmallScreen ? 8 : 12,
                                        vertical: isSmallScreen ? 8 : 10,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: isSmallScreen ? 6 : 8),
                                  ElevatedButton.icon(
                                    icon: Icon(Icons.check,
                                        size: isSmallScreen ? 16 : 20),
                                    label: Text('Guardar', style: TextStyle(
                                        fontSize: isSmallScreen ? 12 : 14)),
                                    onPressed: confirmWithEdits,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isSmallScreen ? 8 : 12,
                                        vertical: isSmallScreen ? 8 : 10,
                                      ),
                                    ),
                                  ),
                                ],
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
      },
    );
  }

  // Widget para los controles de conteo COMPACTOS
  static Widget _buildCompactCountControls(String category,
      int count,
      bool hasBeenModified,
      Function(String) decrementCount,
      Function(String) incrementCount,
      {bool isSmallScreen = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botón para disminuir (tamaño reducido)
        Container(
          height: isSmallScreen ? 22 : 26,
          width: isSmallScreen ? 22 : 26,
          decoration: BoxDecoration(
            color: count > 0
                ? Colors.red.shade100
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: count > 0 ? () => decrementCount(category) : null,
              borderRadius: BorderRadius.circular(4),
              child: Center(
                child: Icon(
                  Icons.remove,
                  color: count > 0 ? Colors.red : Colors.grey,
                  size: isSmallScreen ? 14 : 16,
                ),
              ),
            ),
          ),
        ),

        // Mostrar cantidad actual (tamaño reducido)
        Container(
          height: isSmallScreen ? 22 : 26,
          width: isSmallScreen ? 26 : 32,
          margin: EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: hasBeenModified
                ? Colors.yellow.shade100
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: hasBeenModified
                  ? Colors.orange
                  : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              count.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 12 : 14,
                color: hasBeenModified
                    ? Colors.orange.shade800
                    : Colors.black,
              ),
            ),
          ),
        ),

        // Botón para aumentar (tamaño reducido)
        Container(
          height: isSmallScreen ? 22 : 26,
          width: isSmallScreen ? 22 : 26,
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => incrementCount(category),
              borderRadius: BorderRadius.circular(4),
              child: Center(
                child: Icon(
                  Icons.add,
                  color: Colors.green,
                  size: isSmallScreen ? 14 : 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Calcula el promedio de confianza para una lista de detecciones
  static String _calculateAverageConfidence(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return "0.0";

    double sum = 0;
    for (var item in items) {
      sum += (item['confidence'] ?? 0.0) * 100;
    }
    return (sum / items.length).toStringAsFixed(1);
  }

  // Tarjeta de información con altura fija
  static Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    bool isSmallScreen = false,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
        height: isSmallScreen ? 60 : 70, // Altura adaptativa reducida
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: isSmallScreen ? 14 : 16, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11 : 12,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Detalles técnicos con icono
  static Widget _buildTechnicalDetail(String label,
      String value,
      IconData icon,
      {bool isSmallScreen = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: isSmallScreen ? 14 : 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          // Usar un ancho limitado para el label
          SizedBox(
            width: isSmallScreen ? 40 : 50,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isSmallScreen ? 11 : 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: isSmallScreen ? 11 : 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}