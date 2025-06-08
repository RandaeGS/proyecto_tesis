import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';

class AnalysisResult {
  final String id;
  final String fechaCreacion;
  final String tipoModelo;
  final int numeroObjetos;
  final double tiempoProcesamiento;
  final String resultados;
  final List<Map<String, dynamic>> detecciones;
  final String modeloUsado;
  final int? centerId;
  final String? imageId;
  final bool? confirmed;
  final String? outputImageBase64;

  AnalysisResult({
    required this.id,
    required this.fechaCreacion,
    required this.tipoModelo,
    required this.numeroObjetos,
    required this.tiempoProcesamiento,
    required this.resultados,
    this.detecciones = const [],
    this.modeloUsado = '',
    this.centerId,
    this.imageId,
    this.confirmed,
    this.outputImageBase64,
  });

  factory AnalysisResult.fromJsonMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>> detecList = [];
    if (map['detecciones'] != null) {
      detecList = List<Map<String, dynamic>>.from(
          (map['detecciones'] as List).map((item) =>
          Map<String, dynamic>.from(item))
      );
    }

    int? parsedCenterId;
    if (map.containsKey('center_id')) {
      if (map['center_id'] is int) {
        parsedCenterId = map['center_id'];
      } else if (map['center_id'] is String && map['center_id'].toString().isNotEmpty) {
        parsedCenterId = int.tryParse(map['center_id'].toString());
      }
    }

    String? imageId;
    if (map.containsKey('image_id') && map['image_id'] != null) {
      imageId = map['image_id'].toString();
    }

    bool? confirmed;
    if (map.containsKey('confirmed')) {
      if (map['confirmed'] is bool) {
        confirmed = map['confirmed'];
      } else if (map['confirmed'] is String) {
        confirmed = map['confirmed'].toLowerCase() == 'true';
      } else if (map['confirmed'] is num) {
        confirmed = map['confirmed'] != 0;
      }
    }

    // Extraer la imagen de salida
    String? outputImage;
    if (map.containsKey('output_image') && map['output_image'] != null) {
      outputImage = map['output_image'].toString();
    } else if (map.containsKey('visualization') && map['visualization'] != null) {
      outputImage = map['visualization'].toString();
    }

