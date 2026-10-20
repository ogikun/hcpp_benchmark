import 'dart:convert';
import 'dart:io';

/// `build/*.frame_stats.json` を読み、記事の「計測結果」の表の行（Markdown）を出力する。
/// 同じ条件を複数回計測した場合は、各値の中央値を使う。
///
/// 使い方: dart run tool/summarize.dart
void main() {
  final files = Directory('build')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.frame_stats.json'))
      .toList();
  if (files.isEmpty) {
    stderr.writeln('build/*.frame_stats.json が見つかりません。先に tool/run_all.sh を実行してください。');
    exitCode = 1;
    return;
  }

  // 条件ごとに結果をまとめる
  final groups = <String, List<Map<String, dynamic>>>{};
  Map<String, dynamic>? device;
  for (final file in files) {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final config = json['config'] as Map<String, dynamic>;
    final key = [json['effectiveMode'], config['nativeView'], config['mainThreadLoadMs']].join('|');
    groups.putIfAbsent(key, () => []).add(json);
    device ??= json['device'] as Map<String, dynamic>;
  }

  stdout.writeln(
    '計測環境：${device!['device']} / API ${device['sdkInt']} / '
    '${(device['refreshRate'] as num).round()} Hz',
  );
  stdout.writeln();
  stdout.writeln('| 方式 | View の種類 | メインスレッドの負荷 | FPS | ラスタライズ平均 (ms) | 合計時間 p50 (ms) | 合計時間 p99 (ms) | ジャンク率 | 回数 |');
  stdout.writeln('| --- | --- | --- | --- | --- | --- | --- | --- | --- |');
  for (final MapEntry(:key, :value) in groups.entries.toList()..sort((a, b) => _order(a.key).compareTo(_order(b.key)))) {
    final [mode, kind, load] = key.split('|');
    double med(String field) => _median([for (final r in value) (r['stats'][field] as num).toDouble()]);
    final kindLabel = kind == 'surface' ? 'SurfaceView' : '通常の View';
    stdout.writeln(
      '| $mode | $kindLabel | $load ms | ${med('fps').toStringAsFixed(1)} | '
      '${med('avgRasterMs').toStringAsFixed(1)} | ${med('p50TotalMs').toStringAsFixed(1)} | ${med('p99TotalMs').toStringAsFixed(1)} | '
      '${med('jankRate').toStringAsFixed(1)}% | ${value.length} |',
    );
  }
}

/// 記事の表と同じ順（View の種類 → 負荷 → 方式）に並べる
String _order(String key) {
  final [mode, kind, load] = key.split('|');
  const modes = ['TLHC', 'HC', 'HCPP'];
  return '${kind == 'surface' ? 1 : 0}|${load.padLeft(3, '0')}|${modes.indexOf(mode)}';
}

double _median(List<double> values) {
  values.sort();
  final mid = values.length ~/ 2;
  return values.length.isOdd ? values[mid] : (values[mid - 1] + values[mid]) / 2;
}
