import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:provider/provider.dart';
import '../../entities/analisysresult.dart';
import '../../services/auth_services/auth_provider.dart';
import '../../services/deteccion_services/analysis_provider.dart';
import '../../services/deteccion_services/confirmation_dialog.dart';
import '../../utils/show_analisys_results.dart';
import '../image_capture_screen.dart';
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

  // ML Kit Object Detection (para vista previa local)
  late ObjectDetector _objectDetector;
  List<DetectedObject> _detectedObjects = [];

  // Para detección con el servidor
  int? _centerId;
  String _selectedModel = 'yolo'; // Modelo por defecto

  // Temporizador para análisis periódico
  Timer? _analysisTimer;

  // Control de visualización
  bool _showLocalDetection = true; // Mostrar detección local (ML Kit)

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
    }
  }

  Future<void> _setupCamera(CameraDescription cameraDescription) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    _cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });

        // Iniciar análisis periódico en lugar de stream
        _startPeriodicAnalysis();
      }
    } catch (e) {
      debugPrint('Error al configurar la cámara: $e');
    }
  }

  void _startPeriodicAnalysis() {
    // Detener temporizador anterior si existe
    _analysisTimer?.cancel();

    // Analizar cada 2 segundos (ajustar según las necesidades de rendimiento)
    _analysisTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      _analyzeCurrentFrame();
    });
  }

  Future<void> _analyzeCurrentFrame() async {
    if (_isProcessing || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    _isProcessing = true;
    try {
      // Capturar una imagen
      final XFile imageFile = await _cameraController!.takePicture();

      // Procesar la imagen con ML Kit para la vista previa local
      if (_showLocalDetection) {
        final inputImage = InputImage.fromFilePath(imageFile.path);
        final objects = await _objectDetector.processImage(inputImage);

        // Actualizar la UI con la detección local
        if (mounted) {
          setState(() {
            _detectedObjects = objects;
          });
        }
      }

      // Limpiar el archivo temporal
      try {
        await File(imageFile.path).delete();
      } catch (e) {
        debugPrint('Error al eliminar archivo temporal: $e');
      }
    } catch (e) {
      debugPrint('Error al analizar frame: $e');
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _initDetector() async {
    final options = ObjectDetectorOptions(
      mode: DetectionMode.single,
      classifyObjects: true,
      multipleObjects: true,
    );
    _objectDetector = ObjectDetector(options: options);
  }

  // Capturar y analizar con servidor
  Future<void> _captureAndAnalyzeWithServer() async {
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

    try {
      setState(() {
        _isSaving = true;
      });

      // Pausar temporizador durante el análisis con servidor
      _analysisTimer?.cancel();

      // Capturar imagen
      final XFile photo = await _cameraController!.takePicture();

      // Analizar con el backend SIN GUARDAR automáticamente
      final file = File(photo.path);
      final analysisProvider = Provider.of<AnalysisProvider>(context, listen: false);

      // Usar el modelo seleccionado
      analysisProvider.setSelectedModel(_selectedModel);

      // Enviar para análisis sin guardar
      final result = await analysisProvider.analyzeImage(
        file,
        centerId: _centerId,
        saveToServer: false, // No guardar automáticamente
      );

      setState(() {
        _isSaving = false;
      });

      // Reiniciar temporizador
      _startPeriodicAnalysis();

      // Mostrar diálogo de confirmación si tenemos un resultado
      if (mounted && result != null) {
        // Usar el nuevo diálogo de confirmación con edición de cantidades
        // MODIFICADO: Ahora esperamos un Map<String, dynamic> que contiene las modificaciones
        final editResult = await ConfirmationDialog.show(context, result);

        if (editResult != null) {
          // Usuario confirmó, guardamos los resultados con posibles modificaciones
          setState(() => _isSaving = true);

          // NUEVO: Actualizar el análisisProvider con los resultados modificados
          final analysisProvider = Provider.of<AnalysisProvider>(context, listen: false);

          // Proporcionar los resultados modificados al provider
          if (editResult.containsKey('modified_results')) {
            analysisProvider.setModifiedResults(editResult['modified_results']);
          }

          // Confirmar y guardar en el servidor
          final confirmedResult = await analysisProvider.confirmAnalysis(centerId: _centerId);

          setState(() => _isSaving = false);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Resultados guardados correctamente'),
                backgroundColor: Colors.green,
              ),
            );

            // Mostrar resultados confirmados
            if (confirmedResult != null) {
              _showAnalysisResults(confirmedResult);
            }
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
    } catch (e) {
      debugPrint('Error al capturar y analizar: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'))
      );

      setState(() {
        _isSaving = false;
      });

      // Reiniciar temporizador
      _startPeriodicAnalysis();
    }
  }

  void _showAnalysisResults(AnalysisResult result) {
    AnalysisResultsDialog.show(context, result);
  }

  void _toggleCamera() async {
    if (_cameras == null || _cameras!.length <= 1) return;

    // Detener análisis periódico
    _analysisTimer?.cancel();

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

            // Opción para mostrar/ocultar detección local
            SwitchListTile(
              title: const Text('Mostrar detección local'),
              subtitle: const Text('Previsualizar con ML Kit (solo vista previa)'),
              value: _showLocalDetection,
              onChanged: (value) {
                setState(() {
                  _showLocalDetection = value;
                });
                Navigator.pop(context);
              },
            ),

            const Divider(),

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
      _analysisTimer?.cancel();
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _analysisTimer?.cancel();
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
        onPressed: _captureAndAnalyzeWithServer,
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

        // Overlay de objetos detectados (solo si la detección local está activada)
        if (_showLocalDetection)
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
                'Modelo: ${_selectedModel == 'cl' ? 'YOLO 2.0' : 'YOLO'}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),

        // Contador de objetos detectados
        if (_showLocalDetection)
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
                    '${_detectedObjects.length} objetos locales',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Toca el botón para analizar con servidor',
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
                    'Procesando con el servidor...',
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