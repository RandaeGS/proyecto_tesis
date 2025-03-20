import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path/path.dart' as path;

import '../entities/analisysresult.dart';
import '../services/auth_services/auth_provider.dart';
import '../services/deteccion_services/analysis_provider.dart';
import '../services/images/images_provider.dart';
import '../services/images/images_service.dart';

class ImageCaptureScreen extends StatefulWidget {
  const ImageCaptureScreen({Key? key}) : super(key: key);

  @override
  State<ImageCaptureScreen> createState() => _ImageCaptureScreenState();
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

  // Muestra el resultado del análisis
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
        imageQuality: 80,
      );

      if (photo != null) {
        setState(() => _isLoading = true);

        // Obtener el modelo de detección seleccionado
        final analysisProvider = Provider.of<AnalysisProvider>(context, listen: false);
        final modelType = analysisProvider.selectedModel;

        // Subir y analizar la imagen
        final file = File(photo.path);
        final result = await analysisProvider.analyzeImage(
          file,
          centerId: _centerId,
        );

        // Recargar imágenes del centro después de analizar
        await Provider.of<ServerImageProvider>(context, listen: false)
            .loadCenterImages(_centerId!);

        setState(() => _isLoading = false);

        // Mostrar los resultados
        if (mounted && result != null) {
          _showAnalysisResults(result);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Muestra opciones para capturar imagen
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

  // Ver detalles de una imagen
  void _viewImage(ServerImage image, AnalysisResult? analysisResult) {
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
          final analysisResult = imageProvider.analysisResults[image.id];

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

class ServerImageDetailScreen extends StatelessWidget {
  final ServerImage image;
  final AnalysisResult? analysisResult;
  final ImageService _imageService = ImageService();

  ServerImageDetailScreen({
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
        title: Text(path.basename(image.file)),
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
              child: CachedNetworkImage(
                imageUrl: _imageService.getImageUrl(image.file),
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(),
                ),
                errorWidget: (context, url, error) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error al cargar la imagen: $error',
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
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