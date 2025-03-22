import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';

/// Modelo para representar un resultado de análisis de imagen
class AnalysisResult {
  final String id;
  final String fechaCreacion;
  final String tipoModelo;
  final int numeroObjetos;
  final double tiempoProcesamiento;
  final String resultados;
  final List<Map<String, dynamic>> detecciones;
  final String modeloUsado;
  final int? centerId;  // ID del centro asociado
  final String? imageId;  // ID de la imagen asociada

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
  });

  /// Crea una instancia desde un mapa JSON (formato guardado)
  factory AnalysisResult.fromJsonMap(Map<String, dynamic> map) {
    // Convertir lista de detecciones
    List<Map<String, dynamic>> detecList = [];
    if (map['detecciones'] != null) {
      detecList = List<Map<String, dynamic>>.from(
          (map['detecciones'] as List).map((item) =>
          Map<String, dynamic>.from(item))
      );
    }

    // Parsear centerId si está presente
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
    );
  }

  /// Crea una instancia desde un mapa JSON (formato API)
  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    debugPrint('Procesando AnalysisResult.fromJson con: ${json.keys}');

    // Intentamos extraer los resultados
    final resultadosData = json['resultados'] ?? {};
    List<Map<String, dynamic>> detecciones = [];
    int objCount = 0;
    String modelType = '';
    double processingTime = 0.0;

    // Procesamos la estructura de resultados
    if (resultadosData is Map) {
      // Extraer el tipo de modelo
      modelType = resultadosData['model_type'] ?? '';

      // Extraer conteo de objetos
      objCount = resultadosData['count'] ?? 0;

      // Extraer tiempo de procesamiento (buscar en múltiples posibles claves)
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

      // Extraer detecciones
      if (resultadosData.containsKey('detections') && resultadosData['detections'] is List) {
        final List detectionsList = resultadosData['detections'] as List;
        detecciones = detectionsList.map((item) =>
        Map<String, dynamic>.from(item as Map)
        ).toList();

        // Asegurar que el conteo coincida si no estaba explícito
        if (objCount == 0) {
          objCount = detecciones.length;
        }
      }
    }

    // También intentar obtener el tiempo de procesamiento del objeto principal
    if (processingTime == 0.0 && json.containsKey('tiempo_procesamiento')) {
      var timeValue = json['tiempo_procesamiento'];
      if (timeValue is num) {
        processingTime = timeValue.toDouble();
      } else if (timeValue is String) {
        processingTime = double.tryParse(timeValue) ?? 0.0;
      }
    }

    // Crear una versión formateada del JSON de resultados para mostrar
    final formattedJson = _formatResultJson(resultadosData);

    // Parsear centerId si está presente
    int? parsedCenterId;
    if (json.containsKey('center_id')) {
      if (json['center_id'] is int) {
        parsedCenterId = json['center_id'];
      } else if (json['center_id'] is String && json['center_id'].toString().isNotEmpty) {
        parsedCenterId = int.tryParse(json['center_id'].toString());
      }
    }

    // Parsear imageId si está presente
    String? imageId;
    if (json.containsKey('image_id') && json['image_id'] != null) {
      imageId = json['image_id'].toString();
    }

    return AnalysisResult(
      id: json['id']?.toString() ?? json['deteccion_id']?.toString() ?? '',
      fechaCreacion: json['fecha_creacion'] ?? DateTime.now().toString(),
      tipoModelo: json['tipo_modelo'] ?? modelType,
      numeroObjetos: json['numero_objetos'] ?? objCount,
      tiempoProcesamiento: processingTime,  // Usar el valor extraído
      resultados: formattedJson,
      detecciones: detecciones,
      modeloUsado: modelType,
      centerId: parsedCenterId,
      imageId: imageId,
    );
  }


  /// Método para formatear el JSON de resultados de manera más legible
  static String _formatResultJson(Map<String, dynamic> json) {
    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    try {
      return encoder.convert(json);
    } catch (e) {
      return json.toString();
    }
  }

  /// Convierte la instancia a un mapa JSON para almacenamiento
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
    };
  }

  /// Método para obtener una descripción resumida de cada detección
  List<String> getDetectionDescriptions() {
    return detecciones.map((detection) {
      final className = detection['class'] ?? 'Desconocido';
      final confidence = detection['confidence'] ?? 0.0;
      final formattedConfidence = (confidence * 100).toStringAsFixed(1);

      return '$className (${formattedConfidence}%)';
    }).toList();
  }

  /// Crea una copia de este resultado con los campos especificados actualizados
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
    );
  }
}