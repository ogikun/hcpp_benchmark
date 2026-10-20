import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'composition_mode.dart';
import 'device_info.dart';
import 'frame_stats.dart';

class BenchmarkConfig {
  const BenchmarkConfig({
    this.mode = CompositionMode.textureLayer,
    this.kind = NativeViewKind.animated,
    this.mainThreadLoadMs = 0,
    this.overlay = true,
    this.duration = const Duration(seconds: 15),
  });

  /// integration_test から `--dart-define` で条件を渡すためのコンストラクタ。
  factory BenchmarkConfig.fromEnvironment() {
    const mode = String.fromEnvironment('PV_MODE', defaultValue: 'textureLayer');
    const kind = String.fromEnvironment('PV_KIND', defaultValue: 'animated');
    return BenchmarkConfig(
      mode: CompositionMode.values.byName(mode),
      kind: NativeViewKind.values.byName(kind),
      mainThreadLoadMs: const int.fromEnvironment('MAIN_THREAD_LOAD_MS'),
      overlay: const bool.fromEnvironment('OVERLAY', defaultValue: true),
      duration: const Duration(seconds: int.fromEnvironment('DURATION_SEC', defaultValue: 15)),
    );
  }

  final CompositionMode mode;
  final NativeViewKind kind;
  final int mainThreadLoadMs;
  final bool overlay;
  final Duration duration;

  BenchmarkConfig copyWith({
    CompositionMode? mode,
    NativeViewKind? kind,
    int? mainThreadLoadMs,
    bool? overlay,
  }) {
    return BenchmarkConfig(
      mode: mode ?? this.mode,
      kind: kind ?? this.kind,
      mainThreadLoadMs: mainThreadLoadMs ?? this.mainThreadLoadMs,
      overlay: overlay ?? this.overlay,
      duration: duration,
    );
  }

  /// 実際に使われる合成方式。HCPP が有効なら旧 API の生成リクエストも HCPP になる。
  String effectiveMode(DeviceInfo device) => device.hcppActive ? 'HCPP' : mode.shortName;

  Map<String, Object?> toJson() => {
    'api': mode.apiName,
    'nativeView': kind.name,
    'mainThreadLoadMs': mainThreadLoadMs,
    'overlay': overlay,
  };
}

class BenchmarkResult {
  BenchmarkResult({required this.config, required this.device, required this.stats})
    : timestamp = DateTime.now();

  final BenchmarkConfig config;
  final DeviceInfo device;
  final FrameStats stats;
  final DateTime timestamp;

  String get effectiveMode => config.effectiveMode(device);

  Map<String, Object?> toJson() => {
    'effectiveMode': effectiveMode,
    'config': config.toJson(),
    'device': device.toJson(),
    'stats': stats.toJson(),
    'timestamp': timestamp.toIso8601String(),
  };

  /// `adb logcat | grep HCPP_BENCH` で拾えるように 1 行 JSON で出力する。
  void log() => debugPrint('HCPP_BENCH ${jsonEncode(toJson())}');
}

/// このアプリ起動中に取った計測結果。
final ValueNotifier<List<BenchmarkResult>> benchmarkResults = ValueNotifier([]);
