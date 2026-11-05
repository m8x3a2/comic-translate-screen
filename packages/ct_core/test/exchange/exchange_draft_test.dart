// Where an exchange stands, kept in its folder: written and read back.

import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('ct_draft_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('the parts, the answers taken and the fields come back as written', () async {
    const l11 = ExchangeLabel(1, 1), l12 = ExchangeLabel(1, 2), l21 = ExchangeLabel(2, 1);
    await ExchangeDraft(
      mode: ExchangeMode.both,
      parts: const [
        ['a', 'b'],
        ['c'],
      ],
      part: 1,
      accepted: {
        l11: const ExchangeReply(original: 'Hi', translation: 'Привет', speaker: Speaker.female, hasSpeaker: true),
        l12: const ExchangeReply(translation: 'Пока', missingArrow: true),
        l21: const ExchangeReply(original: 'Run', hasSpeaker: true),
      },
      unchanged: const [ExchangeLabel(2, 2)],
      answer: '[02-003] Беги',
      answer2: 'x',
    ).write(dir);
    final back = (await ExchangeDraft.read(dir))!;
    expect((back.mode, back.part), (ExchangeMode.both, 1));
    expect(back.parts, [
      ['a', 'b'],
      ['c'],
    ]);
    expect(back.unchanged, [const ExchangeLabel(2, 2)]);
    expect((back.answer, back.answer2), ('[02-003] Беги', 'x'));
    final r = back.accepted;
    expect(
      (r[l11]!.original, r[l11]!.translation, r[l11]!.speaker, r[l11]!.hasSpeaker),
      ('Hi', 'Привет', Speaker.female, true),
    );
    expect((r[l12]!.original, r[l12]!.missingArrow, r[l12]!.hasSpeaker), (null, true, false));
    // `[-]`: told that nobody speaks.
    expect((r[l21]!.speaker, r[l21]!.hasSpeaker), (null, true));

    await ExchangeDraft.delete(dir);
    expect(await ExchangeDraft.read(dir), isNull);
  });

  test('a broken draft is none; an empty one has nothing to keep', () async {
    File(p.join(dir.path, ExchangeDraft.fileName)).writeAsStringSync('{broken');
    expect(await ExchangeDraft.read(dir), isNull);
    expect(const ExchangeDraft(mode: ExchangeMode.translate, answer: '  ').isEmpty, isTrue);
    expect(
      const ExchangeDraft(
        mode: ExchangeMode.translate,
        parts: [
          ['a'],
        ],
      ).isEmpty,
      isFalse,
    );
  });
}
