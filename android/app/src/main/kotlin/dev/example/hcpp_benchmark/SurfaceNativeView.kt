package dev.example.hcpp_benchmark

import android.content.Context
import android.graphics.Color
import android.graphics.Paint
import android.os.Handler
import android.os.HandlerThread
import android.view.Choreographer
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.util.concurrent.CountDownLatch
import kotlin.math.cos
import kotlin.math.sin

/**
 * 専用スレッドから描画する SurfaceView。
 * 動画プレイヤーや地図 SDK のように、独自の Surface を持つ View を模している。
 *
 * 描画スレッドでは Choreographer を使い、vsync ごとに 1 回だけ描く。
 * vsync を待たずに描き続けると空きバッファ待ちで描画スレッドが止まり、
 * surfaceDestroyed でその終了を待つメインスレッドまで長く止まってしまう。
 */
class SurfaceNativeView(context: Context, private val id: Int) :
    PlatformView, SurfaceHolder.Callback, Choreographer.FrameCallback {

    private val surfaceView = SurfaceView(context)
    private val renderThread = HandlerThread("SurfaceNativeView-$id").apply { start() }
    private val renderHandler = Handler(renderThread.looper)

    // 以下は描画スレッドからのみ触る
    private var holder: SurfaceHolder? = null
    private val dotPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = Color.WHITE
        textSize = 36f
    }
    private var frames = 0
    private var windowStart = 0L
    private var fps = 0

    init {
        surfaceView.holder.addCallback(this)
    }

    override fun getView(): View = surfaceView

    override fun surfaceCreated(holder: SurfaceHolder) {
        renderHandler.post {
            this.holder = holder
            Choreographer.getInstance().postFrameCallback(this)
        }
    }

    override fun surfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {}

    override fun surfaceDestroyed(holder: SurfaceHolder) {
        // このメソッドから戻った後は Surface に描けないので、描画スレッドが止まるのを待つ。
        // 待つのは描画中の 1 フレーム分だけ
        val stopped = CountDownLatch(1)
        val posted = renderHandler.post {
            this.holder = null
            Choreographer.getInstance().removeFrameCallback(this)
            stopped.countDown()
        }
        // dispose() 済みで描画スレッドが終わっていれば、待つ必要はない
        if (posted) stopped.await()
    }

    override fun doFrame(frameTimeNanos: Long) {
        val holder = holder ?: return
        val canvas = holder.lockHardwareCanvas() ?: return
        try {
            val now = System.nanoTime()
            if (windowStart == 0L) windowStart = now
            frames++
            if (now - windowStart >= 1_000_000_000L) {
                fps = frames
                frames = 0
                windowStart = now
            }
            val t = now / 1_000_000_000.0
            canvas.drawColor(Color.rgb(20, 48, 40))
            for (i in 0 until 12) {
                val a = t * 2 + i * Math.PI / 6
                dotPaint.color = Color.HSVToColor(floatArrayOf(i * 30f, 0.7f, 1f))
                canvas.drawCircle(
                    (canvas.width / 2 + cos(a) * canvas.height * 0.32).toFloat(),
                    (canvas.height / 2 + sin(a) * canvas.height * 0.32).toFloat(),
                    18f,
                    dotPaint,
                )
            }
            canvas.drawText("SurfaceView#$id  native: $fps fps", 24f, 48f, textPaint)
        } finally {
            holder.unlockCanvasAndPost(canvas)
        }
        // TLHC では SurfaceView が自分で invalidate しないため手動で通知する（公式ドキュメント参照）
        surfaceView.postInvalidate()
        Choreographer.getInstance().postFrameCallback(this)
    }

    override fun dispose() {
        surfaceView.holder.removeCallback(this)
        renderThread.quitSafely()
    }
}

class SurfaceNativeViewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        SurfaceNativeView(context, viewId)
}
