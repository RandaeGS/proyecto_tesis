// import 'package:flutter/material.dart';
// import 'package:camera/camera.dart';
// import 'package:flutter/services.dart';
// import 'dart:typed_data';
// import 'dart:io';
// import '../services/yolo_detector_service.dart';
//
// class CameraPhotoYoloScreen extends StatefulWidget {
//   @override
//   _CameraPhotoYoloScreenState createState() => _CameraPhotoYoloScreenState();
// }
//
// class _CameraPhotoYoloScreenState extends State<CameraPhotoYoloScreen> {
//   CameraController? _cameraController;
//   List<CameraDescription> _cameras = [];
//   bool _isCameraInitialized = false;
//   bool _isDetecting = false;
//
//   List<DetectionResult> _detections = [];
//   int _inferenceTime = 0;
//   String _statusMessage = "Inicializando...";
//   File? _capturedImage;
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeCamera();
//   }
//
//   Future<void> _initializeCamera() async {
//     try {
//       setState(() {
//         _statusMessage = "Buscando cámaras...";
//       });
//
//       _cameras = await availableCameras();
//       if (_cameras.isEmpty) {
//         setState(() {
//           _statusMessage = "No se encontraron cámaras";
//         });
//         return;
//       }
//
//       setState(() {
//         _statusMessage = "Inicializando cámara...";
//       });
//
//       _cameraController = CameraController(
//         _cameras[0], // Usar cámara trasera
//         ResolutionPreset.medium,
//         enableAudio: false,
//       );
//
//       await _cameraController!.initialize();
//
//       setState(() {
//         _isCameraInitialized = true;
//         _statusMessage = "Inicializando detector...";
//       });
//
//       // Inicializar el detector
//       try {
//         final initResult = await YoloDetectorService.initializeDetector();
//         print("Detector initialized: $initResult");
//
//         setState(() {
//           _statusMessage = "¡Listo! Toca para capturar y detectar";
//         });
//
//       } catch (e) {
//         setState(() {
//           _statusMessage = "Error inicializando detector: $e";
//         });
//         print("Error initializing detector: $e");
//       }
//
//     } catch (e) {
//       setState(() {
//         _statusMessage = "Error inicializando cámara: $e";
//       });
//       print('Error initializing camera: $e');
//     }
//   }
//
//   Future<void> _captureAndDetect() async {
//     if (_cameraController == null || !_cameraController!.value.isInitialized || _isDetecting) {
//       return;
//     }
//
//     setState(() {
//       _isDetecting = true;
//       _statusMessage = "Capturando imagen...";
//     });
//
//     try {
//       // Capturar imagen
//       final XFile image = await _cameraController!.takePicture();
//       final File imageFile = File(image.path);
//
//       setState(() {
//         _capturedImage = imageFile;
//         _statusMessage = "Procesando imagen...";
//       });
//
//       // Leer imagen como bytes
//       final Uint8List imageBytes = await imageFile.readAsBytes();
//
//       print("Image captured: ${imageBytes.length} bytes");
//
//       // Realizar detección
//       final stopwatch = Stopwatch()..start();
//       final detections = await YoloDetectorService.detectObjects(imageBytes);
//       stopwatch.stop();
//
//       setState(() {
//         _detections = detections;
//         _inferenceTime = stopwatch.elapsedMilliseconds;
//         _statusMessage = "¡Detección completada! ${detections.length} objetos encontrados";
//       });
//
//       print("Detection completed: ${detections.length} objects found in ${stopwatch.elapsedMilliseconds}ms");
//
//     } catch (e) {
//       print('Detection error: $e');
//       setState(() {
//         _statusMessage = "Error en detección: $e";
//       });
//     } finally {
//       setState(() {
//         _isDetecting = false;
//       });
//     }
//   }
//
//   @override
//   void dispose() {
//     _cameraController?.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('YOLOv8 Captura'),
//         backgroundColor: Colors.black,
//         foregroundColor: Colors.white,
//         actions: [
//           // Mostrar tiempo de inferencia
//           Padding(
//             padding: EdgeInsets.all(16.0),
//             child: Center(
//               child: Text(
//                 '${_inferenceTime}ms',
//                 style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//               ),
//             ),
//           ),
//         ],
//       ),
//       body: _isCameraInitialized
//           ? Column(
//         children: [
//           // Vista de la cámara o imagen capturada
//           Expanded(
//             flex: 3,
//             child: Stack(
//               children: [
//                 // Vista de la cámara o imagen
//                 Positioned.fill(
//                   child: _capturedImage != null
//                       ? Image.file(_capturedImage!, fit: BoxFit.cover)
//                       : CameraPreview(_cameraController!),
//                 ),
//
//                 // Overlay con los bounding boxes (solo si hay imagen capturada)
//                 if (_capturedImage != null)
//                   Positioned.fill(
//                     child: CustomPaint(
//                       painter: BoundingBoxPainter(_detections),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//
//           // Información de estado
//           Container(
//             color: Colors.black.withOpacity(0.8),
//             padding: EdgeInsets.all(16),
//             child: Column(
//               children: [
//                 Text(
//                   _statusMessage,
//                   style: TextStyle(color: Colors.white, fontSize: 16),
//                   textAlign: TextAlign.center,
//                 ),
//
//                 SizedBox(height: 16),
//
//                 // Botones
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                   children: [
//                     ElevatedButton.icon(
//                       onPressed: _isDetecting ? null : _captureAndDetect,
//                       icon: _isDetecting
//                           ? SizedBox(
//                           width: 20,
//                           height: 20,
//                           child: CircularProgressIndicator(strokeWidth: 2)
//                       )
//                           : Icon(Icons.camera_alt),
//                       label: Text(_isDetecting ? 'Procesando...' : 'Capturar y Detectar'),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.blue,
//                         foregroundColor: Colors.white,
//                         padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
//                       ),
//                     ),
//
//                     if (_capturedImage != null)
//                       ElevatedButton.icon(
//                         onPressed: () {
//                           setState(() {
//                             _capturedImage = null;
//                             _detections = [];
//                             _statusMessage = "¡Listo! Toca para capturar y detectar";
//                           });
//                         },
//                         icon: Icon(Icons.refresh),
//                         label: Text('Nueva'),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.green,
//                           foregroundColor: Colors.white,
//                         ),
//                       ),
//                   ],
//                 ),
//
//                 SizedBox(height: 16),
//
//                 // Lista de detecciones
//                 if (_detections.isNotEmpty)
//                   Container(
//                     height: 80,
//                     child: ListView.builder(
//                       scrollDirection: Axis.horizontal,
//                       itemCount: _detections.length,
//                       itemBuilder: (context, index) {
//                         final detection = _detections[index];
//                         return Container(
//                           margin: EdgeInsets.only(right: 8),
//                           padding: EdgeInsets.all(8),
//                           decoration: BoxDecoration(
//                             color: Colors.blue.withOpacity(0.8),
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               Text(
//                                 detection.className,
//                                 style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//                               ),
//                               Text(
//                                 '${(detection.confidence * 100).toStringAsFixed(1)}%',
//                                 style: TextStyle(color: Colors.white, fontSize: 12),
//                               ),
//                               Text(
//                                 'x: ${detection.x1.toStringAsFixed(2)}',
//                                 style: TextStyle(color: Colors.white, fontSize: 10),
//                               ),
//                             ],
//                           ),
//                         );
//                       },
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       )
//           : Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             CircularProgressIndicator(),
//             SizedBox(height: 16),
//             Text(_statusMessage),
//           ],
//         ),
//       ),
//     );
//   }
// }
//
// class BoundingBoxPainter extends CustomPainter {
//   final List<DetectionResult> detections;
//
//   BoundingBoxPainter(this.detections);
//
//   @override
//   void paint(Canvas canvas, Size size) {
//     if (detections.isEmpty) return;
//
//     final paint = Paint()
//       ..color = Colors.red
//       ..strokeWidth = 3.0
//       ..style = PaintingStyle.stroke;
//
//     for (final detection in detections) {
//       // Convertir coordenadas normalizadas a coordenadas de pantalla
//       final double left = detection.x1 * size.width;
//       final double top = detection.y1 * size.height;
//       final double right = detection.x2 * size.width;
//       final double bottom = detection.y2 * size.height;
//
//       // Validar coordenadas
//       if (left >= 0 && top >= 0 && right <= size.width && bottom <= size.height && left < right && top < bottom) {
//         // Dibujar bounding box
//         final rect = Rect.fromLTRB(left, top, right, bottom);
//         canvas.drawRect(rect, paint);
//
//         // Dibujar etiqueta
//         final textSpan = TextSpan(
//           text: '${detection.className} ${(detection.confidence * 100).toStringAsFixed(1)}%',
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: 14,
//             fontWeight: FontWeight.bold,
//           ),
//         );
//
//         final textPainter = TextPainter(
//           text: textSpan,
//           textDirection: TextDirection.ltr,
//         );
//
//         textPainter.layout();
//
//         // Asegurar que el texto esté dentro de los límites
//         double textX = left + 4;
//         double textY = top - textPainter.height - 2;
//
//         if (textY < 0) textY = top + 4;
//         if (textX + textPainter.width > size.width) textX = size.width - textPainter.width - 4;
//
//         // Fondo para el texto
//         final textBackground = Rect.fromLTWH(
//           textX - 4,
//           textY - 2,
//           textPainter.width + 8,
//           textPainter.height + 4,
//         );
//
//         canvas.drawRect(textBackground, Paint()..color = Colors.red);
//         textPainter.paint(canvas, Offset(textX, textY));
//       }
//     }
//   }
//
//   @override
//   bool shouldRepaint(CustomPainter oldDelegate) => true;
// }