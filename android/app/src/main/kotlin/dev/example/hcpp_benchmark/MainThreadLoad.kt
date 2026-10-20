package dev.example.hcpp_benchmark

import android.os.SystemClock
import android.view.Choreographer

/**
 * 毎フレーム、メイン（プラットフォーム）スレッドを指定ミリ秒だけビジーにする。
 * 重いプラグインや SDK がメインスレッドで処理している状況を再現するためのもの。
 *
 * 従来の Hybrid Composition ではラスタースレッドがプラットフォームスレッドに
 * マージされるため、この負荷が Flutter のラスタライズ時間に直接響く。
 */
class MainThreadLoad : Choreographer.FrameCallback {
    private var loadMillis = 0

    fun setLoadMillis(millis: Int) {
        val wasRunning = loadMillis > 0
        loadMillis = millis.coerceAtLeast(0)
        if (!wasRunning && loadMillis > 0) {
            Choreographer.getInstance().postFrameCallback(this)
        }
    }

    override fun doFrame(frameTimeNanos: Long) {
        if (loadMillis <= 0) return
        val end = SystemClock.uptimeMillis() + loadMillis
        while (SystemClock.uptimeMillis() < end) {
            // busy wait
        }
        Choreographer.getInstance().postFrameCallback(this)
    }
}
