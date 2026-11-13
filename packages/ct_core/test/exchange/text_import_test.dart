// "Load text": a chat's answer to the exported text goes back into the
// bubbles by its labels.

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

void main() {
  TextBlock block(String text, [String translation = '', Speaker? speaker]) =>
      TextBlock(xyxy: const BBox(0, 0, 1, 1), text: text, translation: translation, speaker: speaker);

  List<ExchangePage> pages() => [
    ExchangePage(
      id: 'a',
      number: 1,
      name: 'p1.png',
      blocks: [block("I'M LATE!", 'Я опоздала!', Speaker.female), block(''), block('Run!')],
    ),
    ExchangePage(id: 'b', number: 2, name: 'p2.png', blocks: [block('Hi'), block('Bye', 'Пока')]),
  ];

  String afterOf(TextImport r, ExchangeLabel label, {bool original = false}) {
    final c = r.changes.firstWhere((c) => c.label == label);
    return original ? c.after.text : c.after.translation;
  }

  test('translations by label; missing and empty lines leave the bubble as it is', () {
    const answer =
        'Here is the translation:\n\n'
        'Page 1\n'
        '[01-001] [f] Я опаздываю!\n'
        '[01-002]\n'
        '[01-003] Беги, *живо*!\n'
        '\n'
        'Page 2\n'
        '[02-002]\n'
        '[09-001] Лишнее\n';
    final r = readTextImport(pages(), answer, TextImportTarget.translation, heading: 'Page {n}');
    expect(r.labelsFound, isTrue);
    expect([for (final c in r.changes) c.label.code], ['01-001', '01-003']);
    expect(afterOf(r, const ExchangeLabel(1, 1)), 'Я опаздываю!');
    // Stars are bold words, as in the exchange.
    expect(afterOf(r, const ExchangeLabel(1, 3)), 'Беги, живо!');
    expect(r.changes.last.after.style?.runs, isNotEmpty);
    // Bubbles with text and no answer; the empty bubble is not missing.
    expect([for (final l in r.missing) l.code], ['02-001', '02-002']);
    expect([for (final l in r.unknown) l.code], ['09-001']);
    // The pages themselves are not touched.
    expect(pages().first.blocks.first.translation, 'Я опоздала!');
  });

  test('a heading the chat glued to the line before is no part of the bubble', () {
    const answer = '[01-003] Беги!\n**Страница 2**\n[02-001] Привет\n--- 3 ---\n';
    final r = readTextImport(pages(), answer, TextImportTarget.translation, heading: '--- {n} ---');
    expect(afterOf(r, const ExchangeLabel(1, 3)), 'Беги!');
    expect(afterOf(r, const ExchangeLabel(2, 1)), 'Привет');
  });

  test('original --> translation fills both; into the original a line is the text', () {
    final both = readTextImport(pages(), '[01-003] Run away! --> Убегай!', TextImportTarget.translation);
    final c = both.changes.single;
    expect((c.after.text, c.after.translation), ('Run away!', 'Убегай!'));

    final read = readTextImport(pages(), '[01-002] WHAT?!\n[02-001] Hi', TextImportTarget.original);
    // "Hi" is what the bubble has: no change.
    expect([for (final c in read.changes) c.label.code], ['01-002']);
    expect(afterOf(read, const ExchangeLabel(1, 2), original: true), 'WHAT?!');
    expect(read.changes.single.after.translation, '');
    // Into the original every bubble without an answer is missing.
    expect(read.missing.length, 3);
  });

  test('a text without labels says so', () {
    final r = readTextImport(pages(), 'Я опоздала!\nБеги!', TextImportTarget.translation);
    expect(r.labelsFound, isFalse);
    expect(r.changes, isEmpty);
    expect(r.answered, 0);
  });

  test('the exported translation file loads back unchanged; a byte order mark is fine', () {
    final options = const TextExportOptions();
    final file = exportedText(pages(), translation: true, options: options, heading: 'Page {n}');
    final r = readTextImport(pages(), '﻿$file', TextImportTarget.translation, heading: 'Page {n}');
    expect(r.changes, isEmpty);
    // Bubbles with a translation (or a speaker); the empty lines are no answer.
    expect(r.answered, 2);
  });

  test('a request to translate: labels always, empty bubbles and pages left out', () {
    final text = exportedText(
      [
        ...pages(),
        ExchangePage(id: 'c', number: 3, name: 'p3.png', blocks: [block('')]),
      ],
      translation: false,
      options: const TextExportOptions(speakers: true),
      heading: 'Page {n}',
      skipEmpty: true,
    );
    expect(text, "Page 1\n[01-001] [f] I'M LATE!\n[01-003] Run!\n\nPage 2\n[02-001] Hi\n[02-002] Bye\n");
    expect(textTranslateRequest('Russian'), contains('into Russian'));
    // The request itself has no label: pasted along with the answer, it fills no bubble.
    final pasted = readTextImport(pages(), '${textTranslateRequest('Russian')}\n\n$text', TextImportTarget.original);
    expect((pasted.answered, pasted.unknown.length, pasted.changes.length), (4, 0, 0));
  });

  test('page headings: the usual ones and the user\'s', () {
    expect(withoutPageHeadings('a\n## Page 12\nb\nСтраница 3:\nстр. 4\nPage twelve', ''), 'a\nb\nPage twelve');
    expect(withoutPageHeadings('a\n=== 5 (p5.png) ===\nb', '=== {n} ({name}) ==='), 'a\nb');
  });
}
