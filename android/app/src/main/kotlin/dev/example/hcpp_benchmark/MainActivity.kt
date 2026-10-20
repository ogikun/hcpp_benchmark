package dev.example.hcpp_benchmark

import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.Display
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val mainThreadLoad = MainThreadLoad()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Dart 側の viewType と 1:1 で対応させる
        flutterEngine.platformViewsController.registry.apply {
            registerViewFactory(ANIMATED_VIEW_TYPE, AnimatedNativeViewFactory())
            registerViewFactory(SURFACE_VIEW_TYPE, SurfaceNativeViewFactory())
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDeviceInfo" -> result.success(deviceInfo())
                    "setMainThreadLoad" -> {
                        mainThreadLoad.setLoadMillis(call.argument<Int>("millis") ?: 0)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 可変リフレッシュレートの端末で計測ごとに条件が変わらないよう、最大のリフレッシュレートを要求する
        maxRefreshMode()?.let { mode ->
            window.attributes = window.attributes.apply { preferredDisplayModeId = mode.modeId }
        }
    }

    override fun onDestroy() {
        mainThreadLoad.setLoadMillis(0)
        super.onDestroy()
    }

    private fun deviceInfo(): Map<String, Any?> {
        val appInfo = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
        return mapOf(
            "sdkInt" to Build.VERSION.SDK_INT,
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            // 起動時点の値は可変リフレッシュレートで揺れるので、要求した最大値を返す
            "refreshRate" to (maxRefreshMode()?.refreshRate ?: display?.refreshRate)?.toDouble(),
            // マニフェストに書いた値。実際に HCPP が有効かは Dart 側の checkIfSupported() で確認する
            "hcppMetaData" to appInfo.metaData?.getBoolean(HCPP_META_DATA, false),
        )
    }

    /** 現在の解像度で選べる、リフレッシュレートが最大の表示モード。 */
    private fun maxRefreshMode(): Display.Mode? {
        val display = display ?: return null
        val current = display.mode
        return display.supportedModes
            .filter { it.physicalWidth == current.physicalWidth && it.physicalHeight == current.physicalHeight }
            .maxByOrNull { it.refreshRate }
    }

    companion object {
        const val ANIMATED_VIEW_TYPE = "hcpp-bench/animated-view"
        const val SURFACE_VIEW_TYPE = "hcpp-bench/surface-view"
        const val DEVICE_CHANNEL = "hcpp_bench/device"
        const val HCPP_META_DATA = "io.flutter.embedding.android.EnableHcpp"
    }
}
