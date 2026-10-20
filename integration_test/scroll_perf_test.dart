import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hcpp_benchmark/main.dart';
import 'package:hcpp_benchmark/src/benchmark.dart';
import 'package:hcpp_benchmark/src/benchmark_page.dart';
import 'package:hcpp_benchmark/src/device_info.dart';
import 'package:integration_test/integration_test.dart';

/// 例:
/// flutter drive --no-dds --profile --flavor hcpp \
///   --driver=test_driver/perf_driver.dart \
///   --target=integration_test/scroll_perf_test.dart \
///   --dart-define=PV_MODE=textureLayer --dart-define=MAIN_THREAD_LOAD_MS=8
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // 実機の vsync でフレームを回す（テスト用の疑似フレームにしない）
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('platform view scroll performance', (tester) async {
    final device = await DeviceInfo.load();
    final config = BenchmarkConfig.fromEnvironment();
    final finished = Completer<BenchmarkResult>();
    final pageKey = GlobalKey<BenchmarkPageState>();

    await tester.pumpWidget(
      BenchApp(
        home: BenchmarkPage(
          key: pageKey,
          config: config,
          device: device,
          autoStart: false,
          onFinished: finished.complete,
        ),
      ),
    );
    // ネイティブ View の生成を待つ
    await Future<void>.delayed(const Duration(seconds: 2));

    await binding.traceAction(() async {
      unawaited(pageKey.currentState!.run());
      await finished.future;
    }, reportKey: 'scroll_timeline');

    final result = await finished.future;
    binding.reportData!['frame_stats'] = result.toJson();
  });
}
