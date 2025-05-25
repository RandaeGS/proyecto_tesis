import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import '../services/yolo_detector_service.dart';

class RealtimeCameraYoloScreen extends StatefulWidget {
  @override
  _RealtimeCameraYoloScreenState createState() => _RealtimeCameraYoloScreenState();
}

class _RealtimeCameraYoloScreenState extends State<RealtimeCameraYoloScreen> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isDetecting = false;

  List<DetectionResult> _detections = [];
  int _inferenceTime = 0;
  String _statusMessage = "Inicializando...";

  // Stream para recibir detecciones del lado nativo
  EventChannel _eventChannel = EventChannel('yolo_detector_stream');
  Stream? _detectionStream;

  @override
  void initState() {
    super.initState();
    _initializeDetector();
    _initializeCamera();
  }

  Future<void> _initializeDetector() async {
    try {
      // Inicializar detector en el lado nativo
      final result = await YoloDetectorService.initializeDetector();
      print("Detector initialized: $result");

      // Inicializar stream de detecciones
      _detectionStream = _eventChannel.receiveBroadcastStream();
      _detectionStream!.listen((event) {
        if (event is Map) {
          final detections = event['detections'] as List;
          final inferenceTime = event['inferenceTime'] as int;

          setState(() {
            _detections = detections.map((d) => DetectionResult(
              x1: d['x1'],
              y1: d['y1'],
              x2: d['x2'],
              y2: d['y2'],
              confidence: d['confidence'],
              className: d['className'],
              classId: d['classId'],
            )).toList();
            _inferenceTime = inferenceTime;
            _statusMessage = "Detectando... ${_detections.length} objetos | ${_inferenceTime}ms";
          });
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Error inicializando detector: $e";
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      setState(() {
        _statusMessage = "Buscando cámaras...";
      });

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _statusMessage = "No se encontraron cámaras";
        });
        return;
      }

      setState(() {
        _statusMessage = "Inicializando cámara...";
      });

      _cameraController = CameraController(
        _cameras[0], // Cámara trasera
        ResolutionPreset.medium, // Medium para balance entre calidad y rendimiento
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      setState(() {
        _isCameraInitialized = true;
        _statusMessage = "¡Listo para detectar!";
      });

      // Iniciar stream de imágenes
      _startImageStream();

    } catch (e) {
      setState(() {
        _statusMessage = "Error inicializando cámara: $e";
      });
      print('Error initializing camera: $e');
    }
  }

  void _startImageStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    _cameraController!.startImageStream((CameraImage image) async {
      if (_isDetecting) return;

      _isDetecting = true;

      try {
        // Enviar frame YUV directamente al lado nativo
        await _processYuvFrame(image);
      } catch (e) {
        print('Error processing frame: $e');
      } finally {
        _isDetecting = false;
      }
    });
  }

  Future<void> _processYuvFrame(CameraImage image) async {
    try {
      // Obtener los planos YUV
      final yPlane = image.planes[0];
      final uPlane = image.planes[1];
      final vPlane = image.planes[2];

      print('Processing frame: ${image.width}x${image.height}');

      // Enviar datos YUV al lado nativo para procesamiento eficiente
      await YoloDetectorService.processYuvFrame(
        width: image.width,
        height: image.height,
        yBytes: yPlane.bytes,
        uBytes: uPlane.bytes,
        vBytes: vPlane.bytes,
        yRowStride: yPlane.bytesPerRow,
        uvRowStride: uPlane.bytesPerRow,
        uvPixelStride: uPlane.bytesPerPixel ?? 1,
      );
    } catch (e) {
      print('Error sending YUV frame: $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('YOLOv8 Tiempo Real'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isCameraInitialized
          ? Stack(
        children: [
          // Vista de la cámara
          Positioned.fill(
            child: CameraPreview(_cameraController!),
          ),

          // Overlay con bounding boxes
          Positioned.fill(
            child: CustomPaint(
              painter: BoundingBoxPainter(_detections),
            ),
          ),

          // Panel de información superior
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    _statusMessage,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_detections.isNotEmpty)
                    Text(
                      'FPS: ${(1000 / _inferenceTime).toStringAsFixed(1)}',
                      style: TextStyle(color: Colors.green, fontSize: 14),
                    ),
                ],
              ),
            ),
          ),

          // Panel inferior con detecciones
          if (_detections.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
                padding: EdgeInsets.all(16),
                child: Container(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _detections.length,
                    itemBuilder: (context, index) {
                      final detection = _detections[index];
                      return Container(
                        margin: EdgeInsets.only(right: 12),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _getColorForClass(detection.className),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              detection.className,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${(detection.confidence * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      )
          : Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 24),
              Text(
                _statusMessage,
                style: TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColorForClass(String className) {
    // Asignar colores según la clase
    switch (className.toLowerCase()) {
      case 'bottle-individual':
        return Colors.blue;
      case 'bottle-pack-12':
        return Colors.green;
      case 'canned-individual':
        return Colors.orange;
      case 'canned-pack':
        return Colors.purple;
      default:
        return Colors.red;
    }
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List<DetectionResult> detections;

  BoundingBoxPainter(this.detections);

  @override
  void paint(Canvas canvas, Size size) {
    for (final detection in detections) {
      // Log para debug
      print('Drawing box for ${detection.className}: (${detection.x1}, ${detection.y1}) - (${detection.x2}, ${detection.y2})');

      // Ahora que la imagen está rotada en Kotlin, las coordenadas vienen
      // directamente en el espacio correcto (portrait)
      final double left = detection.x1 * size.width;
      final double top = detection.y1 * size.height;
      final double right = detection.x2 * size.width;
      final double bottom = detection.y2 * size.height;

      // Validar coordenadas
      if (left < 0 || top < 0 || right > size.width || bottom > size.height) {
        print('Warning: Box out of bounds - left: $left, top: $top, right: $right, bottom: $bottom');
        continue;
      }
      if (left >= right || top >= bottom) {
        print('Warning: Invalid box dimensions - skipping');
        continue;
      }

      final rect = Rect.fromLTRB(left, top, right, bottom);

      print('Actual drawing rect: $rect on canvas size: $size');

      // Color según la clase
      final color = _getColorForClass(detection.className);

      // Dibujar bounding box
      final boxPaint = Paint()
        ..color = color
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;

      canvas.drawRect(rect, boxPaint);

      // Dibujar fondo semi-transparente
      final fillPaint = Paint()
        ..color = color.withOpacity(0.2)
        ..style = PaintingStyle.fill;

      canvas.drawRect(rect, fillPaint);

      // Preparar texto
      final text = '${detection.className} ${(detection.confidence * 100).toStringAsFixed(0)}%';
      final textSpan = TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          backgroundColor: color.withOpacity(0.8),
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      // Posicionar texto
      final textX = left + 4;
      final textY = top - textPainter.height - 4;

      // Dibujar texto
      textPainter.paint(
          canvas,
          Offset(
              textX.clamp(0, size.width - textPainter.width),
              textY > 0 ? textY : top + 4
          )
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;

  Color _getColorForClass(String className) {
    switch (className.toLowerCase()) {
      case 'bottle-individual':
        return Colors.blue;
      case 'bottle-pack-12':
        return Colors.green;
      case 'canned-individual':
        return Colors.orange;
      case 'canned-pack':
        return Colors.purple;
      default:
        return Colors.red;
    }
  }
}