import 'dart:convert';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('cts_exchange_test_'));
  tearDown(() => dir.deleteSync(recursive: true));

  /// A grey page with dark squares where the blocks are.
  RgbImage page(int w, int h, List<BBox> boxes) {
    final img = RgbImage.filled(w, h, 200, 200, 200);
    for (final b in boxes) {
      for (var y = b.y1; y < b.y2; y++) {
        for (var x = b.x1; x < b.x2; x++) {
          final o = img.offset(x, y);
          img.data[o] = img.data[o + 1] = img.data[o + 2] = 20;
        }
      }
    }
    return img;
  }

  List<TextBlock> blocks(List<BBox> boxes, [List<String> texts = const []]) => [
    for (final (i, b) in boxes.indexed) TextBlock(xyxy: b, text: i < texts.length ? texts[i] : ''),
  ];

  List<String> filesIn(String folder) => [
    for (final f in Directory(folder).listSync(recursive: true).whereType<File>())
      p.relative(f.path, from: folder).replaceAll(r'\', '/'),
  ]..sort();

  group('sheets', () {
    List<SheetPiece> pieces(int n, {int w = 200, int h = 100, int pageEvery = 100}) => [
      for (var i = 0; i < n; i++)
        SheetPiece(
          RgbImage.filled(w, h, 0, 0, 0),
          label: ExchangeLabel(i ~/ pageEvery + 1, i + 1),
          page: i ~/ pageEvery + 1,
        ),
    ];

    test('by size: as many as fit, never larger than the limit', () {
      final sheets = buildSheets(pieces(30), maxPx: 800);
      expect(sheets.length, greaterThan(1));
      expect([for (final s in sheets) ...s.labels].length, 30);
      for (final s in sheets) {
        expect(s.image.width, lessThanOrEqualTo(800));
        expect(s.image.height, lessThanOrEqualTo(800));
      }
    });

    test('by count, and a new sheet for every page', () {
      expect(
        [for (final s in buildSheets(pieces(10), grouping: SheetGrouping.count, perSheet: 4)) s.labels.length],
        [4, 4, 2],
      );
      final perPage = buildSheets(pieces(6, pageEvery: 3), sheetPerPage: true);
      expect(
        [for (final s in perPage) s.labels.map((l) => l.page).toSet()],
        [
          {1},
          {2},
        ],
      );
    });

    test('own groups first, the rest as usual, in reading order', () {
      final sheets = buildSheets(
        pieces(7),
        grouping: SheetGrouping.count,
        perSheet: 10,
        groups: [
          [0, 1, 2, 3],
          [4, 5],
        ],
      );
      expect(
        [for (final s in sheets) s.labels.map((l) => l.block).toList()],
        [
          [1, 2, 3, 4],
          [5, 6],
          [7],
        ],
      );
    });

    test('a piece larger than the sheet is made smaller; the label stays on top in yellow', () {
      final sheets = buildSheets(pieces(1, w: 3000, h: 500), maxPx: 1000);
      final s = sheets.single.image;
      expect(s.width, lessThanOrEqualTo(1000));
      // The label bar starts at the margin.
      final o = s.offset(18, 18);
      expect(s.data.sublist(o, o + 3), [255, 224, 0]);
    });

    test('the whole page goes before the pieces of its page', () {
      final ps = [SheetPiece(RgbImage.filled(300, 400, 9, 9, 9), page: 1, context: true), ...pieces(2)];
      final sheets = buildSheets(ps, maxPx: 1600);
      expect(sheets.single.labels.length, 2);
      // Black context page at the first place (inside the frame).
      final o = sheets.single.image.offset(16 + 10, 16 + 10);
      expect(sheets.single.image.data[o], 9);
    });

    test('small cut-outs are enlarged, at most three times', () {
      final img = page(400, 300, []);
      final small = cropForExchange(img, TextBlock(xyxy: const BBox(10, 10, 60, 24))..linePx = 6);
      expect(small.height, greaterThan(24 * 2));
      final big = cropForExchange(img, TextBlock(xyxy: const BBox(10, 10, 300, 200)));
      expect(big.width, lessThan(400));
    });
  });

  group('the exchange folder', () {
    final boxes = [const BBox(20, 20, 120, 80), const BBox(200, 150, 330, 260)];
    List<ExchangePage> pages() => [
      ExchangePage(
        id: 'p1',
        number: 1,
        name: 'a.png',
        blocks: blocks(boxes, ['Hello', '...']),
        image: page(400, 300, boxes),
      ),
      ExchangePage(
        id: 'p2',
        number: 2,
        name: 'b.png',
        blocks: blocks([boxes[0]], ['Bye']),
        image: page(400, 300, [boxes[0]]),
      ),
    ];

    test('both: prompt, sheets, empty templates and what was sent', () async {
      final out = await writeExchange(
        dir,
        pages(),
        ExchangeMode.both,
        const ExchangeSettings(
          textFiles: ExchangeTextFiles.both,
          contextImage: ContextImage.separate,
          splitFiles: false,
        ),
        sourceLanguage: 'English',
        targetLanguage: 'Russian',
      );
      expect(filesIn(dir.path), [
        'ALL.txt',
        'exchange.json',
        'page_01.txt',
        'page_01_context.jpg',
        'page_02.txt',
        'page_02_context.jpg',
        'prompt.txt',
        'sheet_01.png',
      ]);
      expect([for (final i in out.items) i.label.code], ['01-001', '01-002', '02-001']);
      expect(out.pictures, ['page_01_context.jpg', 'page_02_context.jpg', 'sheet_01.png']);
      expect(File(p.join(dir.path, 'ALL.txt')).readAsStringSync(), '[01-001] \n[01-002] \n[02-001] \n');
      expect(out.prompt, contains('Pictures of the whole pages'));
      final manifest = jsonDecode(File(p.join(dir.path, 'exchange.json')).readAsStringSync()) as Map;
      expect((manifest['sheets'] as List).single['labels'], ['01-001', '01-002', '02-001']);
      expect(out.sheetLabels, {
        'sheet_01.png': ['01-001', '01-002', '02-001'],
      });
      expect((await ExchangeManifest.read(dir)).export!.sheetLabels, out.sheetLabels);
    });

    test('translate: only blocks with letters, the text in the prompt and in ALL.txt, no pictures', () async {
      final out = await writeExchange(
        dir,
        pages(),
        ExchangeMode.translate,
        const ExchangeSettings(),
        sourceLanguage: 'English',
        targetLanguage: 'Russian',
      );
      expect(filesIn(dir.path), ['ALL.txt', 'ALL_original.txt', 'ALL_translation.txt', 'exchange.json', 'prompt.txt']);
      expect(File(p.join(dir.path, 'ALL_translation.txt')).readAsStringSync(), '[01-001] \n[02-001] \n');
      expect([for (final i in out.items) i.label.code], ['01-001', '02-001']);
      expect(out.prompt, contains('[01-001] Hello\n[02-001] Bye'));
      expect(File(p.join(dir.path, 'ALL.txt')).readAsStringSync(), '[01-001] Hello\n[02-001] Bye\n');
    });

    test('single cut-outs in folders of ten', () async {
      final many = [for (var i = 0; i < 12; i++) BBox(10 + i * 30, 10, 35 + i * 30, 40)];
      await writeExchange(
        dir,
        [ExchangePage(id: 'p', number: 3, name: 'c.png', blocks: blocks(many), image: page(400, 300, many))],
        ExchangeMode.recognize,
        const ExchangeSettings(images: ExchangeImages.crops),
        sourceLanguage: 'English',
        targetLanguage: 'Russian',
      );
      final crops = filesIn(dir.path).where((f) => f.startsWith('crops/')).toList();
      expect(crops.length, 12);
      expect(crops.first, 'crops/batch_01/03-001.png');
      expect(crops.last, 'crops/batch_02/03-012.png');
    });

    test('translate with pictures of the pages; the folder read back keeps them', () async {
      final out = await writeExchange(
        dir,
        pages(),
        ExchangeMode.translate,
        const ExchangeSettings(contextImage: ContextImage.onSheet),
        sourceLanguage: 'English',
        targetLanguage: 'Russian',
      );
      expect(out.pictures, ['page_01_context.jpg', 'page_02_context.jpg']);
      expect(out.prompt, contains('Pictures of the whole pages'));
      final back = (await ExchangeManifest.read(dir)).export!;
      expect(back.pictures, out.pictures);
      expect(back.prompt, out.prompt);
      expect([for (final i in back.items) i.label], [for (final i in out.items) i.label]);
    });

    test('small pictures of the pieces for the app, apart from what goes to the chat', () async {
      final out = await writeExchange(
        dir,
        pages(),
        ExchangeMode.both,
        const ExchangeSettings(),
        sourceLanguage: 'English',
        targetLanguage: 'Russian',
        previews: true,
      );
      expect(out.previews.keys, ['01-001', '01-002', '02-001']);
      expect(out.previews['01-002'], p.join('_pieces', '01-002.jpg'));
      expect(File(p.join(dir.path, out.previews['01-002']!)).existsSync(), isTrue);
      expect(out.pictures, ['sheet_01.png']);
    });

    test('the original and the translation in two files, written and read back', () async {
      await writeExchange(
        dir,
        pages(),
        ExchangeMode.both,
        const ExchangeSettings(splitFiles: true),
        sourceLanguage: 'English',
        targetLanguage: 'Russian',
      );
      expect(filesIn(dir.path).where((f) => f.endsWith('.txt')), [
        'ALL.txt',
        'ALL_original.txt',
        'ALL_translation.txt',
        'prompt.txt',
      ]);
      File(p.join(dir.path, 'ALL_original.txt')).writeAsStringSync('[01-001] Hello\n[01-002] \n[02-001] Bye\n');
      File(p.join(dir.path, 'ALL_translation.txt')).writeAsStringSync('[01-001] Привет\n[01-002] \n[02-001] Пока\n');
      final m = await readExchangeFolder(dir, await ExchangeManifest.read(dir));
      expect(m.replies.keys, [const ExchangeLabel(1, 1), const ExchangeLabel(2, 1)]);
      expect(m.replies[const ExchangeLabel(2, 1)]!.original, 'Bye');
      expect(m.replies[const ExchangeLabel(2, 1)]!.translation, 'Пока');
      expect(m.missing, [const ExchangeLabel(1, 2)]);
      expect(m.sources[const ExchangeLabel(1, 1)], 'ALL_original.txt + ALL_translation.txt');
    });

    test('each piece takes what was filled in, in whichever file', () async {
      await writeExchange(
        dir,
        pages(),
        ExchangeMode.both,
        const ExchangeSettings(),
        sourceLanguage: 'English',
        targetLanguage: 'Russian',
      );
      // 01-001 in ALL.txt only, 02-001 half in each, 01-002 nowhere.
      File(p.join(dir.path, 'ALL.txt')).writeAsStringSync('[01-001] Hello --> Привет\n[01-002]\n[02-001] Пока\n');
      File(p.join(dir.path, 'ALL_original.txt')).writeAsStringSync('[01-001]\n[01-002]\n[02-001] Bye\n');
      final m = await readExchangeFolder(dir, await ExchangeManifest.read(dir));
      expect(m.replies[const ExchangeLabel(1, 1)]!.translation, 'Привет');
      expect(m.replies[const ExchangeLabel(2, 1)]!.original, 'Bye');
      expect(m.replies[const ExchangeLabel(2, 1)]!.translation, 'Пока');
      expect(m.missingArrow, isEmpty);
      expect(m.missing, [const ExchangeLabel(1, 2)]);
      expect(m.sources[const ExchangeLabel(1, 1)], 'ALL.txt');
      expect(m.sources[const ExchangeLabel(2, 1)], 'ALL_original.txt, ALL.txt');
    });

    test('translate: the template filled in, the apart files left as they are', () async {
      await writeExchange(
        dir,
        pages(),
        ExchangeMode.translate,
        const ExchangeSettings(),
        sourceLanguage: 'English',
        targetLanguage: 'Russian',
      );
      expect(
        File(p.join(dir.path, 'ALL_original.txt')).readAsStringSync(),
        File(p.join(dir.path, 'ALL.txt')).readAsStringSync(),
      );
      File(p.join(dir.path, 'ALL.txt')).writeAsStringSync('[01-001] Привет\n');
      final m = await readExchangeFolder(dir, await ExchangeManifest.read(dir));
      expect(m.replies.keys, [const ExchangeLabel(1, 1)]);
      expect(m.sources[const ExchangeLabel(1, 1)], 'ALL.txt');
    });

    test('pictures made again keep what the user wrote into the text files', () async {
      const settings = ExchangeSettings();
      await writeExchange(
        dir,
        pages(),
        ExchangeMode.both,
        settings,
        sourceLanguage: 'English',
        targetLanguage: 'Russian',
      );
      File(p.join(dir.path, 'ALL.txt')).writeAsStringSync('[01-001] Hello --> Привет\n');
      await writeExchange(
        dir,
        pages(),
        ExchangeMode.both,
        settings.copyWith(grouping: SheetGrouping.count, perSheet: 1),
        sourceLanguage: 'English',
        targetLanguage: 'Russian',
        keepTexts: true,
        promptText: 'my own words',
      );
      expect(filesIn(dir.path).where((f) => f.startsWith('sheet_')), hasLength(3));
      expect(File(p.join(dir.path, 'prompt.txt')).readAsStringSync(), 'my own words');
      await writeExchange(
        dir,
        pages(),
        ExchangeMode.both,
        settings,
        sourceLanguage: 'English',
        targetLanguage: 'Russian',
        keepTexts: true,
      );
      expect(File(p.join(dir.path, 'ALL.txt')).readAsStringSync(), '[01-001] Hello --> Привет\n');
      expect(filesIn(dir.path).where((f) => f.startsWith('sheet_')), ['sheet_01.png'], reason: 'the old sheets went');
    });

    test('answers written into the files come back: ALL.txt first, then the page files', () async {
      await writeExchange(
        dir,
        pages(),
        ExchangeMode.translate,
        const ExchangeSettings(textFiles: ExchangeTextFiles.both),
        sourceLanguage: 'English',
        targetLanguage: 'Russian',
      );
      File(p.join(dir.path, 'ALL.txt')).writeAsStringSync('[01-001] Привет\n[02-001] Bye\n');
      File(p.join(dir.path, 'page_02.txt')).writeAsStringSync('[02-001] Пока\n');
      final manifest = await ExchangeManifest.read(dir);
      expect(manifest.mode, ExchangeMode.translate);
      expect(manifest.pages, {'p1': 1, 'p2': 2});
      final m = await readExchangeFolder(dir, manifest);
      expect(m.replies[const ExchangeLabel(1, 1)]!.translation, 'Привет');
      expect(m.replies[const ExchangeLabel(2, 1)]!.translation, 'Пока');
      expect(m.sources, {const ExchangeLabel(1, 1): 'ALL.txt', const ExchangeLabel(2, 1): 'page_02.txt'});
      expect(m.missing, isEmpty);
    });
  });

  test('settings survive a round trip and wrong values fall back', () {
    const s = ExchangeSettings(
      together: false,
      grouping: SheetGrouping.count,
      perSheet: 4,
      sheetMaxPx: 2000,
      contextImage: ContextImage.onSheet,
      images: ExchangeImages.both,
      textFiles: ExchangeTextFiles.pages,
      placeholder: '⟦пусто⟧',
      apart: true,
      splitFiles: false,
      separator: '|',
      prompts: {ExchangePrompt.both: 'mine'},
    );
    final back = ExchangeSettings.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>);
    expect(back.toJson(), s.toJson());
    final wrong = ExchangeSettings.fromJson({'sheet_max_px': 10, 'grouping': 'x', 'per_sheet': -3});
    expect((wrong.sheetMaxPx, wrong.grouping, wrong.perSheet), (ExchangeSettings.minSheetPx, SheetGrouping.size, 1));
    final app = AppSettings.fromJson(AppSettings(exchange: s).toJson());
    expect(app.exchange.toJson(), s.toJson());
  });
}
