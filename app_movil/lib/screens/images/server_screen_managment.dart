import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'dart:developer' as developer;

import '../../entities/analisysresult.dart';
import '../../services/images/images_service.dart';
import '../../utils/show_analisys_results.dart';

class ServerImageDetailScreen extends StatelessWidget {
  final ServerImage image;
  final AnalysisResult? analysisResult;
  final ImageService _imageService = ImageService();


  ServerImageDetailScreen({
    super.key,
    required this.image,
    this.analysisResult,
  }) {
    // Registrar información sobre el análisis para depuración

    if (analysisResult != null) {
      developer.log('Análisis cargado para la imagen: ${image.file}', name: 'ServerImageDetailScreen');
      developer.log('Tipo de modelo: ${analysisResult!.tipoModelo}', name: 'ServerImageDetailScreen');
      developer.log('Número de objetos: ${analysisResult!.numeroObjetos}', name: 'ServerImageDetailScreen');
      developer.log('Tiempo de procesamiento: ${analysisResult!.tiempoProcesamiento}s', name: 'ServerImageDetailScreen');
      developer.log('Detecciones disponibles: ${analysisResult!.detecciones.length}', name: 'ServerImageDetailScreen');
    } else {
      developer.log('No hay análisis para la imagen: ${image.file}', name: 'ServerImageDetailScreen');
    }
  }

  void _showAnalysisDetails(BuildContext context) {
    if (analysisResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay análisis disponible para esta imagen')),
      );
      return;
    }
    AnalysisResultsDialog.show(context, analysisResult!);
  }

  @override
  Widget build(BuildContext context) {

    // Preparar datos del análisis para mostrar en la interfaz
    final bool hasAnalysis = analysisResult != null;
    final String modelName = hasAnalysis ? (analysisResult!.tipoModelo.toUpperCase()) : '';
    final int objectCount = hasAnalysis ? analysisResult!.numeroObjetos : 0;
    final double processingTime = hasAnalysis ? analysisResult!.tiempoProcesamiento : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(path.basename(image.file)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (hasAnalysis)
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
          if (hasAnalysis)
            Container(
              width: double.infinity,
              color: Colors.black.withOpacity(0.8),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Análisis con $modelName',
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
                          objectCount.toString(),
                          Icons.policy
                      ),
                      _buildStatItem(
                          'Tiempo',
                          '${processingTime.toStringAsFixed(1)}s',
                          Icons.timer
                      ),
                      GestureDetector(
                        onTap: () => _showAnalysisDetails(context),
                        child: TextButton.icon(
                          onPressed: () => _showAnalysisDetails(context),
                          icon: const Icon(Icons.info_outline, color: Colors.blue),
                          label: const Text('Detalles', style: TextStyle(color: Colors.blue)),
                        ),
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