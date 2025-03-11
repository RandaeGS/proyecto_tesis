import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';

import '../entities/analisysresult.dart';
import '../services/auth_services/auth_provider.dart';
import '../services/deteccion_services/analysis_provider.dart';

class ImageCaptureScreen extends StatefulWidget {
  const ImageCaptureScreen({Key? key}) : super(key: key);

  @override
  State<ImageCaptureScreen> createState() => _ImageCaptureScreenState();
}

class _ImageCaptureScreenState extends State<ImageCaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  List<File> _capturedImages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedImages();
    _loadAnalysisResults();
  }

  // Cargar análisis guardados
  Future<void> _loadAnalysisResults() async {
    try {
      await Provider.of<AnalysisProvider>(context, listen: false).loadAnalysisResults();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar análisis guardados: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadSavedImages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final directory = await getApplicationDocumentsDirectory();
      final imageDir = Directory('${directory.path}/captured_images');

      if (await imageDir.exists()) {
        final files = await imageDir.list().toList();
        final imageFiles = files
            .whereType<File>()
            .where((file) =>
            ['.jpg', '.jpeg', '.png'].contains(path.extension(file.path).toLowerCase()))
            .toList();

        setState(() {
          _capturedImages = imageFiles;
        });
      } else {
        // Crear el directorio si no existe
        await imageDir.create(recursive: true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar imágenes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _captureImage(ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (photo != null) {
        // Guardar la imagen en el directorio de la aplicación
        final directory = await getApplicationDocumentsDirectory();
        final imageDir = Directory('${directory.path}/captured_images');

        if (!await imageDir.exists()) {
          await imageDir.create(recursive: true);
        }

        final filename = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImage = File('${imageDir.path}/$filename');

        await savedImage.writeAsBytes(await photo.readAsBytes());

        // Actualizar la UI con la nueva imagen
        setState(() {
          _capturedImages.add(savedImage);
          _isLoading = true; // Activar indicador de carga
        });

        // Obtener el ID del centro actual
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final centerId = authProvider.centerId;

        // Analizar la imagen
        try {
          final analysisProvider = Provider.of<AnalysisProvider>(context, listen: false);
          final result = await analysisProvider.analyzeImage(
            savedImage,
            centerId: centerId,
          );

          setState(() {
            _isLoading = false;
          });

          // Mostrar el resultado del análisis
          if (mounted && result != null) {
            _showAnalysisResults(result);
          }
        } catch (e) {
          setState(() {
            _isLoading = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al analizar imagen: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al capturar imagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteImage(File image) async {
    try {
      await image.delete();

      // También eliminar del almacenamiento
      await Provider.of<AnalysisProvider>(context, listen: false).removeAnalysisResult(image.path);

      setState(() {
        _capturedImages.remove(image);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Imagen eliminada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar imagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAnalysisResults(AnalysisResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resultados del Análisis'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildResultRow('ID', result.id),
              _buildResultRow('Fecha', result.fechaCreacion),
              _buildResultRow('Modelo', result.tipoModelo),
              _buildResultRow('Objetos detectados', result.numeroObjetos.toString()),
              _buildResultRow('Tiempo de procesamiento', '${result.tiempoProcesamiento.toStringAsFixed(2)} s'),
              const Divider(),
              const Text('Resultados:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(result.resultados),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

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
                DropdownMenuItem(value: 'mask_rcnn', child: Text('Mask R-CNN')),
                DropdownMenuItem(value: 'ssd', child: Text('SSD')),
              ],
              onChanged: (value) {
                if (value != null) {
                  analysisProvider.setSelectedModel(value);
                }
              },
            ),

            const SizedBox(height: 16),
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

  void _viewImage(File image) {
    final analysisProvider = Provider.of<AnalysisProvider>(context, listen: false);
    final analysisResult = analysisProvider.analysisResults[image.path];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageDetailScreen(
          image: image,
          analysisResult: analysisResult,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Imágenes y Análisis'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showImageOptions,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _capturedImages.isEmpty
          ? _buildEmptyState()
          : _buildImageGrid(),
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
            'No hay imágenes capturadas',
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

  Widget _buildImageGrid() {
    final analysisProvider = Provider.of<AnalysisProvider>(context);

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: _capturedImages.length,
      itemBuilder: (context, index) {
        final image = _capturedImages[index];
        final hasAnalysis = analysisProvider.analysisResults.containsKey(image.path);

        return _buildImageCard(image, hasAnalysis);
      },
    );
  }

  Widget _buildImageCard(File image, bool hasAnalysis) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _viewImage(image),
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
                    child: Image.file(
                      image,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (hasAnalysis)
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
                          path.basename(image.path),
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasAnalysis) ...[
                          const SizedBox(height: 2),
                          Consumer<AnalysisProvider>(
                            builder: (context, provider, _) {
                              final result = provider.analysisResults[image.path];
                              return Text(
                                'Objetos: ${result?.numeroObjetos ?? 0}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
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
  }

  Future<void> _showDeleteConfirmation(File image) async {
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

class ImageDetailScreen extends StatelessWidget {
  final File image;
  final AnalysisResult? analysisResult;

  const ImageDetailScreen({
    Key? key,
    required this.image,
    this.analysisResult,
  }) : super(key: key);

  void _showAnalysisDetails(BuildContext context) {
    if (analysisResult == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detalles del análisis'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('ID', analysisResult!.id),
              _buildDetailRow('Fecha', analysisResult!.fechaCreacion),
              _buildDetailRow('Modelo', analysisResult!.modeloUsado.isNotEmpty
                  ? analysisResult!.modeloUsado
                  : analysisResult!.tipoModelo),
              _buildDetailRow('Objetos detectados', analysisResult!.numeroObjetos.toString()),
              _buildDetailRow('Tiempo', '${analysisResult!.tiempoProcesamiento.toStringAsFixed(2)} s'),

              if (analysisResult!.detecciones.isNotEmpty) ...[
                const Divider(),
                const Text('Objetos detectados:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),

                // Lista de objetos detectados
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: analysisResult!.detecciones.length,
                  itemBuilder: (context, index) {
                    final detection = analysisResult!.detecciones[index];
                    final className = detection['class'] ?? 'Desconocido';
                    final confidence = detection['confidence'] ?? 0.0;
                    final formattedConfidence = (confidence * 100).toStringAsFixed(1);

                    // Extraer información de bbox si existe
                    String bboxInfo = '';
                    if (detection.containsKey('bbox')) {
                      final bbox = detection['bbox'];
                      bboxInfo = 'Posición: (${bbox['x1'].toStringAsFixed(0)}, '
                          '${bbox['y1'].toStringAsFixed(0)}) - '
                          '(${bbox['x2'].toStringAsFixed(0)}, '
                          '${bbox['y2'].toStringAsFixed(0)})';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Objeto ${index + 1}: $className',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('Confianza: $formattedConfidence%'),
                            if (bboxInfo.isNotEmpty) Text(bboxInfo),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],

              const Divider(),
              const Text('Respuesta completa:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  analysisResult!.resultados,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(path.basename(image.path)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (analysisResult != null)
            IconButton(
              icon: const Icon(Icons.data_usage),
              onPressed: () => _showAnalysisDetails(context),
              tooltip: 'Ver resultados del análisis',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: Image.file(
                image,
                fit: BoxFit.contain,
              ),
            ),
          ),

          // Mostrar resumen de resultados si hay análisis
          if (analysisResult != null)
            Container(
              width: double.infinity,
              color: Colors.black.withOpacity(0.8),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Análisis con ${analysisResult!.tipoModelo.toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStatItem(
                          'Objetos',
                          analysisResult!.numeroObjetos.toString(),
                          Icons.policy
                      ),
                      _buildStatItem(
                          'Tiempo',
                          '${analysisResult!.tiempoProcesamiento.toStringAsFixed(2)}s',
                          Icons.timer
                      ),
                      TextButton.icon(
                        onPressed: () => _showAnalysisDetails(context),
                        icon: const Icon(Icons.info_outline, color: Colors.blue),
                        label: const Text('Detalles', style: TextStyle(color: Colors.blue)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}