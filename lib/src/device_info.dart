import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('hcpp_bench/device');

/// 端末情報と、HCPP が実際に有効になっているか。
class DeviceInfo {
  const DeviceInfo({
    required this.sdkInt,
    required this.manufacturer,
    required this.model,
    required this.refreshRate,
    required this.hcppMetaData,
    required this.hcppActive,
  });

  final int sdkInt;
  final String manufacturer;
  final String model;
  final double refreshRate;

  /// AndroidManifest の `io.flutter.embedding.android.EnableHcpp` の値。
  final bool hcppMetaData;

  /// `HybridAndroidViewController.checkIfSupported()` の結果。
  /// opt-in 済み、かつ API 34+ / Vulkan(Impeller) の条件を満たしたときだけ true。
  final bool hcppActive;

  Duration get frameBudget => Duration(microseconds: (1e6 / refreshRate).round());

  static Future<DeviceInfo> load() async {
    final map = await _channel.invokeMapMethod<String, Object?>('getDeviceInfo') ?? {};
    var hcppActive = false;
    try {
      hcppActive = await HybridAndroidViewController.checkIfSupported();
    } on PlatformException catch (e) {
      debugPrint('checkIfSupported failed: $e');
    }
    return DeviceInfo(
      sdkInt: map['sdkInt'] as int? ?? 0,
      manufacturer: map['manufacturer'] as String? ?? '',
      model: map['model'] as String? ?? '',
      refreshRate: (map['refreshRate'] as double?) ?? 60,
      hcppMetaData: map['hcppMetaData'] as bool? ?? false,
      hcppActive: hcppActive,
    );
  }

  Map<String, Object?> toJson() => {
    'sdkInt': sdkInt,
    'device': '$manufacturer $model',
    'refreshRate': refreshRate,
    'hcppMetaData': hcppMetaData,
    'hcppActive': hcppActive,
  };
}

/// 毎フレーム、メインスレッドを [millis] ミリ秒ビジーにする（0 で停止）。
Future<void> setMainThreadLoad(int millis) =>
    _channel.invokeMethod<void>('setMainThreadLoad', {'millis': millis});
