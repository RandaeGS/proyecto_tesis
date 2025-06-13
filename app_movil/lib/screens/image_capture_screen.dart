import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path/path.dart' as path;

import '../entities/analisysresult.dart';
import '../inventory/services/inventory_comparison_provider.dart';
import '../inventory/services/inventory_sync_service.dart';
import '../inventory/services/product_data_provider.dart';
import 'reconciliation/services/inventory_reconciliation_service.dart';
import '../services/auth_services/auth_provider.dart';
import '../services/deteccion_services/analysis_provider.dart';
import '../services/deteccion_services/confirmation_dialog.dart';
import '../services/images/images_provider.dart';
import '../services/images/images_service.dart';
import '../utils/reconciliation_dialog.dart';
import '../utils/show_analisys_results.dart';
import 'images/server_screen_managment.dart';
import 'live_camera/live_camera_screen.dart';

class ImageCaptureScreen extends StatefulWidget {
  const ImageCaptureScreen({Key? key}) : super(key: key);

  @override
  State<ImageCaptureScreen> createState() => _ImageCaptureScreenState();
}

/// Diálogo para mostrar el progreso de análisis de la imagen
class AnalysisProgressDialog {
  /// Muestra un diálogo de progreso mientras se analiza la imagen
  static void show(BuildContext context, {String message = 'Analizando imagen...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 24),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Por favor espere mientras se procesa la imagen',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// Cierra el diálogo de progreso
  static void hide(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}

class _ImageCaptureScreenState extends State<ImageCaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  String _errorMessage = '';
  int? _centerId;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);

    try {
      // Obtener el ID del centro del usuario actual
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _centerId = authProvider.centerId;

      if (_centerId == null) {
        throw Exception('No tiene un centro asignado');
      }

      // Cargar imágenes del centro
      await Provider.of<ServerImageProvider>(context, listen: false)
          .loadCenterImages(_centerId!);

      // También cargar datos de productos para tener el inventario actualizado
      await Provider.of<ProductDataProvider>(context, listen: false)
          .loadProductData(_centerId!);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Método modificado para usar AnalysisResultsDialog
  void _showAnalysisResults(AnalysisResult result) {
    // Usamos el método estático de nuestra clase AnalysisResultsDialog
    AnalysisResultsDialog.show(context, result);
  }

  // Captura una nueva imagen
  Future<void> _captureImage(ImageSource source) async {
    if (_centerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tiene un centro asignado'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 90, // Aumentar calidad de la imagen
      );

      if (photo != null) {
        // Mostrar diálogo de progreso
        AnalysisProgressDialog.show(context);

        // Obtener el modelo de detección seleccionado
        final analysisProvider = Provider.of<AnalysisProvider>(context, listen: false);
        final modelType = analysisProvider.selectedModel;

        // Subir y analizar la imagen SIN GUARDAR automáticamente
        final file = File(photo.path);

        // Debug info
        debugPrint('Iniciando análisis de imagen: ${file.path}, tamaño: ${await file.length() ~/ 1024} KB');

        final result = await analysisProvider.analyzeImage(
          file,
          centerId: _centerId,
          saveToServer: false, // No guardar automáticamente
        );

        // Cerrar diálogo de progreso
        if (mounted) {
          AnalysisProgressDialog.hide(context);
        }

        // Verificar si tenemos un resultado para confirmar
        if (mounted && result != null) {
          // Debug info
          debugPrint('Análisis completado: ${result.numeroObjetos} objetos detectados');

          // Mostrar diálogo de confirmación con edición de cantidades
          // MODIFICADO: Ahora esperamos un Map<String, dynamic> que contiene las modificaciones
          final editResult = await ConfirmationDialog.show(context, result);

          if (editResult != null) {
            // Usuario confirmó con posibles modificaciones, mostrar progreso de guardado
            if (mounted) {
              AnalysisProgressDialog.show(context, message: 'Guardando resultados...');
            }

            // Actualizar el análisisProvider con los resultados modificados
            final analysisProvider = Provider.of<AnalysisProvider>(context, listen: false);

            // NUEVO: Proporcionar los resultados modificados al provider
            if (editResult.containsKey('modified_results')) {
              analysisProvider.setModifiedResults(editResult['modified_results']);
            }

            // Confirmar y guardar en el servidor
            await analysisProvider.confirmAnalysis(centerId: _centerId);

            // Recargar imágenes del centro
            final imageProvider = Provider.of<ServerImageProvider>(context, listen: false);
            await imageProvider.loadCenterImages(_centerId!);

            // NUEVO: Actualizar el product data provider con los resultados confirmados
            final productDataProvider = Provider.of<ProductDataProvider>(context, listen: false);
            await productDataProvider.loadProductData(_centerId!);

            // NUEVO: Verificar si hay conflictos con el inventario manual
            await _checkInventoryReconciliation();

            // Cerrar diálogo de progreso
            if (mounted) {
              AnalysisProgressDialog.hide(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Resultados guardados correctamente'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            // Usuario canceló, descartar el resultado
            analysisProvider.cancelPendingAnalysis();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Captura cancelada'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      // Cerrar diálogo de progreso en caso de error
      if (mounted) {
        AnalysisProgressDialog.hide(context);
      }

      debugPrint('Error en captura: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // NUEVO MÉTODO: Comprobar si hay conflictos con el inventario manual
  Future<void> _checkInventoryReconciliation() async {
    if (_centerId == null) return;

    try {
      final imageProvider = Provider.of<ServerImageProvider>(context, listen: false);
      final productDataProvider = Provider.of<ProductDataProvider>(context, listen: false);
      final inventoryProvider = Provider.of<InventoryComparisonProvider>(context, listen: false);

      // Crear el servicio de reconciliación
      final reconciliationService = InventoryReconciliationService(
        imageProvider: imageProvider,
        productDataProvider: productDataProvider,
        inventoryProvider: inventoryProvider,
      );

      // Buscar conflictos
      final conflicts = await reconciliationService.identifyConflicts();

      if (conflicts.isEmpty) {
        debugPrint('No se encontraron conflictos de inventario');
        return;
      }

      debugPrint('Se encontraron ${conflicts.length} conflictos de inventario');

      // Mostrar diálogo de reconciliación
      if (mounted) {
        await ReconciliationDialog.show(
          context,
          conflicts,
          _centerId!,
              (decisions) async {
            // Aplicar las decisiones de reconciliación
            final success = await reconciliationService.reconcileInventory(
              context,
              _centerId!,
              decisions,
            );

            if (success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Inventario reconciliado correctamente'),
                  backgroundColor: Colors.green,
                ),
              );

              // Recargar datos después de la reconciliación
              await _initialize();
            }

            // Registrar las decisiones para auditoría
            for (var decision in decisions) {
              await reconciliationService.logReconciliationDecision(
                _centerId!,
                decision,
              );
            }
          },
        );
      }
    } catch (e) {
      debugPrint('Error en el proceso de reconciliación: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al reconciliar inventario: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // NUEVO MÉTODO: Abre la pantalla de detección en vivo
  void _openLiveDetection() {
    if (_centerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tiene un centro asignado'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pushNamed(
      context,
        '/yolo-launcher'
    ).then((_) {
      // Recargar imágenes al volver
      _initialize();

      // También verificar si hay conflictos con el inventario después de la detección en vivo
      _checkInventoryReconciliation();
    });
  }

  // Muestra opciones para capturar imagen (MODIFICADO)
  void _showImageOptions() {
    final analysisProvider = Provider.of<AnalysisProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Capturar Imagen',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Selector de modelo
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Modelo de detección',
                border: OutlineInputBorder(),
              ),
              value: analysisProvider.selectedModel,
              items: const [
                DropdownMenuItem(value: 'yolo', child: Text('YOLO')),
                DropdownMenuItem(value: 'cl', child: Text('YOLO_2.0')),
                DropdownMenuItem(value: 'rf_detr', child: Text('RF_DETR')),
              ],
              onChanged: (value) {
                if (value != null) {
                  analysisProvider.setSelectedModel(value);
                }
              },
            ),

            const SizedBox(height: 16),

            // NUEVA OPCIÓN: Detección en vivo
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.videocam, color: Colors.orange),
              ),
              title: const Text('Detección en vivo'),
              subtitle: const Text('Analizar objetos en tiempo real'),
              onTap: () {
                Navigator.pop(context);
                _openLiveDetection();
              },
            ),

            const Divider(),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.blue),
              ),
              title: const Text('Tomar foto con la cámara'),
              onTap: () {
                Navigator.pop(context);
                _captureImage(ImageSource.camera);
              },
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.photo_library, color: Colors.green),
              ),
              title: const Text('Seleccionar de la galería'),
              onTap: () {
                Navigator.pop(context);
                _captureImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Ver detalles de una imagen
  void _viewImage(ServerImage image, AnalysisResult? analysisResult) {
    // Intentar obtener el mejor análisis disponible usando el nuevo método
    final imageProvider = Provider.of<ServerImageProvider>(context, listen: false);
    final bestAnalysis = imageProvider.getBestAnalysisForImage(image.id);

    // Si encontramos un mejor análisis, usarlo en lugar del proporcionado
    if (bestAnalysis != null) {
      debugPrint('Usando análisis optimizado con tiempo: ${bestAnalysis.tiempoProcesamiento}');
      analysisResult = bestAnalysis;
    } else if (analysisResult != null) {
      debugPrint('Usando análisis proporcionado con tiempo: ${analysisResult.tiempoProcesamiento}');
    } else {
      debugPrint('No se encontró ningún análisis para la imagen');
    }

    // Navegar a la pantalla de detalles
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServerImageDetailScreen(
          image: image,
          analysisResult: analysisResult,
        ),
      ),
    );
  }

  // Eliminar una imagen
  Future<void> _deleteImage(ServerImage image) async {
    try {
      final success = await Provider.of<ServerImageProvider>(context, listen: false)
          .deleteImage(image.id);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagen eliminada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar imagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Imágenes y Análisis'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _initialize,
            tooltip: 'Recargar imágenes',
          ),
          // Botón para forzar verificación de reconciliación
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _isLoading ? null : _checkInventoryReconciliation,
            tooltip: 'Verificar reconciliación',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _showImageOptions,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? _buildErrorState()
          : Consumer<ServerImageProvider>(
        builder: (context, imageProvider, _) {
          if (imageProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (imageProvider.centerImages.isEmpty) {
            return _buildEmptyState();
          }

          return _buildImageGrid(imageProvider);
        },
      ),
    );
  }

  Widget _buildErrorState() {
    // Obtener el imageProvider desde el contexto
    final imageProvider = Provider.of<ServerImageProvider>(context, listen: false);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'Error al cargar imágenes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _initialize,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.sync),
            label: const Text('Sincronizar con Inventario'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              // Verificar que haya detecciones confirmadas
              if (imageProvider.confirmedCenterDetections.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No hay detecciones confirmadas para sincronizar'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              // Mostrar diálogo de confirmación
              final doSync = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sincronizar con Inventario'),
                  content: const Text(
                      'Esto actualizará el inventario con los productos detectados en las imágenes. '
                          '¿Deseas continuar?'
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                      child: const Text('Sincronizar'),
                    ),
                  ],
                ),
              );

              if (doSync != true) return;

              // Mostrar indicador de carga
              setState(() {
                _isLoading = true;
              });

              try {
                // Obtener el ID del centro
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final centerId = authProvider.centerId;

                if (centerId == null) {
                  throw Exception('No se pudo identificar el centro');
                }

                // Inicializar el servicio de sincronización
                final inventoryProvider = Provider.of<InventoryComparisonProvider>(
                    context,
                    listen: false
                );

                final syncService = InventorySyncService(
                  imageProvider: imageProvider,
                  inventoryProvider: inventoryProvider,
                );

                // Realizar la sincronización
                final success = await syncService.syncInventoryWithImages(centerId);

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Inventario sincronizado correctamente'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  throw Exception('No se pudo sincronizar el inventario');
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                setState(() {
                  _isLoading = false;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay imágenes en este centro',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Presiona el botón de la cámara para capturar una imagen',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildImageGrid(ServerImageProvider imageProvider) {
    final imageService = ImageService();

    return RefreshIndicator(
      onRefresh: _initialize,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: imageProvider.centerImages.length,
        itemBuilder: (context, index) {
          final image = imageProvider.centerImages[index];
          final hasAnalysis = imageProvider.analysisResults.containsKey(image.id);
          final analysisResult = imageProvider.getBestAnalysisForImage(image.id);

          return Card(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              onTap: () => _viewImage(image, analysisResult),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          child: CachedNetworkImage(
                            imageUrl: imageService.getImageUrl(image.file),
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.error,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ),
                        if (image.processed || hasAnalysis)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                path.basename(image.file),
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (hasAnalysis && analysisResult != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Objetos: ${analysisResult.numeroObjetos}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () => _showDeleteConfirmation(image),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showDeleteConfirmation(ServerImage image) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: const Text('¿Está seguro que desea eliminar esta imagen?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteImage(image);
              },
            ),
          ],
        );
      },
    );
  }
}