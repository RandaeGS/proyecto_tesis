import 'package:flutter/services.dart';
import 'dart:typed_data';

class YoloDetectorService {
  static const MethodChannel _channel = MethodChannel('yolo_detector');

  // Inicializar el detector
  static Future<String> initializeDetector() async {
    try {
      final String result = await _channel.invokeMethod('initializeDetector');
      return result;
    } on PlatformException catch (e) {
      print("Error inicializando detector: ${e.message}");
      throw e;
    }
  }

  // Detectar objetos en una imagen (para imágenes estáticas)
  static Future<List<DetectionResult>> detectObjects(Uint8List imageBytes) async {
    try {
      final List<dynamic> results = await _channel.invokeMethod('detectObjects', {
        'imageBytes': imageBytes,
      });

      return results.map((result) => DetectionResult.fromMap(Map<String, dynamic>.from(result))).toList();
    } on PlatformException catch (e) {
      print("Error detectando objetos: ${e.message}");
      return [];
    }
  }

  // Procesar frame YUV directamente (para tiempo real)
  static Future<void> processYuvFrame({
    required int width,
    required int height,
    required Uint8List yBytes,
    required Uint8List uBytes,
    required Uint8List vBytes,
    required int yRowStride,
    required int uvRowStride,
    required int uvPixelStride,
  }) async {
    try {
      await _channel.invokeMethod('processYuvFrame', {
        'width': width,
        'height': height,
        'yBytes': yBytes,
        'uBytes': uBytes,
        'vBytes': vBytes,
        'yRowStride': yRowStride,
        'uvRowStride': uvRowStride,
        'uvPixelStride': uvPixelStride,
      });
    } on PlatformException catch (e) {
      // Silenciar errores para no afectar el rendimiento
      // Los resultados vendrán por el EventChannel
    }
  }
}

class DetectionResult {
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double confidence;
  final String className;
  final int classId;

  DetectionResult({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.confidence,
    required this.className,
    required this.classId,
  });

  factory DetectionResult.fromMap(Map<String, dynamic> map) {
    return DetectionResult(
      x1: (map['x1'] as num).toDouble(),
      y1: (map['y1'] as num).toDouble(),
      x2: (map['x2'] as num).toDouble(),
      y2: (map['y2'] as num).toDouble(),
      confidence: (map['confidence'] as num).toDouble(),
      className: map['className'] as String,
      classId: map['classId'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'x1': x1,
      'y1': y1,
      'x2': x2,
      'y2': y2,
      'confidence': confidence,
      'className': className,
      'classId': classId,
    };
  }
}