// "Export text": the dialogues of the chosen pages as plain text, with the
// labels of the exchange.

import 'dart:convert';

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

void main() {
  TextBlock block(String text, [String translation = '', Speaker? speaker]) =>
      TextBlock(xyxy: const BBox(0, 0, 1, 1), text: text, translation: translation, speaker: speaker);

  // The second and the fifth page of the project.
  final pages = [
    ExchangePage(
      id: 'a',
      number: 2,
      name: 'p2.png',
      blocks: [block("I'M\nLATE!", 'Я опоздала!', Speaker.female), block(''), block('Run!', 'Беги!')],
    ),
    ExchangePage(id: 'b', number: 5, name: 'p5.png', blocks: [block('Hi', '')]),
  ];
  const heading = 'Page {n}';

  test('labels, speakers and headings: the lines of ALL.txt', () {
    expect(
      exportedText(pages, translation: false, options: const TextExportOptions(), heading: heading),
      "Page 2\n[02-001] [f] I'M LATE!\n[02-002]\n[02-003] Run!\n\nPage 5\n[05-001] Hi\n",
    );
    expect(
      exportedText(pages, translation: true, options: const TextExportOptions(), heading: heading),
      'Page 2\n[02-001] [f] Я опоздала!\n[02-002]\n[02-003] Беги!\n\nPage 5\n[05-001]\n',
    );
  });

  test('plain lines: empty bubbles and empty pages are left out', () {
    const plain = TextExportOptions(labels: false, headings: false, speakers: false);
    expect(exportedText(pages, translation: false, options: plain, heading: heading), "I'M LATE!\nRun!\n\nHi\n");
    expect(exportedText(pages, translation: true, options: plain, heading: heading), 'Я опоздала!\nБеги!\n');
  });

  test('a heading of the user with the page number and the file name', () {
    final text = exportedText(
      [pages.last],
      translation: false,
      options: const TextExportOptions(labels: false),
      heading: '--- {n} ({name}) ---',
    );
    expect(text, '--- 5 (p5.png) ---\nHi\n');
  });

  test('file names and the remembered choices', () {
    expect(textExportName('Chapter 1', translation: false), 'Chapter 1_original.txt');
    expect(textExportName('Chapter 1', translation: true), 'Chapter 1_translation.txt');
    const options = TextExportOptions(part: TextExportPart.translation, labels: false, heading: '# {n}');
    final back = TextExportOptions.fromJson(jsonDecode(jsonEncode(options.toJson())));
    expect(
      (back.part, back.labels, back.headings, back.speakers, back.heading),
      (TextExportPart.translation, false, true, true, '# {n}'),
    );
    final settings = ExchangeSettings.fromJson(
      jsonDecode(jsonEncode(const ExchangeSettings(textExport: options).toJson())) as Map<String, Object?>,
    );
    expect(settings.textExport.heading, '# {n}');
    expect(TextExportOptions.fromJson(null).part, TextExportPart.both);
  });
}
