import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/auth_services/auth_provider.dart';
import '../services/deteccion_services/analysis_provider.dart';
import '../services/deteccion_services/confirmation_dialog.dart';

class YoloLauncherScreen extends StatefulWidget {
  const YoloLauncherScreen({Key? key}) : super(key: key);

  @override
  State<YoloLauncherScreen> createState() => _YoloLauncherScreenState();
}

class _YoloLauncherScreenState extends State<YoloLauncherScreen> {
  static const _channel = MethodChannel('yolo_detector');
  int? _centerId;

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_handleMethodCall);
    _centerId = Provider.of<AuthProvider>(context, listen: false).centerId;
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    super.dispose();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onImageCaptured') {
      await _processCapture(call.arguments as String);
    }
  }

  void _showProgress({String message = 'Analizando imagen...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            const SizedBox(height: 24),
            Text(message,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _hideProgress() => Navigator.of(context, rootNavigator: true).pop();

  Future<void> _processCapture(String imagePath) async {
    final analysisProvider =
        Provider.of<AnalysisProvider>(context, listen: false);

    _showProgress();
    try {
      final result = await analysisProvider.analyzeImage(
        File(imagePath),
        centerId: _centerId,
        saveToServer: false,
      );

      if (mounted) _hideProgress();
      if (!mounted || result == null) return;

      final editResult = await ConfirmationDialog.show(context, result);

      if (editResult != null) {
        if (mounted) _showProgress(message: 'Guardando resultados...');

        if (editResult.containsKey('modified_results')) {
          analysisProvider.setModifiedResults(editResult['modified_results']);
        }

        await analysisProvider.confirmAnalysis(centerId: _centerId);

        if (mounted) {
          _hideProgress();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Resultados guardados correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        analysisProvider.cancelPendingAnalysis();
      }
    } catch (e) {
      if (mounted) {
        _hideProgress();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _startYoloDetection() async {
    try {
      await _channel.invokeMethod('startYoloDetection');
    } on PlatformException catch (e) {
      debugPrint('Error al iniciar detección YOLO: ${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YOLO Detector'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, size: 100, color: Colors.orange),
            const SizedBox(height: 20),
            const Text(
              'Detección de Objetos YOLO',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Presiona el botón para iniciar la cámara',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _startYoloDetection,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Iniciar Detección'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
