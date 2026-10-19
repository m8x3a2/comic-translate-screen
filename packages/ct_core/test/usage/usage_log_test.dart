import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('cts_usage_test_'));
  tearDown(() => dir.deleteSync(recursive: true));

  ServiceUsage used(String model, {int input = 100, int output = 10, double? cost, bool estimated = false}) =>
      ServiceUsage(
        plugin: 'openai_compatible',
        host: 'openrouter.ai',
        model: model,
        inputTokens: input,
        outputTokens: output,
        cost: cost,
        estimated: estimated,
      );

  test('counts per model, today and in total; survives a restart', () async {
    var now = DateTime(2026, 10, 18, 23, 30);
    final file = File(p.join(dir.path, 'usage.json'));
    final log = UsageLog(file, clock: () => now);
    expect((await log.read()).entries, isEmpty);

    await log.record(used('deepseek', cost: 0.001));
    now = DateTime(2026, 10, 19, 9);
    await Future.wait([
      log.record(used('deepseek', cost: 0.002)),
      log.record(used('deepseek', input: 50, output: 5)),
    ]);
    now = now.add(const Duration(minutes: 1));
    await log.record(used('gemma:free', estimated: true));

    final report = await UsageLog(file, clock: () => now).read();
    expect(report.since, DateTime(2026, 10, 18));
    expect([for (final e in report.entries) e.model], ['gemma:free', 'deepseek'], reason: 'most recent first');
    final deepseek = report.entries.last;
    expect((deepseek.today.requests, deepseek.today.tokens), (2, 165));
    expect(deepseek.today.cost, closeTo(0.002, 1e-12), reason: 'requests without a cost add nothing');
    expect((deepseek.total.requests, deepseek.total.inputTokens, deepseek.total.outputTokens), (3, 250, 25));
    expect(deepseek.total.cost, closeTo(0.003, 1e-12));
    expect(deepseek.total.estimated, isFalse);
    final free = report.entries.first;
    expect((free.today.requests, free.today.cost, free.today.estimated), (1, null, true));
  });

  test('old days are dropped, totals stay; reset starts from zero; a broken file counts as empty', () async {
    var now = DateTime(2026, 1, 1);
    final file = File(p.join(dir.path, 'usage.json'));
    final log = UsageLog(file, clock: () => now);
    await log.record(used('m'));
    now = now.add(const Duration(days: UsageLog.keepDays + 5));
    await log.record(used('m'));
    expect(file.readAsStringSync(), isNot(contains('"2026-01-01": {')));
    final entry = (await log.read()).entries.single;
    expect((entry.today.requests, entry.total.requests), (1, 2));

    await log.reset();
    expect((await log.read()).entries, isEmpty);

    file.writeAsStringSync('{not json');
    await log.record(used('m'));
    expect((await log.read()).entries.single.total.requests, 1);
  });

  test('a plugin context reports usage and never fails because of the counter', () async {
    final context = PluginContext(
      log: EventLog.silent(),
      onUsage: (_) => throw const FileSystemException('disk full'),
    );
    await context.reportUsage(used('m'));
    final page = PluginContext(log: EventLog.silent(), onUsage: (_) {}).forPage('p1');
    expect(page.onUsage, isNotNull);
  });
}
