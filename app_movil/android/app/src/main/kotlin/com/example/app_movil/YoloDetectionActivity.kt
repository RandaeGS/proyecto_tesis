package com.example.app_movil

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.Bundle
import android.util.Log
import android.view.Surface
import androidx.appcompat.app.AppCompatActivity
import androidx.camera.core.AspectRatio
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
// Asegúrate que el import del binding sea el correcto para tu layout de esta actividad
import com.example.app_movil.databinding.ActivityMainBinding
import com.example.surendramaran.yolov8tflite.BoundingBox
// Asegúrate que este import de Constants sea el correcto o define las constantes aquí mismo
// o pásalas por Intent
import com.example.surendramaran.yolov8tflite.Constants.LABELS_PATH
import com.example.surendramaran.yolov8tflite.Constants.MODEL_PATH
import com.example.surendramaran.yolov8tflite.Detector
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors


class YoloDetectionActivity : AppCompatActivity(), Detector.DetectorListener {
    private lateinit var binding: ActivityMainBinding
    private val isFrontCamera = false

    private var preview: Preview? = null
    private var imageAnalyzer: ImageAnalysis? = null
    private var camera: Camera? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private lateinit var detector: Detector

    private lateinit var cameraExecutor: ExecutorService

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater) // MODIFICADO AQUÍ
        setContentView(binding.root)

        // Revisa que MODEL_PATH y LABELS_PATH sean accesibles.
        // Si 'com.example.surendramaran.yolov8tflite.Constants' no es parte de tu
        // módulo android de Flutter, necesitas copiar esa clase Constants o
        // definir las rutas aquí, o pasarlas por Intent desde MainActivity de Flutter.
        // Por ejemplo:
        // val modelPath = intent.getStringExtra("modelPath") ?: "best_float32.tflite"
        // val labelPath = intent.getStringExtra("labelPath") ?: "labels.txt"
        // detector = Detector(baseContext, modelPath, labelPath, this)
        detector = Detector(baseContext, MODEL_PATH, LABELS_PATH, this)
        detector.setup()

        if (allPermissionsGranted()) {
            startCamera()
        } else {
            ActivityCompat.requestPermissions(this, REQUIRED_PERMISSIONS, REQUEST_CODE_PERMISSIONS)
        }

        cameraExecutor = Executors.newSingleThreadExecutor()
    }

    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        cameraProviderFuture.addListener({
            cameraProvider  = cameraProviderFuture.get()
            bindCameraUseCases()
        }, ContextCompat.getMainExecutor(this))
    }

    private fun bindCameraUseCases() {
        val cameraProvider = cameraProvider ?: throw IllegalStateException("Camera initialization failed.")

        val rotation = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            // Usa el display asociado con el contexto de la vista si es posible para mayor precisión,
            // o el display por defecto de la actividad.
            binding.viewFinder.display?.rotation ?: display?.rotation ?: Surface.ROTATION_0
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay?.rotation ?: Surface.ROTATION_0
        }

        val cameraSelector = CameraSelector
            .Builder()
            .requireLensFacing(CameraSelector.LENS_FACING_BACK)
            .build()

        preview =  Preview.Builder()
            .setTargetAspectRatio(AspectRatio.RATIO_4_3)
            .setTargetRotation(rotation)
            .build()

        imageAnalyzer = ImageAnalysis.Builder()
            .setTargetAspectRatio(AspectRatio.RATIO_4_3)
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setTargetRotation(rotation) // Asegúrate que sea la misma rotación para análisis y preview
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
            .build()

        imageAnalyzer?.setAnalyzer(cameraExecutor) { imageProxy ->
            val bitmapBuffer =
                Bitmap.createBitmap(
                    imageProxy.width,
                    imageProxy.height,
                    Bitmap.Config.ARGB_8888
                )
            // El bloque 'use' se encarga de cerrar el imageProxy automáticamente.
            // No necesitas llamar a imageProxy.close() explícitamente después.
            imageProxy.use {
                bitmapBuffer.copyPixelsFromBuffer(it.planes[0].buffer)
            }
            // imageProxy.close() // ESTA LÍNEA YA NO ES NECESARIA Y PUEDE CAUSAR ERROR

            val matrix = Matrix().apply {
                postRotate(imageProxy.imageInfo.rotationDegrees.toFloat())

                if (isFrontCamera) {
                    postScale(
                        -1f,
                        1f,
                        imageProxy.width.toFloat(),
                        imageProxy.height.toFloat()
                    )
                }
            }

            val rotatedBitmap = Bitmap.createBitmap(
                bitmapBuffer, 0, 0, bitmapBuffer.width, bitmapBuffer.height,
                matrix, true
            )

            detector.detect(rotatedBitmap)
        }

        cameraProvider.unbindAll()

        try {
            camera = cameraProvider.bindToLifecycle(
                this,
                cameraSelector,
                preview,
                imageAnalyzer
            )
            // Ahora 'binding.viewFinder' se referirá al PreviewView de 'activity_yolo_detection.xml'
            preview?.setSurfaceProvider(binding.viewFinder.surfaceProvider)
        } catch(exc: Exception) {
            Log.e(TAG, "Use case binding failed", exc)
        }
    }

    private fun allPermissionsGranted() = REQUIRED_PERMISSIONS.all {
        ContextCompat.checkSelfPermission(baseContext, it) == PackageManager.PERMISSION_GRANTED
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_CODE_PERMISSIONS) {
            if (allPermissionsGranted()) {
                startCamera()
            } else {
                Log.w(TAG, "Camera permission not granted. Finishing Activity.")
                // Considera mostrar un mensaje al usuario antes de cerrar
                finish()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        detector.clear()
        cameraExecutor.shutdown()
    }

    override fun onResume() {
        super.onResume()
        // Solo inicia la cámara si los permisos están concedidos y la cámara no se ha iniciado ya
        // (cameraProvider es una buena proxy para esto, o simplemente camera == null)
        if (allPermissionsGranted() && camera == null){
            startCamera()
        }
    }

    companion object {
        private const val TAG = "YoloDetectionActivity" // Cambiado para diferenciar logs
        private const val REQUEST_CODE_PERMISSIONS = 10
        private val REQUIRED_PERMISSIONS = arrayOf( // Simplificado a arrayOf
            Manifest.permission.CAMERA
        )
    }

    override fun onEmptyDetect() {
        // 'binding.overlay' se referirá al OverlayView de 'activity_yolo_detection.xml'
        binding.overlay.clear() // Llama al método clear de tu OverlayView si lo tienes
        binding.overlay.invalidate()
    }

    override fun onDetect(boundingBoxes: List<BoundingBox>, inferenceTime: Long) {
        runOnUiThread {
            binding.inferenceTime.text = "${inferenceTime}ms"
            binding.overlay.setResults(boundingBoxes) // Asumiendo que tu OverlayView en Flutter tiene setResults
            binding.overlay.invalidate()
        }
    }
}