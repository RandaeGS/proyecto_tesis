package com.example.app_movil

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.EventChannel
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors
import java.util.concurrent.ExecutorService
import android.os.Handler
import android.os.Looper

class MainActivity: FlutterActivity() {
    private val CHANNEL = "yolo_detector"
    private val EVENT_CHANNEL = "yolo_detector_stream"
    private lateinit var detector: Detector
    private var eventSink: EventChannel.EventSink? = null
    private val executorService: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var isProcessing = false
    private var frameSkipCounter = 0
    private val FRAME_SKIP = 5 // Procesar 1 de cada 5 frames para mejor rendimiento y menos detecciones duplicadas

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Inicializar detector una sola vez
        initializeDetector()

        // Canal para métodos individuales
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "detectObjects" -> {
                    handleSingleDetection(call, result)
                }
                "processYuvFrame" -> {
                    handleYuvFrame(call, result)
                }
                "initializeDetector" -> {
                    try {
                        if (!::detector.isInitialized) {
                            initializeDetector()
                        }
                        result.success("Detector initialized")
                    } catch (e: Exception) {
                        result.error("INIT_ERROR", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Canal de eventos para stream en tiempo real
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }

    private fun initializeDetector() {
        detector = Detector(
            context = this,
            modelPath = "model.tflite",
            labelPath = "labels.txt",
            detectorListener = object : Detector.DetectorListener {
                override fun onEmptyDetect() {
                    sendDetectionResult(emptyList(), 0)
                }

                override fun onDetect(boundingBoxes: List<BoundingBox>, inferenceTime: Long) {
                    val results = boundingBoxes.map { box ->
                        mapOf(
                            "x1" to box.x1,
                            "y1" to box.y1,
                            "x2" to box.x2,
                            "y2" to box.y2,
                            "confidence" to box.cnf,
                            "className" to box.clsName,
                            "classId" to box.cls
                        )
                    }
                    sendDetectionResult(results, inferenceTime)
                }
            }
        )
        detector.setup()
    }

    private fun handleYuvFrame(call: MethodCall, result: MethodChannel.Result) {
        // Skip frames para mejor rendimiento
        frameSkipCounter++
        if (frameSkipCounter < FRAME_SKIP) {
            result.success(null)
            return
        }
        frameSkipCounter = 0

        // Evitar procesamiento simultáneo
        if (isProcessing) {
            result.success(null)
            return
        }

        isProcessing = true

        executorService.execute {
            try {
                val width = call.argument<Int>("width") ?: 0
                val height = call.argument<Int>("height") ?: 0
                val yBytes = call.argument<ByteArray>("yBytes")
                val uBytes = call.argument<ByteArray>("uBytes")
                val vBytes = call.argument<ByteArray>("vBytes")
                val yRowStride = call.argument<Int>("yRowStride") ?: width
                val uvRowStride = call.argument<Int>("uvRowStride") ?: width
                val uvPixelStride = call.argument<Int>("uvPixelStride") ?: 1

                android.util.Log.d("YOLODetector", "Processing frame: ${width}x${height}")

                if (yBytes == null || uBytes == null || vBytes == null) {
                    mainHandler.post {
                        isProcessing = false
                        result.error("INVALID_ARGS", "Frame data is null", null)
                    }
                    return@execute
                }

                // Convertir YUV a Bitmap de manera eficiente
                val bitmap = convertYuvToBitmap(
                    yBytes, uBytes, vBytes,
                    width, height,
                    yRowStride, uvRowStride, uvPixelStride
                )

                if (bitmap != null) {
                    android.util.Log.d("YOLODetector", "Detecting on bitmap: ${bitmap.width}x${bitmap.height}")

                    // Detectar objetos directamente sin rotar
                    detector.detect(bitmap)
                    bitmap.recycle()
                }

                mainHandler.post {
                    isProcessing = false
                    result.success(null)
                }

            } catch (e: Exception) {
                android.util.Log.e("YOLODetector", "Error processing frame", e)
                mainHandler.post {
                    isProcessing = false
                    result.error("PROCESSING_ERROR", e.message, null)
                }
            }
        }
    }

    private fun convertYuvToBitmap(
        yBytes: ByteArray,
        uBytes: ByteArray,
        vBytes: ByteArray,
        width: Int,
        height: Int,
        yRowStride: Int,
        uvRowStride: Int,
        uvPixelStride: Int
    ): Bitmap? {
        try {
            // Crear buffer NV21
            val nv21 = ByteArray(width * height * 3 / 2)

            // Copiar Y plane
            if (yRowStride == width) {
                // Sin padding, copia directa
                System.arraycopy(yBytes, 0, nv21, 0, width * height)
            } else {
                // Con padding, copiar fila por fila
                var yPos = 0
                for (row in 0 until height) {
                    System.arraycopy(yBytes, row * yRowStride, nv21, yPos, width)
                    yPos += width
                }
            }

            // Convertir UV a formato NV21 (intercalado V,U)
            val uvSize = width * height / 4
            var nv21Pos = width * height

            for (i in 0 until uvSize) {
                val uvIndex = i * uvPixelStride
                if (uvIndex < vBytes.size && uvIndex < uBytes.size) {
                    nv21[nv21Pos++] = vBytes[uvIndex] // V
                    nv21[nv21Pos++] = uBytes[uvIndex] // U
                }
            }

            // Convertir NV21 a JPEG
            val yuvImage = YuvImage(nv21, ImageFormat.NV21, width, height, null)
            val out = ByteArrayOutputStream()
            yuvImage.compressToJpeg(Rect(0, 0, width, height), 85, out)
            val jpegBytes = out.toByteArray()

            // Decodificar JPEG a Bitmap
            return BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)

        } catch (e: Exception) {
            e.printStackTrace()
            return null
        }
    }

    private fun handleSingleDetection(call: MethodCall, result: MethodChannel.Result) {
        executorService.execute {
            try {
                val imageBytes = call.argument<ByteArray>("imageBytes")
                if (imageBytes == null) {
                    mainHandler.post {
                        result.error("INVALID_ARGUMENT", "imageBytes is required", null)
                    }
                    return@execute
                }

                val bitmap = BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size)
                if (bitmap == null) {
                    mainHandler.post {
                        result.error("DECODE_ERROR", "Failed to decode image", null)
                    }
                    return@execute
                }

                var detectionResults: List<Map<String, Any>>? = null
                var detectionCompleted = false

                val tempListener = object : Detector.DetectorListener {
                    override fun onEmptyDetect() {
                        detectionResults = emptyList()
                        detectionCompleted = true
                    }

                    override fun onDetect(boundingBoxes: List<BoundingBox>, inferenceTime: Long) {
                        detectionResults = boundingBoxes.map { box ->
                            mapOf(
                                "x1" to box.x1,
                                "y1" to box.y1,
                                "x2" to box.x2,
                                "y2" to box.y2,
                                "confidence" to box.cnf,
                                "className" to box.clsName,
                                "classId" to box.cls
                            )
                        }
                        detectionCompleted = true
                    }
                }

                // Crear detector temporal para esta detección
                val tempDetector = Detector(this, "model.tflite", "labels.txt", tempListener)
                tempDetector.setup()
                tempDetector.detect(bitmap)

                // Esperar resultado
                var attempts = 0
                while (!detectionCompleted && attempts < 50) {
                    Thread.sleep(10)
                    attempts++
                }

                tempDetector.clear()
                bitmap.recycle()

                mainHandler.post {
                    result.success(detectionResults ?: emptyList<Map<String, Any>>())
                }

            } catch (e: Exception) {
                mainHandler.post {
                    result.error("DETECTION_ERROR", e.message, null)
                }
            }
        }
    }

    private fun sendDetectionResult(results: List<Map<String, Any>>, inferenceTime: Long) {
        android.util.Log.d("YOLODetector", "Sending ${results.size} detections, inference time: ${inferenceTime}ms")
        results.forEach { detection ->
            android.util.Log.d("YOLODetector", "Detection: ${detection["className"]} at (${detection["x1"]}, ${detection["y1"]}) - (${detection["x2"]}, ${detection["y2"]})")
        }

        mainHandler.post {
            eventSink?.success(mapOf(
                "detections" to results,
                "inferenceTime" to inferenceTime
            ))
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::detector.isInitialized) {
            detector.clear()
        }
        executorService.shutdown()
    }
}