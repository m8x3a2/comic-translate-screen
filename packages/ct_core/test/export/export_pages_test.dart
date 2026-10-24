import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('cts_export_test_'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<String> picture(String name, int shade) async {
    final path = p.join(dir.path, 'src', name);
    Directory(p.dirname(path)).createSync(recursive: true);
    await ImageCodec.writeFile(path, RgbImage.filled(40, 30, shade, shade, shade));
    return path;
  }

  Future<List<ExportPage>> chapter(String chapter, List<String> names) async => [
    for (final (i, n) in names.indexed)
      ExportPage(
        name: n,
        chapter: chapter,
        sourceExtension: '.jpg',
        translatedImage: await picture('${chapter}_${n}_t.png', 10 * i),
        cleanImage: await picture('${chapter}_${n}_c.png', 200),
        recognized: {'block_0': 'Hello $n'},
        translations: {'block_0': 'Привет $n'},
      ),
  ];

  List<String> filesIn(String folder) => [
    for (final f in Directory(folder).listSync(recursive: true).whereType<File>())
      p.relative(f.path, from: folder).replaceAll(r'\', '/'),
  ]..sort();

  test('a folder of translated pages, in the original format; names keep the page order', () async {
    final pages = await chapter('', ['page10', 'page2', 'page2']);
    final out = p.join(dir.path, 'out');
    final r = await exportPages(pages, const ExportOptions(), out);
    expect(r.pages, 3);
    expect(filesIn(out), [
      '001_page10.jpg',
      '002_page2.jpg',
      '003_page2_02.jpg',
    ], reason: 'page10 would sort after page2, so numbers keep the order');

    final inOrder = await exportPages(
      await chapter('', ['001', '002']),
      const ExportOptions(imageFormat: 'png'),
      p.join(dir.path, 'ordered'),
    );
    expect(filesIn(inOrder.outputs.single), ['001.png', '002.png']);
  });

  test('names from a template: text and a number from the chosen start', () async {
    final pages = await chapter('', ['page10', 'page2', 'x']);
    final out = p.join(dir.path, 'named');
    await exportPages(
      pages,
      const ExportOptions(imageFormat: 'jpg', translatedText: true, names: NameTemplate('spider man ', '009')),
      out,
    );
    expect(filesIn(out), [
      'translated/spider man 009.jpg',
      'translated/spider man 010.jpg',
      'translated/spider man 011.jpg',
      'translated_texts/spider man 009_translated.json',
      'translated_texts/spider man 010_translated.json',
      'translated_texts/spider man 011_translated.json',
    ]);
    expect(
      [
        for (final s in ['1', '0', '0007']) const NameTemplate('p', '').nameOf(0) + NameTemplate('', s).nameOf(2),
      ],
      ['p13', 'p12', 'p10009'],
    );
    expect(const NameTemplate('  ', '01').nameOf(0), '01', reason: 'spaces alone: just the number');
    expect(NameTemplate.validStart('12a'), isFalse);
  });

  test('several kinds go into their own folders, texts as JSON like the original', () async {
    final out = p.join(dir.path, 'all');
    await exportPages(
      await chapter('', ['a', 'b']),
      const ExportOptions(cleaned: true, recognizedText: true, translatedText: true, imageFormat: 'webp'),
      out,
    );
    expect(filesIn(out), [
      'cleaned/a.webp',
      'cleaned/b.webp',
      'raw_texts/a_raw.json',
      'raw_texts/b_raw.json',
      'translated/a.webp',
      'translated/b.webp',
      'translated_texts/a_translated.json',
      'translated_texts/b_translated.json',
    ]);
    expect(jsonDecode(File(p.join(out, 'translated_texts', 'b_translated.json')).readAsStringSync()), {
      'block_0': 'Привет b',
    });
  });

  test('CBZ holds only the pictures, stored without recompression', () async {
    final file = p.join(dir.path, 'book.cbz');
    final r = await exportPages(
      await chapter('', ['1', '2']),
      const ExportOptions(container: ExportContainer.cbz, recognizedText: true, imageFormat: 'png'),
      file,
    );
    expect(r.outputs, [file]);
    final bytes = File(file).readAsBytesSync();
    final zip = ZipDecoder().decodeBytes(bytes);
    expect([for (final f in zip.files) f.name], ['1.png', '2.png']);
    expect(bytes[8] | bytes[9] << 8, 0, reason: 'method 0 (stored) in the first local header');
    expect(zip.files.first.content, File(p.join(dir.path, 'src', '_1_t.png')).readAsBytesSync());
  });

  test('one file per chapter; chapter names become file names', () async {
    final pages = [
      ...await chapter('Vol 1: Start', ['01', '02']),
      ...await chapter('Vol 2', ['01']),
    ];
    final out = p.join(dir.path, 'chapters');
    final r = await exportPages(pages, const ExportOptions(container: ExportContainer.zip, byChapter: true), out);
    expect(r.outputs.map(p.basename), ['Vol 1_ Start.zip', 'Vol 2.zip']);
    final second = ZipDecoder().decodeBytes(File(r.outputs.last).readAsBytesSync());
    expect([for (final f in second.files) f.name], ['01.jpg']);
  });

  test('PDF: one page per picture, a valid index', () async {
    final file = p.join(dir.path, 'book.pdf');
    final r = await exportPages(
      await chapter('', ['1', '2', '3']),
      const ExportOptions(container: ExportContainer.pdf),
      file,
    );
    expect(r.pages, 3);
    final bytes = File(file).readAsBytesSync();
    final text = latin1.decode(bytes);
    expect(text, startsWith('%PDF-1.4'));
    expect(text.trimRight(), endsWith('%%EOF'));
    expect(RegExp(r'/Type /Page ').allMatches(text), hasLength(3));
    expect(text, contains('/Count 3'));
    expect(text, contains('/MediaBox [0 0 40 30]'));
    // Every entry of the index points at its object.
    final start = int.parse(RegExp(r'startxref\n(\d+)').firstMatch(text)!.group(1)!);
    expect(text.substring(start, start + 4), 'xref');
    final entries = RegExp(r'^(\d{10}) 00000 n $', multiLine: true).allMatches(text.substring(start)).toList();
    for (final (i, e) in entries.indexed) {
      final offset = int.parse(e.group(1)!);
      expect(text.substring(offset), startsWith('${i + 1} 0 obj'));
    }

    final lossless = p.join(dir.path, 'png.pdf');
    await exportPages(
      await chapter('', ['1']),
      const ExportOptions(container: ExportContainer.pdf, cleaned: true, translated: false, imageFormat: 'png'),
      lossless,
    );
    expect(latin1.decode(File(lossless).readAsBytesSync()), contains('/FlateDecode'));
  });

  test('CB7 needs 7-Zip', () async {
    final pages = await chapter('', ['1']);
    final file = p.join(dir.path, 'book.cb7');
    await expectLater(
      exportPages(pages, const ExportOptions(container: ExportContainer.cb7), file),
      throwsA(isA<ArchiveToolMissingException>()),
    );
    final tool = findArchiveTool(file);
    if (tool == null) return;
    await exportPages(pages, const ExportOptions(container: ExportContainer.cb7), file, sevenZip: tool);
    final list = await Process.run(tool, ['l', file]);
    expect('${list.stdout}', contains('1.jpg'));
  });

  test('file names: characters Windows refuses are replaced', () {
    expect(safeFileStem('Глава 1: "Начало"?'), 'Глава 1_ _Начало');
    expect(safeFileStem('...'), 'chapter');
  });
}
