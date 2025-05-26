package com.example.app_movil

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.app.Activity

class MainActivity: FlutterActivity() {
    private val CHANNEL = "yolo_detector"
    private val YOLO_ACTIVITY_REQUEST = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startYoloDetection" -> {
                    // Lanzar la actividad de detección YOLO nativa
                    val intent = Intent(this, YoloDetectionActivity::class.java)
                    startActivityForResult(intent, YOLO_ACTIVITY_REQUEST)
                    result.success("Launching YOLO detection")
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == YOLO_ACTIVITY_REQUEST) {
            if (resultCode == Activity.RESULT_OK) {
                // Aquí puedes manejar los resultados si es necesario
                // Por ejemplo, si quieres pasar datos de vuelta a Flutter
            }
        }
    }
}