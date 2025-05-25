import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../services/yolo_detector_service.dart';

class YoloTestScreen extends StatefulWidget {
  @override
  _YoloTestScreenState createState() => _YoloTestScreenState();
}

class _YoloTestScreenState extends State<YoloTestScreen> {
  List<DetectionResult> _detections = [];
  File? _selectedImage;
  bool _isLoading = false;
  String _status = "Listo para detectar";

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera, // Cambia a ImageSource.gallery para galería
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _detections = [];
          _status = "Imagen seleccionada";
        });
      }
    } catch (e) {
      setState(() {
        _status = "Error al seleccionar imagen: $e";
      });
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _detections = [];
          _status = "Imagen seleccionada de la galería";
        });
      }
    } catch (e) {
      setState(() {
        _status = "Error al seleccionar imagen: $e";
      });
    }
  }

  Future<void> _detectObjects() async {
    if (_selectedImage == null) {
      setState(() {
        _status = "Selecciona una imagen primero";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _status = "Detectando objetos...";
    });

    try {
      // Leer imagen como bytes
      final Uint8List imageBytes = await _selectedImage!.readAsBytes();

      // Llamar al detector nativo
      final List<DetectionResult> results = await YoloDetectorService.detectObjects(imageBytes);

      setState(() {
        _detections = results;
        _status = "Detectados ${results.length} objetos";
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _status = "Error en detección: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('YOLOv8 Detector'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Estado
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _status,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),

            SizedBox(height: 16),

            // Botones
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: Icon(Icons.camera_alt),
                    label: Text('Cámara'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickFromGallery,
                    icon: Icon(Icons.photo_library),
                    label: Text('Galería'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _detectObjects,
                    icon: _isLoading
                        ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                    )
                        : Icon(Icons.search),
                    label: Text('Detectar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Imagen seleccionada
            if (_selectedImage != null)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _selectedImage!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),

            SizedBox(height: 16),

            // Resultados
            Text(
              'Detecciones encontradas:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            SizedBox(height: 8),

            Expanded(
              child: _detections.isEmpty
                  ? Center(
                child: Text(
                  'No hay detecciones',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
                  : ListView.builder(
                itemCount: _detections.length,
                itemBuilder: (context, index) {
                  final detection = _detections[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text('${index + 1}'),
                      ),
                      title: Text(detection.className),
                      subtitle: Text(
                        'Confianza: ${(detection.confidence * 100).toStringAsFixed(1)}%',
                      ),
                      trailing: Text(
                        'Pos: (${detection.x1.toStringAsFixed(2)}, ${detection.y1.toStringAsFixed(2)})',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}