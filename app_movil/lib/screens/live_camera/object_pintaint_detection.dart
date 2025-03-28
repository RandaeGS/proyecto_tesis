// Pintado de las cajas de detección
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';

class ObjectDetectionPainter extends CustomPainter {
  final List<DetectedObject> objects;
  final Size originalSize;
  final Size actualSize;

  ObjectDetectionPainter(this.objects, this.originalSize, this.actualSize);

  @override
  void paint(Canvas canvas, Size size) {
    final double scaleX = actualSize.width / originalSize.width;
    final double scaleY = actualSize.height / originalSize.height;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final object in objects) {
      // Asignar un color según el índice
      final color = Colors.primaries[object.hashCode.abs() % Colors.primaries.length];
      paint.color = color;

      // Obtener rectángulo del objeto
      final rect = Rect.fromLTRB(
        object.boundingBox.left * scaleX,
        object.boundingBox.top * scaleY,
        object.boundingBox.right * scaleX,
        object.boundingBox.bottom * scaleY,
      );

      // Dibujar el rectángulo
      canvas.drawRect(rect, paint);

      // Dibujar etiqueta si está disponible
      if (object.labels.isNotEmpty) {
        final textSpan = TextSpan(
          text: ' ${object.labels.first.text} ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            backgroundColor: color,
          ),
        );

        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );

        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(rect.left, rect.top - 20),
        );

        // Dibujar confianza
        final confidenceSpan = TextSpan(
          text: ' ${(object.labels.first.confidence * 100).toStringAsFixed(0)}% ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            backgroundColor: color.withOpacity(0.8),
          ),
        );

        final confidencePainter = TextPainter(
          text: confidenceSpan,
          textDirection: TextDirection.ltr,
        );

        confidencePainter.layout();
        confidencePainter.paint(
          canvas,
          Offset(rect.left, rect.top),
        );
      }
    }
  }

  @override
  bool shouldRepaint(ObjectDetectionPainter oldDelegate) {
    return oldDelegate.objects != objects;
  }
}