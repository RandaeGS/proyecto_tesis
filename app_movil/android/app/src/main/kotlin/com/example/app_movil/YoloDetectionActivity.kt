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
import com.example.app_movil.databinding.ActivityMainBinding
import com.example.surendramaran.yolov8tflite.BoundingBox
import com.example.surendramaran.yolov8tflite.Constants.LABELS_PATH
import com.example.surendramaran.yolov8tflite.Constants.MODEL_PATH
import com.example.surendramaran.yolov8tflite.Detector
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit // Necesario para awaitTermination
import java.util.concurrent.atomic.AtomicBoolean // Para flags thread-safe

class YoloDetectionActivity : AppCompatActivity(), Detector.DetectorListener {
    private lateinit var binding: ActivityMainBinding
    private val isFrontCamera = false

    private var preview: Preview? = null
    private var imageAnalyzer: ImageAnalysis? = null
    private var camera: Camera? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private lateinit var detector: Detector

    private lateinit var cameraExecutor: ExecutorService
    private val isActivityDestroying = AtomicBoolean(false) // Flag para indicar si la actividad se está destruyendo

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        Log.d(TAG, "onCreate called")

        detector = Detector(baseContext, MODEL_PATH, LABELS_PATH, this)
        detector.setup()

        cameraExecutor = Executors.newSingleThreadExecutor()

