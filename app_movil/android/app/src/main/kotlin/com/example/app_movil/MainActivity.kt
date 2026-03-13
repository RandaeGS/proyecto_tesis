package com.example.app_movil

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.app.Activity

class MainActivity: FlutterActivity() {
    private val CHANNEL = "yolo_detector"
    private val YOLO_ACTIVITY_REQUEST = 1001
    private var methodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "startYoloDetection" -> {
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

        if (requestCode == YOLO_ACTIVITY_REQUEST && resultCode == Activity.RESULT_OK) {
            val imagePath = data?.getStringExtra("image_path")
            if (imagePath != null) {
                methodChannel?.invokeMethod("onImageCaptured", imagePath)
            }
        }
    }
}