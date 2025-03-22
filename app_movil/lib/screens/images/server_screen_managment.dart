import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../../entities/analisysresult.dart';
import '../../services/images/images_service.dart';

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