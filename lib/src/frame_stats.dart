import 'dart:math' as math;

import 'package:flutter/scheduler.dart';

/// [SchedulerBinding.addTimingsCallback] で FrameTiming を収集する。
///
/// FrameTiming はエンジンからまとめて（profile/release で約 100ms ごとに）届くため、
/// 停止前に少し待ってから集計する。
class FrameStatsRecorder {
  final List<FrameTiming> _timings = [];
  final Stopwatch _stopwatch = Stopwatch();

  void start() {
    _timings.clear();
    _stopwatch
      ..reset()
      ..start();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  Future<FrameStats> stop({required Duration frameBudget}) async {
    _stopwatch.stop();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    return FrameStats.fromTimings(_timings, elapsed: _stopwatch.elapsed, frameBudget: frameBudget);
  }

  void _onTimings(List<FrameTiming> timings) => _timings.addAll(timings);
}

class FrameStats {
  const FrameStats({
    required this.frameCount,
    required this.elapsed,
    required this.frameBudget,
    required this.avgBuildMs,
    required this.avgRasterMs,
    required this.p90RasterMs,
    required this.p50TotalMs,
    required this.p90TotalMs,
    required this.p99TotalMs,
    required this.worstTotalMs,
    required this.jankCount,
  });

  factory FrameStats.fromTimings(
    List<FrameTiming> timings, {
    required Duration elapsed,
    required Duration frameBudget,
  }) {
    double ms(Duration d) => d.inMicroseconds / 1000;
    final build = timings.map((t) => ms(t.buildDuration)).toList();
    final raster = timings.map((t) => ms(t.rasterDuration)).toList()..sort();
    // totalSpan = vsync 開始 〜 ラスタライズ完了。ユーザーが体感する遅延に最も近い
    final total = timings.map((t) => ms(t.totalSpan)).toList()..sort();
    final budgetMs = ms(frameBudget);

    return FrameStats(
      frameCount: timings.length,
      elapsed: elapsed,
      frameBudget: frameBudget,
      avgBuildMs: _avg(build),
      avgRasterMs: _avg(raster),
      p90RasterMs: _percentile(raster, 0.90),
      p50TotalMs: _percentile(total, 0.50),
      p90TotalMs: _percentile(total, 0.90),
      p99TotalMs: _percentile(total, 0.99),
      worstTotalMs: total.isEmpty ? 0 : total.last,
      jankCount: total.where((t) => t > budgetMs).length,
    );
  }

  final int frameCount;
  final Duration elapsed;
  final Duration frameBudget;
  final double avgBuildMs;
  final double avgRasterMs;
  final double p90RasterMs;
  final double p50TotalMs;
  final double p90TotalMs;
  final double p99TotalMs;
  final double worstTotalMs;

  /// totalSpan がフレーム予算（1 / リフレッシュレート）を超えたフレーム数。
  final int jankCount;

  double get fps => elapsed.inMicroseconds == 0 ? 0 : frameCount / (elapsed.inMicroseconds / 1e6);
  double get jankRate => frameCount == 0 ? 0 : jankCount / frameCount;

  Map<String, Object?> toJson() => {
    'frames': frameCount,
    'elapsedSec': _round(elapsed.inMilliseconds / 1000),
    'budgetMs': _round(frameBudget.inMicroseconds / 1000),
    'fps': _round(fps),
    'avgBuildMs': _round(avgBuildMs),
    'avgRasterMs': _round(avgRasterMs),
    'p90RasterMs': _round(p90RasterMs),
    'p50TotalMs': _round(p50TotalMs),
    'p90TotalMs': _round(p90TotalMs),
    'p99TotalMs': _round(p99TotalMs),
    'worstTotalMs': _round(worstTotalMs),
    'jankCount': jankCount,
    'jankRate': _round(jankRate * 100),
  };

  static double _avg(List<double> values) =>
      values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

  static double _percentile(List<double> sorted, double p) {
    if (sorted.isEmpty) return 0;
    final index = math.min(sorted.length - 1, (sorted.length * p).ceil() - 1);
    return sorted[math.max(0, index)];
  }

  static double _round(double v) => (v * 100).roundToDouble() / 100;
}
