import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:provider/provider.dart';

import '../../entities/analisysresult.dart';
import '../../services/auth_services/auth_provider.dart';
import '../../services/deteccion_services/analysis_provider.dart';
import '../../services/images/images_provider.dart';
import '../../utils/show_analisys_results.dart';
import 'object_pintaint_detection.dart';

class LiveCameraDetectionScreen extends StatefulWidget {
  const LiveCameraDetectionScreen({Key? key}) : super(key: key);

  @override
  State<LiveCameraDetectionScreen> createState() => _LiveCameraDetectionScreenState();
}

class _LiveCameraDetectionScreenState extends State<LiveCameraDetectionScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isSaving = false;
  int _selectedCameraIndex = 0;

  // ML Kit Object Detection
  late ObjectDetector _objectDetector;
  List<DetectedObject> _detectedObjects = [];

  // Centro actual
  int? _centerId;
  String _selectedModel = 'yolo'; // Modelo por defecto

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _initDetector();
    _loadCenterId();
  }

  Future<void> _loadCenterId() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _centerId = authProvider.centerId;
      if (_centerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No hay centro asignado. Algunas funciones pueden no estar disponibles.'))
        );
      }
    });

    // Obtener el modelo seleccionado
    final analysisProvider = Provider.of<AnalysisProvider>(context, listen: false);
    setState(() {
      _selectedModel = analysisProvider.selectedModel;
    });
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se encontraron cámaras disponibles'))
        );
        return;
      }

      await _setupCamera(_cameras![_selectedCameraIndex]);
    } catch (e) {
      debugPrint('Error al inicializar la cámara: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al inicializar la cámara: $e'))
      );
    }
  }

  Future<void> _setupCamera(CameraDescription cameraDescription) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    // Inicializar controlador con resolución media para mejor rendimiento
    _cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _cameraController!.initialize();

      // Iniciar stream de imágenes
      await _cameraController!.startImageStream(_processCameraImage);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error al configurar la cámara: $e');
    }
  }

  Future<void> _initDetector() async {
    // Usar modelo por defecto de ML Kit para demostración
    final options = ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: true,
    );
    _objectDetector = ObjectDetector(options: options);
  }

  InputImageRotation _getInputImageRotation(int sensorOrientation) {
    // Normalizar la orientación a 0, 90, 180, 270
    final rotationDegrees = sensorOrientation % 360;

    switch (rotationDegrees) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
      // Si no es uno de los valores exactos, aproximamos al más cercano
        if (rotationDegrees > 315 || rotationDegrees <= 45) {
          return InputImageRotation.rotation0deg;
        } else if (rotationDegrees > 45 && rotationDegrees <= 135) {
          return InputImageRotation.rotation90deg;
        } else if (rotationDegrees > 135 && rotationDegrees <= 225) {
          return InputImageRotation.rotation180deg;
        } else {
          return InputImageRotation.rotation270deg;
        }
    }
  }

  void _processCameraImage(CameraImage cameraImage) async {
    if (_isProcessing) return;

    _isProcessing = true;
    try {
      final camera = _cameras![_selectedCameraIndex];

      // Usar el método WriteBuffer para concatenar los planos
      final WriteBuffer allBytes = WriteBuffer();
      for (Plane plane in cameraImage.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      // Crear un InputImage con la nueva estructura de metadatos
      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
          rotation: _getInputImageRotation(camera.sensorOrientation),
          format: InputImageFormat.values[cameraImage.format.raw],
          bytesPerRow: cameraImage.planes.first.bytesPerRow,
        ),
      );

      final objects = await _objectDetector.processImage(inputImage);

      if (mounted) {
        setState(() {
          _detectedObjects = objects;
        });
      }
    } catch (e) {
      debugPrint('Error al procesar imagen: $e');
    } finally {
      _isProcessing = false;
    }
  }