    return AnalysisResult(
      id: map['id'] ?? '',
      fechaCreacion: map['fechaCreacion'] ?? '',
      tipoModelo: map['tipoModelo'] ?? '',
      numeroObjetos: map['numeroObjetos'] ?? 0,
      tiempoProcesamiento: (map['tiempoProcesamiento'] is int)
          ? (map['tiempoProcesamiento'] as int).toDouble()
          : map['tiempoProcesamiento'] ?? 0.0,
      resultados: map['resultados'] ?? '',
      detecciones: detecList,
      modeloUsado: map['modeloUsado'] ?? '',
      centerId: parsedCenterId,
      imageId: imageId,
      confirmed: confirmed,
      outputImageBase64: outputImage,
    );
  }

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    debugPrint('Procesando AnalysisResult.fromJson con: ${json.keys}');

    final resultadosData = json['resultados'] ?? {};
    List<Map<String, dynamic>> detecciones = [];
    int objCount = 0;
    String modelType = '';
    double processingTime = 0.0;

    if (resultadosData is Map) {
      modelType = resultadosData['model_type'] ?? '';

      objCount = resultadosData['count'] ?? resultadosData['count_objects'] ?? 0;

      List<String> possibleTimeKeys = ['processing_time', 'tiempo', 'time'];
      for (var key in possibleTimeKeys) {
        if (resultadosData.containsKey(key)) {
          var timeValue = resultadosData[key];
          if (timeValue is num) {
            processingTime = timeValue.toDouble();
            break;
          } else if (timeValue is String) {
            processingTime = double.tryParse(timeValue) ?? 0.0;
            break;
          }
        }
      }

      if (resultadosData.containsKey('detections') && resultadosData['detections'] is List) {
        final List detectionsList = resultadosData['detections'] as List;
        detecciones = detectionsList.map((item) =>
        Map<String, dynamic>.from(item as Map)
        ).toList();

        if (objCount == 0) {
          objCount = detecciones.length;
        }
      }
    }

    if (processingTime == 0.0 && json.containsKey('tiempo_procesamiento')) {
      var timeValue = json['tiempo_procesamiento'];
      if (timeValue is num) {
        processingTime = timeValue.toDouble();
      } else if (timeValue is String) {
        processingTime = double.tryParse(timeValue) ?? 0.0;
      }
    }

    final formattedJson = _formatResultJson(resultadosData);

    int? parsedCenterId;
    if (json.containsKey('center_id')) {
      if (json['center_id'] is int) {
        parsedCenterId = json['center_id'];
      } else if (json['center_id'] is String && json['center_id'].toString().isNotEmpty) {
        parsedCenterId = int.tryParse(json['center_id'].toString());
      }
    }

    String? imageId;
    if (json.containsKey('image_id') && json['image_id'] != null) {
      imageId = json['image_id'].toString();
    }

    bool? confirmed;
    if (json.containsKey('confirmed')) {
      if (json['confirmed'] is bool) {
        confirmed = json['confirmed'];
      } else if (json['confirmed'] is String) {
        confirmed = json['confirmed'].toLowerCase() == 'true';
      } else if (json['confirmed'] is num) {
        confirmed = json['confirmed'] != 0;
      }
    }

    // Extraer la imagen de salida de múltiples ubicaciones posibles
    String? outputImage;

    // Primero intentar desde resultadosData
    if (resultadosData is Map) {
      if (resultadosData.containsKey('output_image') && resultadosData['output_image'] != null) {
        outputImage = resultadosData['output_image'].toString();
      } else if (resultadosData.containsKey('visualization') && resultadosData['visualization'] != null) {
        outputImage = resultadosData['visualization'].toString();
      }
    }

    // Si no se encontró, buscar en el JSON principal
    if (outputImage == null) {
      if (json.containsKey('output_image') && json['output_image'] != null) {
        outputImage = json['output_image'].toString();
      } else if (json.containsKey('visualization') && json['visualization'] != null) {
        outputImage = json['visualization'].toString();
      }
    }

    debugPrint('Output image encontrada: ${outputImage != null ? "Sí (${outputImage!.length} chars)" : "No"}');

    return AnalysisResult(
      id: json['id']?.toString() ?? json['deteccion_id']?.toString() ?? '',
      fechaCreacion: json['fecha_creacion'] ?? DateTime.now().toString(),
      tipoModelo: json['tipo_modelo'] ?? modelType,
      numeroObjetos: json['numero_objetos'] ?? objCount,
      tiempoProcesamiento: processingTime,
      resultados: formattedJson,
      detecciones: detecciones,
      modeloUsado: modelType,
      centerId: parsedCenterId,
      imageId: imageId,
      confirmed: confirmed,
      outputImageBase64: outputImage,
    );
  }

  static String _formatResultJson(Map<String, dynamic> json) {
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    try {
      return encoder.convert(json);
    } catch (e) {
      return json.toString();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fechaCreacion': fechaCreacion,
      'tipoModelo': tipoModelo,
      'numeroObjetos': numeroObjetos,
      'tiempoProcesamiento': tiempoProcesamiento,
      'resultados': resultados,
      'detecciones': detecciones,
      'modeloUsado': modeloUsado,
      'center_id': centerId,
      'image_id': imageId,
      'confirmed': confirmed,
      'output_image': outputImageBase64,
    };
  }

  List<String> getDetectionDescriptions() {
    return detecciones.map((detection) {
      final className = detection['class'] ?? 'Desconocido';
      final confidence = detection['confidence'] ?? 0.0;
      final formattedConfidence = (confidence * 100).toStringAsFixed(1);

      return '$className (${formattedConfidence}%)';
    }).toList();
  }

  // Método helper para verificar si tiene imagen de salida
  bool get hasOutputImage => outputImageBase64 != null && outputImageBase64!.isNotEmpty;

  AnalysisResult copyWith({
    String? id,
    String? fechaCreacion,
    String? tipoModelo,
    int? numeroObjetos,
    double? tiempoProcesamiento,
    String? resultados,
    List<Map<String, dynamic>>? detecciones,
    String? modeloUsado,
    int? centerId,
    String? imageId,
    bool? confirmed,
    String? outputImageBase64,
  }) {
    return AnalysisResult(
      id: id ?? this.id,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      tipoModelo: tipoModelo ?? this.tipoModelo,
      numeroObjetos: numeroObjetos ?? this.numeroObjetos,
      tiempoProcesamiento: tiempoProcesamiento ?? this.tiempoProcesamiento,
      resultados: resultados ?? this.resultados,
      detecciones: detecciones ?? this.detecciones,
      modeloUsado: modeloUsado ?? this.modeloUsado,
      centerId: centerId ?? this.centerId,
      imageId: imageId ?? this.imageId,
      confirmed: confirmed ?? this.confirmed,
      outputImageBase64: outputImageBase64 ?? this.outputImageBase64,
    );
  }
}