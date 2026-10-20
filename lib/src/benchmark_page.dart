import 'dart:async';

import 'package:flutter/material.dart';

import 'bench_platform_view.dart';
import 'benchmark.dart';
import 'device_info.dart';
import 'frame_stats.dart';

/// ネイティブ View と Flutter ウィジェットが交互に並ぶリストを自動スクロールし、
/// その間の FrameTiming を集計する。
class BenchmarkPage extends StatefulWidget {
  const BenchmarkPage({
    super.key,
    required this.config,
    required this.device,
    this.autoStart = true,
    this.onFinished,
  });

  static const listKey = ValueKey('benchmark-list');

  final BenchmarkConfig config;
  final DeviceInfo device;
  final bool autoStart;
  final ValueChanged<BenchmarkResult>? onFinished;

  @override
  State<BenchmarkPage> createState() => BenchmarkPageState();
}

class BenchmarkPageState extends State<BenchmarkPage> {
  static const _itemCount = 60;
  static const _scrollSpeedPxPerSec = 1800.0;

  final _scrollController = ScrollController();
  final _recorder = FrameStatsRecorder();
  BenchmarkResult? _result;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      // ネイティブ View の生成が落ち着いてから計測を始める
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (mounted) run();
      });
    }
  }

  @override
  void dispose() {
    setMainThreadLoad(0);
    _scrollController.dispose();
    super.dispose();
  }

  Future<BenchmarkResult> run() async {
    setState(() {
      _running = true;
      _result = null;
    });
    await setMainThreadLoad(widget.config.mainThreadLoadMs);
    _recorder.start();

    final deadline = DateTime.now().add(widget.config.duration);
    var down = true;
    while (mounted && DateTime.now().isBefore(deadline)) {
      final position = _scrollController.position;
      final from = position.pixels;
      var to = down ? position.maxScrollExtent : 0.0;
      final remainingMs = deadline.difference(DateTime.now()).inMilliseconds;
      var sweepMs = ((to - from).abs() / _scrollSpeedPxPerSec * 1000).round();
      if (sweepMs > remainingMs) {
        // 計測時間内に端まで届かない場合は、同じ速度のまま途中で止める
        to = from + (to - from) * remainingMs / sweepMs;
        sweepMs = remainingMs;
      }
      if (sweepMs > 0) {
        await _scrollController.animateTo(
          to,
          duration: Duration(milliseconds: sweepMs),
          curve: Curves.linear,
        );
      }
      down = !down;
    }

    final stats = await _recorder.stop(frameBudget: widget.device.frameBudget);
    await setMainThreadLoad(0);
    final result = BenchmarkResult(config: widget.config, device: widget.device, stats: stats)
      ..log();
    benchmarkResults.value = [...benchmarkResults.value, result];
    widget.onFinished?.call(result);
    if (mounted) {
      setState(() {
        _running = false;
        _result = result;
      });
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.config;
    return Scaffold(
      appBar: AppBar(
        title: Text('${config.effectiveMode(widget.device)} / ${config.kind.label}'),
        actions: [
          if (!_running) IconButton(icon: const Icon(Icons.replay), tooltip: '再計測', onPressed: run),
        ],
      ),
      body: Stack(
        children: [
          ListView.builder(
            key: BenchmarkPage.listKey,
            controller: _scrollController,
            itemCount: _itemCount,
            itemBuilder: (context, index) => index.isEven
                ? _NativeTile(config: config, index: index)
                : _FlutterTile(index: index),
          ),
          if (_running) const _RunningBanner(),
          if (_result case final result?) _ResultSheet(result: result),
        ],
      ),
    );
  }
}

class _NativeTile extends StatelessWidget {
  const _NativeTile({required this.config, required this.index});

  final BenchmarkConfig config;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: SizedBox(
        height: 220,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              BenchPlatformView(mode: config.mode, kind: config.kind),
              // ネイティブ View の上に Flutter を重ねる → HC / HCPP ではオーバーレイ層が必要になる
              if (config.overlay) const Positioned(right: 16, bottom: 16, child: _SpinningBadge()),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlutterTile extends StatelessWidget {
  const _FlutterTile({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Flutter tile #$index', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            // ラスタライズ負荷を少し上げるため、影付きのチップを並べる
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < 8; i++)
                  Chip(
                    elevation: 2,
                    backgroundColor: scheme.secondaryContainer,
                    label: Text('item ${index * 8 + i}'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _SpinningBadge extends StatefulWidget {
  const _SpinningBadge();

  @override
  State<_SpinningBadge> createState() => _SpinningBadgeState();
}

class _SpinningBadgeState extends State<_SpinningBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.deepPurple.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.flutter_dash, color: Colors.white, size: 36),
      ),
    );
  }
}

class _RunningBanner extends StatelessWidget {
  const _RunningBanner();

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      top: 8,
      left: 0,
      right: 0,
      child: Center(
        child: Chip(avatar: Icon(Icons.timer, size: 18), label: Text('計測中…')),
      ),
    );
  }
}

class _ResultSheet extends StatelessWidget {
  const _ResultSheet({required this.result});

  final BenchmarkResult result;

  @override
  Widget build(BuildContext context) {
    final s = result.stats;
    String f(double v) => v.toStringAsFixed(1);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Card(
        margin: const EdgeInsets.all(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('結果: ${result.effectiveMode}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('FPS ${f(s.fps)}  /  ジャンク ${s.jankCount} 件 (${f(s.jankRate * 100)}%)'),
                Text(
                  'build 平均 ${f(s.avgBuildMs)} ms  /  ラスタライズ平均 ${f(s.avgRasterMs)} ms (p90 ${f(s.p90RasterMs)})',
                ),
                Text(
                  'totalSpan p50 ${f(s.p50TotalMs)} / p90 ${f(s.p90TotalMs)} / p99 ${f(s.p99TotalMs)} / 最大 ${f(s.worstTotalMs)} ms',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