// Añade este método auxiliar
  Uint8List _concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  Future<void> _captureAndAnalyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cámara no disponible'))
      );
      return;
    }

    if (_centerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay centro asignado. No se puede guardar.'))
      );
      return;
    }

    // Detener stream para capturar imagen de calidad
    try {
      setState(() {
        _isSaving = true;
      });

      await _cameraController!.stopImageStream();

      // Pequeña pausa para estabilizar la imagen
      await Future.delayed(const Duration(milliseconds: 500));

      // Capturar imagen
      final XFile photo = await _cameraController!.takePicture();

      // Analizar con el backend
      final file = File(photo.path);
      final analysisProvider = Provider.of<AnalysisProvider>(context, listen: false);

      // Usar el modelo seleccionado
      analysisProvider.setSelectedModel(_selectedModel);

      // Enviar para análisis
      final result = await analysisProvider.analyzeImage(
        file,
        centerId: _centerId,
      );

      // Recargar imágenes del centro después de analizar
      if (_centerId != null) {
        await Provider.of<ServerImageProvider>(context, listen: false)
            .loadCenterImages(_centerId!);
      }

      // Reiniciar stream
      await _cameraController!.startImageStream(_processCameraImage);

      setState(() {
        _isSaving = false;
      });

      // Mostrar resultados
      if (mounted && result != null) {
        _showAnalysisResults(result);
      }
    } catch (e) {
      debugPrint('Error al capturar y analizar: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'))
      );

      // Asegurar que se reinicie el stream
      if (_cameraController != null && !_cameraController!.value.isStreamingImages) {
        await _cameraController!.startImageStream(_processCameraImage);
      }

      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showAnalysisResults(AnalysisResult result) {
    AnalysisResultsDialog.show(context, result);
  }

  void _toggleCamera() async {
    if (_cameras == null || _cameras!.length <= 1) return;

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras!.length;

    setState(() {
      _isInitialized = false;
    });

    await _setupCamera(_cameras![_selectedCameraIndex]);
  }

  void _showModelSelector() {
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
              'Seleccionar Modelo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // YOLO
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _selectedModel == 'yolo' ? Colors.blue.shade100 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.auto_awesome,
                    color: _selectedModel == 'yolo' ? Colors.blue : Colors.grey),
              ),
              title: const Text('YOLO'),
              subtitle: const Text('Modelo estándar de detección'),
              selected: _selectedModel == 'yolo',
              onTap: () {
                setState(() {
                  _selectedModel = 'yolo';
                });
                Provider.of<AnalysisProvider>(context, listen: false)
                    .setSelectedModel('yolo');
                Navigator.pop(context);
              },
            ),

            // YOLO 2.0 (Claude)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _selectedModel == 'cl' ? Colors.purple.shade100 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.psychology_alt,
                    color: _selectedModel == 'cl' ? Colors.purple : Colors.grey),
              ),
              title: const Text('YOLO 2.0'),
              subtitle: const Text('Modelo avanzado'),
              selected: _selectedModel == 'cl',
              onTap: () {
                setState(() {
                  _selectedModel = 'cl';
                });
                Provider.of<AnalysisProvider>(context, listen: false)
                    .setSelectedModel('cl');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _objectDetector.close();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detección en Vivo'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          // Selector de modelo
          IconButton(
            icon: Icon(_selectedModel == 'cl'
                ? Icons.psychology_alt
                : Icons.auto_awesome),
            onPressed: _showModelSelector,
            tooltip: 'Seleccionar modelo',
          ),

          // Cambiar cámara
          if (_cameras != null && _cameras!.length > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios),
              onPressed: _toggleCamera,
              tooltip: 'Cambiar cámara',
            ),
        ],
      ),
      body: _isInitialized
          ? _buildCameraPreview()
          : const Center(child: CircularProgressIndicator()),
      floatingActionButton: _isInitialized && !_isSaving
          ? FloatingActionButton(
        onPressed: _captureAndAnalyze,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.camera_alt, color: Colors.white),
      )
          : _isSaving
          ? const FloatingActionButton(
        onPressed: null,
        backgroundColor: Colors.grey,
        child: CircularProgressIndicator(color: Colors.white),
      )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildCameraPreview() {
    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;

    return Stack(
      children: [
        // Vista de la cámara
        Transform.scale(
          scale: _cameraController!.value.aspectRatio / deviceRatio,
          child: Center(
            child: CameraPreview(_cameraController!),
          ),
        ),

        // Overlay de objetos detectados
        CustomPaint(
          painter: ObjectDetectionPainter(
              _detectedObjects,
              Size(
                  _cameraController!.value.previewSize!.height,
                  _cameraController!.value.previewSize!.width
              ),
              MediaQuery.of(context).size
          ),
        ),

        // Información del modelo seleccionado
        Positioned(
          top: 20,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Modelo: ${_selectedModel == 'cl' ? 'YOLO 2.0 (Claude)' : 'YOLO'}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),

        // Contador de objetos detectados
        Positioned(
          bottom: 100,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_detectedObjects.length} objetos',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Toca para guardar',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),

        // Indicador de procesamiento
        if (_isSaving)
          Container(
            color: Colors.black45,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Procesando y guardando...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

