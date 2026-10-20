package dev.example.hcpp_benchmark

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.view.Choreographer
import android.view.View
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import kotlin.math.sin

/**
 * 毎 vsync で再描画し続ける通常の View。
 * ネイティブ側の描画フレームレートを自分で計測して画面に表示する。
 */
class AnimatedCanvasView(context: Context, private val label: String) :
    View(context), Choreographer.FrameCallback {

    private val barPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = 36f
    }
    private var running = false
    private var framesInWindow = 0
    private var windowStartNanos = 0L
    private var nativeFps = 0

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        running = true
        Choreographer.getInstance().postFrameCallback(this)
    }

    override fun onDetachedFromWindow() {
        running = false
        Choreographer.getInstance().removeFrameCallback(this)
        super.onDetachedFromWindow()
    }

    override fun doFrame(frameTimeNanos: Long) {
        if (!running) return
        invalidate()
        Choreographer.getInstance().postFrameCallback(this)
    }

    override fun onDraw(canvas: Canvas) {
        val now = System.nanoTime()
        if (windowStartNanos == 0L) windowStartNanos = now
        framesInWindow++
        if (now - windowStartNanos >= 1_000_000_000L) {
            nativeFps = framesInWindow
            framesInWindow = 0
            windowStartNanos = now
        }

        canvas.drawColor(Color.rgb(28, 35, 51))
        val t = now / 1_000_000_000.0
        val barCount = 24
        val barWidth = width / barCount.toFloat()
        for (i in 0 until barCount) {
            val h = (0.5 + 0.5 * sin(t * 4 + i * 0.45)) * height * 0.7
            barPaint.color = Color.HSVToColor(floatArrayOf((i * 15f + (t * 60).toFloat()) % 360f, 0.6f, 0.95f))
            canvas.drawRect(i * barWidth + 2, (height - h).toFloat(), (i + 1) * barWidth - 2, height.toFloat(), barPaint)
        }
        canvas.drawText("$label  native: $nativeFps fps", 24f, 48f, textPaint)
    }
}

class AnimatedNativeView(context: Context, id: Int) : PlatformView {
    private val view = AnimatedCanvasView(context, "View#$id")
    override fun getView(): View = view
    override fun dispose() {}
}

class AnimatedNativeViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        AnimatedNativeView(context, viewId)
}
