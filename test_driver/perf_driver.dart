import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// `build/$SUMMARY_NAME.timeline_summary.json` と `build/$SUMMARY_NAME.frame_stats.json` を書き出す。
Future<void> main() {
  final name = Platform.environment['SUMMARY_NAME'] ?? 'scroll_perf';
  return integrationDriver(
    responseDataCallback: (data) async {
      if (data == null) return;
      final timeline = driver.Timeline.fromJson(data['scroll_timeline'] as Map<String, dynamic>);
      final summary = driver.TimelineSummary.summarize(timeline);
      await summary.writeTimelineToFile(name, pretty: true, includeSummary: true);
      await File(
        'build/$name.frame_stats.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(data['frame_stats']));
    },
  );
}
