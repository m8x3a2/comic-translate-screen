// The exchange folders in the data folder: the newest kept, and those with
// answers not applied yet.

import 'dart:io';

import 'package:comic_translate/state/exchange.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('old exchange folders go, except those with answers not applied yet', () async {
    final data = Directory.systemTemp.createTempSync('cts_exchange_dirs_');
    addTearDown(() => data.deleteSync(recursive: true));
    final root = Directory(p.join(data.path, 'exchange'));
    for (var n = 0; n < keptExchangeFolders + 5; n++) {
      Directory(p.join(root.path, '20260101_0000${'$n'.padLeft(2, '0')}')).createSync(recursive: true);
    }
    final pending = Directory(p.join(root.path, '20260101_000000'));
    await const ExchangeDraft(mode: ExchangeMode.translate, answer: '[01-001] Привет').write(pending);
    // Parts alone are no answers: such a folder goes like any other.
    await const ExchangeDraft(
      mode: ExchangeMode.translate,
      parts: [
        ['a'],
      ],
    ).write(Directory(p.join(root.path, '20260101_000001')));
    newExchangeDir(AppPaths(data.path));
    final left = root.listSync().whereType<Directory>().map((d) => p.basename(d.path)).toList();
    expect(left, contains('20260101_000000'), reason: 'the oldest, but with answers');
    expect(left, isNot(contains('20260101_000001')));
    expect(left.length, keptExchangeFolders + 1);
  });
}