        // Los permisos se solicitan en onResume si es necesario
    }

    private fun startCamera() {
        Log.d(TAG, "startCamera called")
        isActivityDestroying.set(false) // Asegurarse que el flag esté en false al iniciar/reiniciar la cámara
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)
        cameraProviderFuture.addListener({
            try {
                cameraProvider = cameraProviderFuture.get()
                bindCameraUseCases()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get camera provider", e)
            }
        }, ContextCompat.getMainExecutor(this))
    }

    private fun bindCameraUseCases() {
        val localCameraProvider = cameraProvider ?: run {
            Log.e(TAG, "Camera initialization failed: cameraProvider is null.")
            return
        }
        Log.d(TAG, "bindCameraUseCases called")

        val rotation = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            binding.viewFinder.display?.rotation ?: display?.rotation ?: Surface.ROTATION_0
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay?.rotation ?: Surface.ROTATION_0
        }

        val cameraSelector = CameraSelector.Builder()
            .requireLensFacing(CameraSelector.LENS_FACING_BACK)
            .build()

        preview = Preview.Builder()
            .setTargetAspectRatio(AspectRatio.RATIO_4_3)
            .setTargetRotation(rotation)
            .build()

        imageAnalyzer = ImageAnalysis.Builder()
            .setTargetAspectRatio(AspectRatio.RATIO_4_3)
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .setTargetRotation(rotation)
            .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
            .build()

        imageAnalyzer?.setAnalyzer(cameraExecutor) { imageProxy ->
            if (isActivityDestroying.get()) { // Comprobar ANTES de cualquier procesamiento
                imageProxy.close()
                return@setAnalyzer
            }

            val bitmapBuffer = Bitmap.createBitmap(
                imageProxy.width,
                imageProxy.height,
                Bitmap.Config.ARGB_8888
            )
            imageProxy.use { // Esto cierra imageProxy automáticamente
                bitmapBuffer.copyPixelsFromBuffer(it.planes[0].buffer)
            }

            val matrix = Matrix().apply {
                postRotate(imageProxy.imageInfo.rotationDegrees.toFloat())
                if (isFrontCamera) {
                    postScale(-1f, 1f, imageProxy.width.toFloat(), imageProxy.height.toFloat())
                }
            }
            val rotatedBitmap = Bitmap.createBitmap(
                bitmapBuffer, 0, 0, bitmapBuffer.width, bitmapBuffer.height, matrix, true
            )

            if (isActivityDestroying.get()) { // Doble chequeo por si el flag cambió durante el preprocesamiento
                return@setAnalyzer
            }
            detector.detect(rotatedBitmap)
        }

        localCameraProvider.unbindAll() // Desvincular antes de volver a vincular

        try {
            camera = localCameraProvider.bindToLifecycle(
                this,
                cameraSelector,
                preview,
                imageAnalyzer
            )
            preview?.setSurfaceProvider(binding.viewFinder.surfaceProvider)
            Log.d(TAG, "Camera use cases bound successfully")
        } catch (exc: Exception) {
            Log.e(TAG, "Use case binding failed", exc)
        }
    }

    private fun allPermissionsGranted() = REQUIRED_PERMISSIONS.all {
        ContextCompat.checkSelfPermission(baseContext, it) == PackageManager.PERMISSION_GRANTED
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        Log.d(TAG, "onRequestPermissionsResult called. RequestCode: $requestCode")
        if (requestCode == REQUEST_CODE_PERMISSIONS) {
            if (allPermissionsGranted()) {
                Log.i(TAG, "Camera permission granted. Starting camera.")
                startCamera()
            } else {
                Log.e(TAG, "Camera permission not granted. Finishing activity.")
                // Podrías mostrar un mensaje al usuario aquí antes de cerrar.
                finish()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume called")
        isActivityDestroying.set(false) // Marcar que la actividad está activa
        if (allPermissionsGranted()) {
            startCamera()
        } else {
            ActivityCompat.requestPermissions(this, REQUIRED_PERMISSIONS, REQUEST_CODE_PERMISSIONS)
        }
    }

    override fun onPause() {
        super.onPause()
        Log.d(TAG, "onPause called")
        // Es una buena práctica desvincular los casos de uso aquí para liberar la cámara
        // cuando la actividad no está en primer plano.
        // Si no se hace aquí, el flag isActivityDestroying es aún más crucial.
        cameraProvider?.unbindAll()
        Log.d(TAG, "Camera use cases unbound in onPause.")
        // No establecer isActivityDestroying a true aquí, solo cuando realmente se destruye.
    }


    override fun onDestroy() {
        Log.d(TAG, "onDestroy: Setting isActivityDestroying to true.")
        isActivityDestroying.set(true) // 1. Marcar que la actividad se está destruyendo

        // 2. Desvincular explícitamente aquí también por si onPause no se llamó o falló
        Log.d(TAG, "onDestroy: Unbinding camera use cases.")
        cameraProvider?.unbindAll() // Ayuda a detener el flujo de ImageAnalysis

        Log.d(TAG, "onDestroy: Shutting down cameraExecutor.")
        cameraExecutor.shutdown() // 3. Iniciar el apagado del executor
        try {
            // Esperar a que las tareas existentes terminen por un tiempo limitado
            if (!cameraExecutor.awaitTermination(1000, TimeUnit.MILLISECONDS)) {
                Log.w(TAG, "onDestroy: Camera executor did not terminate in time, forcing shutdownNow.")
                cameraExecutor.shutdownNow() // Forzar si no terminaron
            } else {
                Log.d(TAG, "onDestroy: Camera executor terminated gracefully.")
            }
        } catch (e: InterruptedException) {
            Log.w(TAG, "onDestroy: Interrupted while waiting for camera executor, forcing shutdownNow.")
            cameraExecutor.shutdownNow()
            Thread.currentThread().interrupt() // Re-establecer el flag de interrupción
        }

        Log.d(TAG, "onDestroy: Clearing detector.")
        detector.clear() // 4. Limpiar el detector SÓLO DESPUÉS de que el executor se haya detenido

        super.onDestroy() // 5. Llamar al super método al final
        Log.d(TAG, "onDestroy: Completed.")
    }

    companion object {
        private const val TAG = "YoloDetectionActivity"
        private const val REQUEST_CODE_PERMISSIONS = 10
        private val REQUIRED_PERMISSIONS = arrayOf(Manifest.permission.CAMERA)
    }

    override fun onEmptyDetect() {
        if (isActivityDestroying.get()) return // Evitar actualizaciones de UI si se está destruyendo
        binding.overlay.clear()
        binding.overlay.invalidate()
    }

    override fun onDetect(boundingBoxes: List<BoundingBox>, inferenceTime: Long) {
        if (isActivityDestroying.get()) return // Evitar actualizaciones de UI si se está destruyendo
        runOnUiThread {
            binding.inferenceTime.text = "${inferenceTime}ms"
            binding.overlay.setResults(boundingBoxes)
            binding.overlay.invalidate()
        }
    }
}