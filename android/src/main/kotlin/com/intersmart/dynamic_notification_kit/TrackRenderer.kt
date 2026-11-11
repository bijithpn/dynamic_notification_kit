package com.intersmart.dynamic_notification_kit

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF

/** Draws the route line + vehicle at [progress] into a bitmap. */
object TrackRenderer {
    fun track(progress: Float, emoji: String, accent: Int, widthPx: Int = 900, heightPx: Int = 100): Bitmap {
        val bmp = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val pad = heightPx * 0.5f
        val y = heightPx * 0.62f
        val x0 = pad
        val x1 = widthPx - pad
        val p = progress.coerceIn(0f, 1f)
        val xv = x0 + (x1 - x0) * p
        val stroke = heightPx * 0.10f
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            strokeWidth = stroke; strokeCap = Paint.Cap.ROUND
        }
        paint.color = 0x55888888
        c.drawLine(x0, y, x1, y, paint)
        paint.color = accent
        c.drawLine(x0, y, xv, y, paint)
        // origin / destination dots
        paint.style = Paint.Style.FILL
        c.drawCircle(x0, y, stroke * 1.1f, paint)
        paint.color = if (p >= 1f) accent else 0xFF888888.toInt()
        c.drawCircle(x1, y, stroke * 1.1f, paint)
        // vehicle
        val tp = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = heightPx * 0.55f; textAlign = Paint.Align.CENTER }
        c.drawText(emoji, xv, y - stroke * 1.2f, tp)
        return bmp
    }

    /** Square icon with only the vehicle, used as ProgressStyle tracker icon. */
    fun vehicleIcon(emoji: String, sizePx: Int = 96): Bitmap {
        val bmp = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val tp = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = sizePx * 0.8f; textAlign = Paint.Align.CENTER }
        Canvas(bmp).drawText(emoji, sizePx / 2f, sizePx * 0.78f, tp)
        return bmp
    }
}
