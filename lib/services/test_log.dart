import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/app_state.dart';

/// Testing mode: records every alert and the tester's verdict (correct / wrong)
/// to a CSV file, for measuring accuracy, false alarms and response time.
class TestLog {
  TestLog._();
  static final TestLog I = TestLog._();

  /// The last logged event, so the tester can mark it correct or wrong.
  String? lastModule, lastEvent;
  final Map<String, int> correct = {}, wrong = {};

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/gabay_test_log.csv');
    if (!await f.exists()) {
      await f.writeAsString('timestamp,module,event,label,score,latency_ms,verdict\n');
    }
    return f;
  }

  static String _q(String s) => '"${s.replaceAll('"', "'")}"';

  Future<void> log(String module, String event, {String label = '', double? score, int? latencyMs, String verdict = ''}) async {
    if (!AppState.I.testMode) return;
    if (verdict.isEmpty) {
      lastModule = module;
      lastEvent = event;
    }
    final f = await _file();
    final line = [
      DateTime.now().toIso8601String(),
      module,
      _q(event),
      _q(label),
      score?.toStringAsFixed(3) ?? '',
      latencyMs?.toString() ?? '',
      verdict,
    ].join(',');
    await f.writeAsString('$line\n', mode: FileMode.append);
  }

  /// Tester marks the last alert as correct or wrong.
  Future<void> verdict(bool ok) async {
    final m = lastModule;
    if (m == null) return;
    (ok ? correct : wrong).update(m, (v) => v + 1, ifAbsent: () => 1);
    await log(m, lastEvent ?? '', verdict: ok ? 'correct' : 'wrong');
  }

  String summary() {
    final mods = {...correct.keys, ...wrong.keys};
    if (mods.isEmpty) return 'No verdicts yet.';
    return mods.map((m) {
      final c = correct[m] ?? 0, w = wrong[m] ?? 0;
      final pct = c + w == 0 ? 0 : (c * 100 / (c + w)).round();
      return '$m: $c correct, $w wrong ($pct% accurate)';
    }).join('\n');
  }

  Future<void> share() async {
    final f = await _file();
    await Share.shareXFiles([XFile(f.path)], subject: 'Gabay test log');
  }

  Future<void> clear() async {
    final f = await _file();
    await f.writeAsString('timestamp,module,event,label,score,latency_ms,verdict\n');
    correct.clear();
    wrong.clear();
    lastModule = null;
    lastEvent = null;
  }
}
