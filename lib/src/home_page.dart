import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'benchmark.dart';
import 'benchmark_page.dart';
import 'composition_mode.dart';
import 'device_info.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<DeviceInfo> _device = DeviceInfo.load();
  var _config = const BenchmarkConfig();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Platform View Bench')),
      body: FutureBuilder<DeviceInfo>(
        future: _device,
        builder: (context, snapshot) {
          final device = snapshot.data;
          if (device == null) {
            return Center(
              child: snapshot.hasError
                  ? Text('端末情報の取得に失敗しました: ${snapshot.error}')
                  : const CircularProgressIndicator(),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _DeviceCard(device: device),
              const SizedBox(height: 16),
              _ConfigSection(
                config: _config,
                device: device,
                onChanged: (config) => setState(() => _config = config),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: Text('計測開始（${_config.duration.inSeconds} 秒）'),
                onPressed: _config.mode == CompositionMode.hcpp && !device.hcppActive
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BenchmarkPage(config: _config, device: device),
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              const _ResultsTable(),
            ],
          );
        },
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device});

  final DeviceInfo device;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final String reason;
    if (device.hcppActive) {
      reason = 'すべての PlatformView が HCPP で合成されます';
    } else if (!device.hcppMetaData) {
      reason = 'マニフェストで opt-in されていません（legacy フレーバー）';
    } else if (device.sdkInt < 34) {
      reason = 'API ${device.sdkInt} のため従来方式にフォールバックしています（要 API 34+）';
    } else {
      reason = 'Vulkan (Impeller) が使えないため従来方式にフォールバックしています';
    }
    return Card(
      color: device.hcppActive ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      child: ListTile(
        leading: Icon(device.hcppActive ? Icons.check_circle : Icons.info_outline),
        title: Text('HCPP: ${device.hcppActive ? '有効' : '無効'}'),
        subtitle: Text(
          '$reason\n'
          '${device.manufacturer} ${device.model} / API ${device.sdkInt} / '
          '${device.refreshRate.toStringAsFixed(0)} Hz',
        ),
        isThreeLine: true,
      ),
    );
  }
}

class _ConfigSection extends StatelessWidget {
  const _ConfigSection({required this.config, required this.device, required this.onChanged});

  final BenchmarkConfig config;
  final DeviceInfo device;
  final ValueChanged<BenchmarkConfig> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('生成 API', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<CompositionMode>(
          segments: [
            for (final mode in CompositionMode.values)
              ButtonSegment(
                value: mode,
                label: Text(mode.shortName),
                enabled: mode != CompositionMode.hcpp || device.hcppActive,
              ),
          ],
          selected: {config.mode},
          onSelectionChanged: (s) => onChanged(config.copyWith(mode: s.single)),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${config.mode.apiName} → 実効: ${config.effectiveMode(device)}',
            style: textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 16),
        Text('ネイティブ View', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<NativeViewKind>(
          segments: [
            for (final kind in NativeViewKind.values)
              ButtonSegment(value: kind, label: Text(kind.label)),
          ],
          selected: {config.kind},
          onSelectionChanged: (s) => onChanged(config.copyWith(kind: s.single)),
        ),
        const SizedBox(height: 16),
        Text('メインスレッド負荷（毎フレーム）', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: [
            for (final ms in const [0, 4, 8, 12]) ButtonSegment(value: ms, label: Text('$ms ms')),
          ],
          selected: {config.mainThreadLoadMs},
          onSelectionChanged: (s) => onChanged(config.copyWith(mainThreadLoadMs: s.single)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('ネイティブ View の上に Flutter を重ねる'),
          value: config.overlay,
          onChanged: (v) => onChanged(config.copyWith(overlay: v)),
        ),
      ],
    );
  }
}

class _ResultsTable extends StatelessWidget {
  const _ResultsTable();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<BenchmarkResult>>(
      valueListenable: benchmarkResults,
      builder: (context, results, _) {
        if (results.isEmpty) return const SizedBox.shrink();
        String f(double v) => v.toStringAsFixed(1);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('計測結果', style: Theme.of(context).textTheme.titleSmall)),
                TextButton.icon(
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('JSON をコピー'),
                  onPressed: () {
                    final json = jsonEncode([for (final r in results) r.toJson()]);
                    Clipboard.setData(ClipboardData(text: json));
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('コピーしました')));
                  },
                ),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('方式')),
                  DataColumn(label: Text('View')),
                  DataColumn(label: Text('負荷'), numeric: true),
                  DataColumn(label: Text('FPS'), numeric: true),
                  DataColumn(label: Text('ラスタライズ平均'), numeric: true),
                  DataColumn(label: Text('p99'), numeric: true),
                  DataColumn(label: Text('ジャンク率'), numeric: true),
                ],
                rows: [
                  for (final r in results)
                    DataRow(
                      cells: [
                        DataCell(Text(r.effectiveMode)),
                        DataCell(Text(r.config.kind.label)),
                        DataCell(Text('${r.config.mainThreadLoadMs} ms')),
                        DataCell(Text(f(r.stats.fps))),
                        DataCell(Text('${f(r.stats.avgRasterMs)} ms')),
                        DataCell(Text('${f(r.stats.p99TotalMs)} ms')),
                        DataCell(Text('${f(r.stats.jankRate * 100)}%')),
                      ],
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
