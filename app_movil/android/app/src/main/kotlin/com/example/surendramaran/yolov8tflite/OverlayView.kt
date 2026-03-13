package com.example.surendramaran.yolov8tflite

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.util.AttributeSet
import android.view.View
import androidx.core.content.ContextCompat
import com.example.app_movil.R
import java.lang.reflect.Field
import java.lang.reflect.Method

class OverlayView(context: Context?, attrs: AttributeSet?) : View(context, attrs) {

    private var results = listOf<BoundingBox>()
    private var boxPaint = Paint()
    private var textBackgroundPaint = Paint()
    private var textPaint = Paint()
    private var fillPaint = Paint()

    private var bounds = Rect()

    init {
        initPaints()
    }

    fun clear() {
        results = emptyList()
        invalidate()
    }

    private fun initPaints() {
        boxPaint.color = ContextCompat.getColor(context!!, R.color.bounding_box_color)
        boxPaint.strokeWidth = 4F
        boxPaint.style = Paint.Style.STROKE
        boxPaint.isAntiAlias = true

        fillPaint.color = Color.argb(20, 255, 20, 147)
        fillPaint.style = Paint.Style.FILL

        textBackgroundPaint.color = Color.argb(180, 255, 20, 147)
        textBackgroundPaint.style = Paint.Style.FILL
        textBackgroundPaint.textSize = 28f

        textPaint.color = Color.WHITE
        textPaint.style = Paint.Style.FILL
        textPaint.textSize = 28f
        textPaint.isAntiAlias = true
        textPaint.typeface = android.graphics.Typeface.DEFAULT_BOLD
    }

    override fun draw(canvas: Canvas) {
        super.draw(canvas)

        results.forEach { box ->
            val left = box.x1 * width
            val top = box.y1 * height
            val right = box.x2 * width
            val bottom = box.y2 * height

            canvas.drawRect(left, top, right, bottom, fillPaint)
            canvas.drawRect(left, top, right, bottom, boxPaint)

            // Texto seguro que funciona con o sin score
            val confidencePercentage = box.cnf * 100
            val drawableText = "${box.clsName} ${"%.2f".format(confidencePercentage)}%"

            textPaint.getTextBounds(drawableText, 0, drawableText.length, bounds)

            val textWidth = bounds.width()
            val textHeight = bounds.height()
            val textPadding = 6f

            val textBackgroundRect = RectF(
                left,
                top,
                left + textWidth + textPadding * 2,
                top + textHeight + textPadding * 2
            )
            canvas.drawRoundRect(textBackgroundRect, 10f, 10f, textBackgroundPaint)

            canvas.drawText(
                drawableText,
                left + textPadding,
                top + textHeight + textPadding,
                textPaint
            )
        }
    }

    fun setResults(boundingBoxes: List<BoundingBox>) {
        results = boundingBoxes
        invalidate()
    }
}