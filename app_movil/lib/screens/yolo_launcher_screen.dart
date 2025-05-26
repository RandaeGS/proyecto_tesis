import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class YoloLauncherScreen extends StatelessWidget {
  static const platform = MethodChannel('yolo_detector');

  Future<void> _startYoloDetection() async {
    try {
      await platform.invokeMethod('startYoloDetection');
    } on PlatformException catch (e) {
      print("Error al iniciar detección YOLO: ${e.message}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('YOLO Detector'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt,
              size: 100,
              color: Colors.orange,
            ),
            SizedBox(height: 20),
            Text(
              'Detección de Objetos YOLO',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Presiona el botón para iniciar la cámara',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _startYoloDetection,
              icon: Icon(Icons.play_arrow),
              label: Text('Iniciar Detección'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                textStyle: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}