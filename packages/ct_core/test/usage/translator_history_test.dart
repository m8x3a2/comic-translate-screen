// The history of requests to translators: the newest 100, kept on disk,
// cleared on request; reporting never fails a translation.

import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('ct_history_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  HistoryEntry entry(int n, {String error = ''}) => HistoryEntry(
    time: DateTime(2026, 10, 25, 12, 0, n),
    plugin: 'openrouter',
    host: 'openrouter.ai',
    model: 'm',
    page: 'p$n.png',
    ms: 1200,
    sent: 'system: translate\nuser: {"block_0": "Hi"}',
    image: n.isEven,
    reply: '{"block_0": "Привет"}',
    blocks: 1,
    warnings: n == 3 ? ['block_1 missing'] : const [],
    error: error,
    inputTokens: 10,
    outputTokens: 5,
    cost: 0.0001,
  );

  test('the newest first, at most 100, everything back as written', () async {
    final history = TranslatorHistory(File(p.join(tmp.path, 'translator_history.json')));
    for (var n = 0; n < 105; n++) {
      unawaited(history.record(entry(n, error: n == 104 ? 'the key was refused' : '')));
    }
    final read = await history.read();
    expect(read.length, TranslatorHistory.keep);
    expect([read.first.page, read.last.page], ['p104.png', 'p5.png']);
    expect((read.first.failed, read.first.error), (true, 'the key was refused'));
    final back = read.firstWhere((e) => e.page == 'p6.png');
    expect(
      (back.image, back.sent, back.reply, back.inputTokens, back.outputTokens, back.cost, back.ms),
      (true, 'system: translate\nuser: {"block_0": "Hi"}', '{"block_0": "Привет"}', 10, 5, 0.0001, 1200),
    );

    // Another program (cts) reads the same file.
    expect((await TranslatorHistory(history.file).read()).length, 100);
    await history.clear();
    expect(await history.read(), isEmpty);
  });

  test('a broken file is an empty history; reporting never throws', () async {
    final file = File(p.join(tmp.path, 'translator_history.json'))..writeAsStringSync('{broken');
    expect(await TranslatorHistory(file).read(), isEmpty);
    final context = PluginContext(
      log: EventLog.silent(),
      onHistory: (_) => throw const FileSystemException('disk full'),
    );
    await context.reportHistory(entry(1));
    final kept = <HistoryEntry>[];
    await PluginContext(log: EventLog.silent(), onHistory: kept.add).forPage('p1').reportHistory(entry(2));
    expect(kept.single.page, 'p2.png');
  });
}

void unawaited(Future<void> _) {}
