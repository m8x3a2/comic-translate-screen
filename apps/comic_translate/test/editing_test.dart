// Editing a page: undo history and the single steps of the editor.

import 'dart:io';

import 'package:comic_translate/bootstrap.dart';
import 'package:comic_translate/state/app_state.dart';
import 'package:comic_translate/state/batch.dart';
import 'package:comic_translate/state/exchange.dart';
import 'package:comic_translate/state/editor.dart';
import 'package:comic_translate/state/page_render.dart';
import 'package:comic_translate/state/steps.dart';
import 'package:comic_translate/state/workspace.dart';
import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart' show chatTranslatorId;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/fake_plugins.dart';

class _YesUi implements BatchUi {
  Future<bool> Function(ExchangeRequest)? answerExchange;

  @override
  Future<bool> exchange(ExchangeRequest request) async => await answerExchange?.call(request) ?? false;

  final errors = <Object>[];

  /// Plugins said to have no key, and the ones asked to send data (with or
  /// without pictures); what to answer.
  final missingKey = <String>[];
  final networkAsked = <(String, bool)>[];
  NetworkChoice network = NetworkChoice.once;

  @override
  Future<void> explainMissingKey(PluginInfo translator, String host) async => missingKey.add(translator.id);

  @override
  Future<bool> confirmDownload(List<ModelSpec> models) async => true;

  @override
  Future<NetworkChoice> confirmNetwork(
    PluginInfo translator,
    PluginEndpoint endpoint, {
    required bool sendsImage,
  }) async {
    networkAsked.add((translator.id, sendsImage));
    return network;
  }

  @override
  void showError(Object error) => errors.add(error);

  /// Pages changed by hand: what to answer.
  HandEditedChoice handEdited = HandEditedChoice.translate;
  int handEditedAsked = 0;

  @override
  Future<HandEditedChoice> confirmHandEdited(int count) async {
    handEditedAsked = count;
    return handEdited;
  }

  /// Frames without text: what to answer (null: stop) and how many were asked about.
  EmptyFrames? emptyFrames = EmptyFrames.read;
  bool rememberEmpty = false;
  int emptyAsked = 0;

  @override
  Future<({EmptyFrames choice, bool remember})?> confirmEmptyFrames(int count) async {
    emptyAsked = count;
    final choice = emptyFrames;
    return choice == null ? null : (choice: choice, remember: rememberEmpty);
  }
}

final _paintMaskInfo = fakeInfo('paint_mask', PluginKind.inpainter);

PluginRegistry _editingRegistry() =>
    fakeRegistry()..register(PluginFactory<Inpainter>(_paintMaskInfo, (c, e) async => _PaintMask()));

class _PaintMask implements Inpainter {
  @override
  PluginInfo get info => _paintMaskInfo;

  @override
  Future<RgbImage> inpaint(RgbImage image, GrayImage mask, InpaintConfig config, PluginContext context) async {
    final cleaned = image.clone();
    for (var i = 0; i < mask.data.length; i++) {
      if (mask.data[i] != 0) cleaned.data.fillRange(i * 3, i * 3 + 3, 255);
    }
    return cleaned;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late AppServices services;
  late ProviderContainer container;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('cts_edit_test_');
    services = AppServices.create(
      dataDirOverride: dir.path,
      secretStore: MemorySecretStore(),
      registry: _editingRegistry(),
    );
    container = ProviderContainer(
      overrides: [
        servicesProvider.overrideWithValue(services),
        initialSettingsProvider.overrideWithValue(fakeSettings()),
        workerRegistryProvider.overrideWithValue(_editingRegistry),
      ],
    );
    final page = p.join(dir.path, 'page.png');
    await ImageCodec.writeFile(page, RgbImage.filled(100, 60, 255, 255, 255));
    await container.read(workspaceProvider.notifier).addInputs([page]);
  });

  tearDown(() async {
    container.dispose();
    await services.dispose();
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Still open somewhere; the folder is in temp.
    }
  });

  WorkspaceNotifier ws() => container.read(workspaceProvider.notifier);
  PageEntry page() => container.read(workspaceProvider).currentPage!;

  test('edits are undo steps; typing merges; undo and redo restore', () {
    final id = page().id;
    ws().edit(
      id,
      (p) => p.copyWith(
        blocks: [TextBlock(xyxy: const BBox(1, 1, 50, 30), text: 'Hi')],
      ),
    );
    expect(container.read(workspaceProvider).canUndo, isTrue);

    ws().editBlock(id, 0, (b) => b.translation = 'П', mergeKey: 'tr:0');
    ws().editBlock(id, 0, (b) => b.translation = 'Привет', mergeKey: 'tr:0');
    expect(container.read(workspaceProvider).history[id]!.undo, hasLength(2), reason: 'typing is one step');

    final before = page().blocks;
    ws().editBlock(id, 0, (b) => b.style = const BlockStyle(fontSizePt: 20));
    expect(identical(before.first, page().blocks.first), isFalse, reason: 'blocks are copied, never changed');
    expect(before.first.style, isNull);

    ws().undo();
    expect(page().blocks.single.style, isNull);
    expect(page().blocks.single.translation, 'Привет');
    ws().undo();
    expect(page().blocks.single.translation, '');
    expect(container.read(workspaceProvider).canRedo, isTrue);
    ws().redo();
    expect(page().blocks.single.translation, 'Привет');
    ws().undo();
    ws().undo();
    expect(page().blocks, isEmpty);
    expect(container.read(workspaceProvider).canUndo, isFalse);
  });

  test('an edit clears the drawn page and the exported mark', () {
    final id = page().id;
    ws().updatePage(id, (p) => p.copyWith(translatedPath: 'x.png', exported: true));
    ws().edit(
      id,
      (p) => p.copyWith(
        blocks: [TextBlock(xyxy: const BBox(1, 1, 50, 30), translation: 'Да')],
      ),
    );
    expect(page().translatedPath, isNull);
    expect(page().exported, isFalse);
    expect(page().isDone, isTrue, reason: 'a translated block is something to export');
  });

  test('all boxes grow, shrink and go at once; one undo step each', () {
    ws().addBlock(const BBox(10, 10, 40, 30));
    ws().addBlock(const BBox(50, 20, 52, 22));
    ws().growAllBlocks(3);
    expect(page().blocks.map((b) => b.xyxy.toJson()), [
      [7, 7, 43, 33],
      [47, 17, 55, 25],
    ]);
    ws().growAllBlocks(-6);
    expect(page().blocks.first.xyxy.toJson(), [13, 13, 37, 27]);
    expect(page().blocks.last.xyxy.toJson(), [49, 19, 53, 23], reason: 'never smaller than 4 px');
    ws().deleteAllBlocks();
    expect(page().blocks, isEmpty);
    ws().undo();
    expect(page().blocks, hasLength(2));
    ws().undo();
    expect(page().blocks.first.xyxy.toJson(), [7, 7, 43, 33]);
  });

  test('blocks found inside a block take its place in one undo step; only they are read', () async {
    ws().addBlock(const BBox(2, 2, 20, 20));
    ws().addBlock(const BBox(10, 10, 90, 50));
    ws().addBlock(const BBox(60, 2, 90, 8));
    final original = page().blocks[1];
    final parts = [TextBlock(xyxy: const BBox(10, 10, 45, 50)), TextBlock(xyxy: const BBox(55, 10, 90, 50))];
    // A page changed meanwhile: nothing happens.
    expect(ws().replaceBlock(page().id, 1, original.copy(), parts), isFalse);
    expect(ws().replaceBlock(page().id, 1, original, parts), isTrue);
    expect(page().blocks.map((b) => b.xyxy.x1), [2, 10, 55, 60]);
    expect(container.read(workspaceProvider).selectedBlock, 1);

    await container.read(stepsProvider.notifier).run(ManualStep.recognize, _YesUi(), blocks: [1, 2]);
    expect([for (final b in page().blocks) b.text.isNotEmpty], [false, true, true, false]);
    ws().undo();
    expect(page().blocks.every((b) => b.text.isEmpty), isTrue);
    ws().undo();
    expect(page().blocks.map((b) => b.xyxy.x1), [2, 10, 60]);
  });

  test('pages picked with Ctrl or Shift: a step runs on each, one undo step per page', () async {
    final more = [
      for (final n in ['p2.png', 'p3.png']) p.join(dir.path, n),
    ];
    for (final f in more) {
      await ImageCodec.writeFile(f, RgbImage.filled(100, 60, 255, 255, 255));
    }
    await ws().addInputs(more);
    expect(container.read(workspaceProvider).stepPages.map((x) => x.name), ['page.png'], reason: 'only the current');

    ws().select(2, range: true);
    expect(container.read(workspaceProvider).selectedPages, hasLength(3));
    ws().select(1, toggle: true);
    expect(container.read(workspaceProvider).stepPages.map((x) => x.name), ['page.png', 'p3.png']);

    final ui = _YesUi();
    await container.read(stepsProvider.notifier).run(ManualStep.translate, ui);
    expect(ui.errors, isEmpty);
    final pages = container.read(workspaceProvider).pages;
    expect([for (final x in pages) x.blocks.isNotEmpty], [true, false, true]);
    expect(pages.first.blocks.single.translation, contains('HELLO'));
    for (final x in [pages.first, pages.last]) {
      expect(container.read(workspaceProvider).history[x.id]!.undo, hasLength(1));
    }
    // The time of the run, for the line under the step buttons.
    final last = container.read(stepsProvider).last!;
    expect((last.step, last.pages, last.count), (ManualStep.translate, 2, 2));
    expect(last.ms.keys, containsAll([ManualStep.detect, ManualStep.recognize, ManualStep.translate]));

    ws().select(0);
    expect(container.read(workspaceProvider).selectedPages, isEmpty, reason: 'a plain click clears the selection');
  });

  test('pages go below a page; the same pictures are added only when picked', () async {
    Future<String> picture(String name, int shade) async {
      final f = p.join(dir.path, name);
      await ImageCodec.writeFile(f, RgbImage.filled(100, 60, shade, shade, shade));
      return f;
    }

    final a = await picture('a.png', 10), b = await picture('b.png', 20), c = await picture('c.png', 30);
    await ws().addInputs([a]);
    ws().select(1);
    await ws().addInputs([b, c], at: 1);
    List<String> names() => [for (final x in container.read(workspaceProvider).pages) x.name];
    expect(names(), ['page.png', 'b.png', 'c.png', 'a.png']);
    expect(page().name, 'a.png', reason: 'the open page stays open');

    await ws().addInputs([await picture('d.png', 40)], at: 0, open: true);
    expect(names().first, 'd.png');
    expect(page().name, 'd.png', reason: 'a pasted page is opened');

    final asked = <List<RepeatedPage>>[];
    final copy = await picture('copy of b.png', 20);
    final outcome = await ws().addInputs(
      [copy, await picture('e.png', 50), a],
      chooseRepeats: (repeats) async {
        asked.add(repeats);
        return {1};
      },
    );
    final repeats = asked.single;
    expect(
      [for (final r in repeats) (r.name, r.sameAs, r.sameAsNumber, p.basename(r.sameAsPath))],
      [('copy of b.png', 'b.png', 3, 'b.png'), ('a.png', 'a.png', 5, 'a.png')],
    );
    expect((outcome.added, outcome.repeatsLeft), (2, 1));
    expect(names(), ['d.png', 'page.png', 'b.png', 'c.png', 'a.png', 'e.png', 'a.png']);
  });

  test('pages sort by name or file date, turn round, and the order comes back', () async {
    final files = <String>[];
    for (final (name, day) in [('p10.png', 3), ('p2.png', 1), ('P1.png', 2)]) {
      final f = p.join(dir.path, name);
      await ImageCodec.writeFile(f, RgbImage.filled(10, 10, day, day, day));
      File(f).setLastModifiedSync(DateTime(2026, 10, day));
      files.add(f);
    }
    File(p.join(dir.path, 'page.png')).setLastModifiedSync(DateTime(2026, 9, 1));
    await ws().addInputs(files);
    ws().select(2);
    List<String> names() => [for (final x in container.read(workspaceProvider).pages) x.name];
    final first = names();

    final before = ws().sortPages(PageOrder.nameUp);
    expect(names(), ['P1.png', 'p2.png', 'p10.png', 'page.png']);
    expect(page().name, 'p2.png', reason: 'the open page stays open');
    ws().sortPages(PageOrder.nameDown);
    expect(names(), ['page.png', 'p10.png', 'p2.png', 'P1.png']);
    ws().sortPages(PageOrder.dateUp);
    expect(names(), ['page.png', 'p2.png', 'P1.png', 'p10.png']);
    ws().sortPages(PageOrder.dateDown);
    expect(names(), ['p10.png', 'P1.png', 'p2.png', 'page.png']);
    ws().sortPages(PageOrder.reverse);
    expect(names(), ['page.png', 'p2.png', 'P1.png', 'p10.png']);

    ws().setPageOrder(before);
    expect(names(), first);
  });

  test('step plans do what is missing first', () {
    final fresh = page();
    expect(StepsNotifier.plan(ManualStep.translate, fresh), [
      ManualStep.detect,
      ManualStep.recognize,
      ManualStep.translate,
    ]);
    expect(StepsNotifier.plan(ManualStep.clean, fresh), [ManualStep.detect, ManualStep.mask, ManualStep.clean]);
    final read = fresh.copyWith(
      blocks: [TextBlock(xyxy: const BBox(1, 1, 5, 5), text: 'Hi')],
    );
    expect(StepsNotifier.plan(ManualStep.translate, read), [ManualStep.translate]);
    expect(StepsNotifier.plan(ManualStep.clean, read.copyWith(maskPath: 'm.png')), [ManualStep.clean]);
  });

  test('retry fills only flagged omissions with recognized text and keeps manual styling', () async {
    final edited = TextBlock(
      xyxy: const BBox(1, 1, 10, 10),
      text: 'Edited',
      translation: 'Manual translation',
      style: const BlockStyle(fontSizePt: 23),
      untranslated: true,
    );
    ws().edit(
      page().id,
      (p) => p.copyWith(
        blocks: [
          edited,
          TextBlock(xyxy: const BBox(12, 1, 20, 10), text: 'Retry me', untranslated: true),
          TextBlock(xyxy: const BBox(22, 1, 30, 10), text: 'Intentional blank'),
          TextBlock(xyxy: const BBox(32, 1, 40, 10), untranslated: true),
        ],
      ),
    );
    final ui = _YesUi();
    final steps = container.read(stepsProvider.notifier);
    await steps.run(ManualStep.translate, ui, retryOmissions: true);

    expect(ui.errors, isEmpty);
    expect(ui.emptyAsked, 0);
    expect(container.read(stepsProvider).last?.count, 1);
    final blocks = page().blocks;
    expect(blocks[0].toJson(), edited.toJson());
    expect(blocks[1].translation.toUpperCase(), endsWith('RETRY ME'));
    expect(blocks[1].untranslated, isFalse);
    expect(blocks[2].translation, isEmpty);
    expect(blocks[3].untranslated, isTrue);
  });

  for (final viaChat in [false, true]) {
    test('retry through ${viaChat ? 'chat' : 'the translator'} cleans only the newly translated frame', () async {
      await container.read(settingsProvider.notifier).change((s) {
        s.inpainter = _paintMaskInfo.id;
        if (viaChat) s.translator = chatTranslatorId;
      });
      final cleanPath = p.join(dir.path, 'clean.png');
      final maskPath = p.join(dir.path, 'draft_mask.png');
      final clean = RgbImage.filled(100, 60, 255, 255, 255);
      // Simulate a retouch on the first frame and dark letters in the second.
      clean.data.setRange(clean.offset(12, 16), clean.offset(13, 16), [185, 200, 220]);
      for (var y = 21; y < 35; y++) {
        clean.data.fillRange(clean.offset(47, y), clean.offset(51, y), 0);
        clean.data.fillRange(clean.offset(78, y), clean.offset(82, y), 0);
      }
      await ImageCodec.writeFile(cleanPath, clean);
      await File(maskPath).writeAsBytes(ImageCodec.encodeGrayPng(GrayImage.zeros(100, 60)));
      final ready = TextBlock(
        xyxy: const BBox(6, 10, 26, 48),
        text: 'Ready',
        translation: 'Edited translation',
        style: const BlockStyle(fontSizePt: 23),
      );
      final pending = TextBlock(xyxy: const BBox(38, 10, 60, 48), text: 'Retry me', untranslated: true);
      final missed = TextBlock(
        xyxy: const BBox(71, 10, 92, 48),
        text: viaChat ? 'Still missing' : '',
        untranslated: true,
      );
      const strokes = [
        MaskStroke(points: [Point2(8, 52), Point2(20, 52)], width: 4),
      ];
      ws().edit(
        page().id,
        (p) => p.copyWith(
          cleanPath: cleanPath,
          translatedPath: cleanPath,
          maskPath: maskPath,
          strokes: strokes,
          blocks: [ready, pending, missed],
        ),
      );
      final ui = _YesUi();
      if (viaChat) {
        ui.answerExchange = (request) async {
          final state = container.read(workspaceProvider);
          final items = exchangeItems(exchangePages(state, request), request.mode);
          expect(items.map((item) => item.blockIndex), [1, 2]);
          final match = matchExchangeAnswer(
            items,
            parseExchangeAnswer('[01-002] New translation', request.mode),
            request.mode,
          );
          final result = await applyExchange(
            ws(),
            state,
            items,
            match,
            request.mode,
            retryOmissions: request.retryOmissions,
            commitOmissions: request.commitOmissions,
          );
          expect(result.changed, 1);
          return true;
        };
      }
      await container.read(stepsProvider.notifier).run(ManualStep.translate, ui, retryOmissions: true);

      expect(ui.errors, isEmpty);
      expect(page().cleanPath, isNot(cleanPath));
      expect(page().translatedPath, isNull);
      expect(page().maskPath, maskPath);
      expect(page().strokes, strokes);
      expect(page().blocks[0].toJson(), ready.toJson());
      expect(page().blocks[1].untranslated, isFalse);
      expect(page().blocks[1].translation, isNotEmpty);
      expect(page().blocks[2].toJson(), missed.toJson());
      final cleaned = await ImageCodec.readFile(page().cleanPath!);
      expect(cleaned.data[cleaned.offset(48, 26)], 255);
      expect(cleaned.data[cleaned.offset(79, 26)], 0);
      expect(cleaned.data[cleaned.offset(12, 16)], 185);
      ws().undo();
      expect(page().cleanPath, cleanPath);
      expect(page().blocks[1].toJson(), pending.toJson());
    });
  }

  test('"Translate" asks about frames without text: read them, translate without them, or stop', () async {
    final ui = _YesUi();
    final steps = container.read(stepsProvider.notifier);
    final id = page().id;
    void frames() => ws().edit(
      id,
      (p) => p.copyWith(
        blocks: [
          TextBlock(xyxy: const BBox(5, 5, 45, 25), text: 'Hi'),
          TextBlock(xyxy: const BBox(50, 5, 95, 25)),
          TextBlock(xyxy: const BBox(5, 30, 45, 55)),
        ],
      ),
    );
    List<(String, bool)> read() => [for (final b in page().blocks) (b.text, b.translation.isNotEmpty)];

    // Stop: nothing is done.
    frames();
    ui.emptyFrames = null;
    await steps.run(ManualStep.translate, ui);
    expect(ui.emptyAsked, 2);
    expect(read(), [('Hi', false), ('', false), ('', false)]);

    // Without them: they stay empty and untranslated.
    ui.emptyFrames = EmptyFrames.skip;
    await steps.run(ManualStep.translate, ui);
    expect(ui.errors, isEmpty);
    expect(read(), [('Hi', true), ('', false), ('', false)]);

    // Read them, remembered: the next time there is no question.
    ui
      ..emptyFrames = EmptyFrames.read
      ..rememberEmpty = true;
    await steps.run(ManualStep.translate, ui);
    expect(read(), [('Hi', true), ('HELLO', true), ('HELLO', true)]);
    expect(container.read(settingsProvider).emptyFrames, EmptyFrames.read);
    frames();
    ui.emptyAsked = 0;
    await steps.run(ManualStep.translate, ui);
    expect(ui.emptyAsked, 0);
    expect(read(), [('Hi', true), ('HELLO', true), ('HELLO', true)]);

    // Chosen in the settings: translated without them, no question.
    await container.read(settingsProvider.notifier).change((s) => s.emptyFrames = EmptyFrames.skip);
    frames();
    await steps.run(ManualStep.translate, ui);
    expect(ui.emptyAsked, 0);
    expect(read(), [('Hi', true), ('', false), ('', false)]);

    // One frame chosen: only it counts.
    await container.read(settingsProvider.notifier).change((s) => s.emptyFrames = EmptyFrames.ask);
    frames();
    ui.rememberEmpty = false;
    await steps.run(ManualStep.translate, ui, block: 1);
    expect(ui.emptyAsked, 1);
    expect(read(), [('Hi', false), ('HELLO', true), ('', false)]);
  });

  test('reading by a model through the network: its key first, then the question about sending pictures', () async {
    await container.read(settingsProvider.notifier).change((s) => s.ocr = 'openrouter_ocr');
    ws().edit(page().id, (p) => p.copyWith(blocks: [TextBlock(xyxy: const BBox(5, 5, 45, 25))]));
    final ui = _YesUi()..network = NetworkChoice.cancel;
    await container.read(stepsProvider.notifier).run(ManualStep.recognize, ui);
    expect(ui.missingKey, ['openrouter_ocr']);
    expect(ui.networkAsked, isEmpty);

    // The key of the OpenRouter translator serves the reading too.
    await services.secrets.write(pluginSecretKey('openrouter', 'api_key'), 'sk-or-test');
    ui.missingKey.clear();
    await container.read(stepsProvider.notifier).run(ManualStep.recognize, ui);
    expect(ui.missingKey, isEmpty);
    expect(ui.networkAsked, [('openrouter_ocr', true)]);
    expect(page().blocks.single.text, '', reason: 'sending was not allowed: nothing read');
  });

  test('a page without frames is found and read with no question', () async {
    final ui = _YesUi();
    await container.read(stepsProvider.notifier).run(ManualStep.translate, ui);
    expect(ui.emptyAsked, 0);
    expect(page().blocks.single.text, 'HELLO');
  });

  test('translate a fresh page, make the mask, clean, then draw it for export', () async {
    final ui = _YesUi();
    final steps = container.read(stepsProvider.notifier);
    await steps.run(ManualStep.translate, ui);
    expect(ui.errors, isEmpty);
    final b = page().blocks.single;
    expect((b.text, b.translation.contains('HELLO')), ('HELLO', true));
    expect(container.read(workspaceProvider).history[page().id]!.undo, hasLength(1), reason: 'one step, one undo');

    await steps.run(ManualStep.mask, ui);
    expect(page().maskPath, isNotNull);
    expect(container.read(editorProvider).tool, EditorTool.brush, reason: 'ready to correct the mask');
    ws().edit(
      page().id,
      (p) => p.copyWith(
        strokes: const [
          MaskStroke(points: [Point2(5, 5), Point2(20, 5)], width: 4),
        ],
      ),
    );

    await steps.run(ManualStep.clean, ui);
    expect(ui.errors, isEmpty);
    expect(page().cleanPath, isNotNull);
    expect(page().maskPath, isNull);
    expect(page().strokes, isEmpty);
    expect(container.read(stepsProvider).last?.step, ManualStep.clean);
    expect(container.read(stepsProvider).last?.ms.keys, [ManualStep.clean], reason: 'the mask was there');

    final drawn = await drawMissingPages(container.read, [page().id]);
    expect(File(drawn.single.translatedPath!).existsSync(), isTrue);
    expect(container.read(stepsProvider).running, isFalse);
  });

  test('"Translate all" asks before translating again pages changed by hand', () async {
    final ui = _YesUi();
    final batch = container.read(batchProvider.notifier);
    await batch.run(ui);
    expect(page().isDone, isTrue);
    expect(page().handEdited, isFalse, reason: 'translated by the program');
    final report = (container.read(batchProvider) as BatchIdle).last!;
    expect(report.stageMs.keys, ['01_detect', '02_ocr', '03_translate', '04_mask', '05_inpaint', '06_render']);
    expect(ui.handEditedAsked, 0);

    ws().editBlock(page().id, 0, (b) => b.translation = 'Моё');
    expect(page().handEdited, isTrue);

    ui.handEdited = HandEditedChoice.skip;
    await batch.run(ui);
    expect(ui.handEditedAsked, 1);
    expect(page().blocks.single.translation, 'Моё', reason: 'skipped');

    ui.handEdited = HandEditedChoice.translate;
    await batch.run(ui);
    expect(page().blocks.single.translation, isNot('Моё'));
    expect(page().handEdited, isFalse);

    ws().undo();
    expect(page().blocks.single.translation, 'Моё', reason: 'the hand-made text comes back');
    expect(page().handEdited, isTrue);
  });

  test('pages picked by numbers; "Translate selected" translates only them', () async {
    final more = [
      for (final n in ['p2.png', 'p3.png', 'p4.png']) p.join(dir.path, n),
    ];
    for (final f in more) {
      await ImageCodec.writeFile(f, RgbImage.filled(100, 60, 255, 255, 255));
    }
    await ws().addInputs(more);
    ws().pickPages(parsePageNumbers('2, 4', 4));
    var state = container.read(workspaceProvider);
    expect(state.stepPages.map((x) => x.name), ['p2.png', 'p4.png']);
    expect(state.currentPage!.name, 'p2.png', reason: 'the current page was not picked: the first one opens');

    ws().pickPages({2});
    state = container.read(workspaceProvider);
    expect(state.selectedPages, isEmpty);
    expect(state.currentPage!.name, 'p3.png', reason: 'one page is just opened');

    ws().pickPages({0, 3});
    state = container.read(workspaceProvider);
    await container.read(batchProvider.notifier).run(_YesUi(), only: state.selectedPages);
    final pages = container.read(workspaceProvider).pages;
    expect([for (final x in pages) x.isDone], [true, false, false, true]);
  });

  test('several pages go at once; the open one stays, or the next one opens', () async {
    final more = [
      for (final n in ['p2.png', 'p3.png', 'p4.png', 'p5.png']) p.join(dir.path, n),
    ];
    for (final f in more) {
      await ImageCodec.writeFile(f, RgbImage.filled(100, 60, 255, 255, 255));
    }
    await ws().addInputs(more);
    List<String> names() => [for (final x in container.read(workspaceProvider).pages) x.name];
    String id(String name) => container.read(workspaceProvider).pages.firstWhere((x) => x.name == name).id;

    ws().select(3);
    ws().removePages({id('page.png'), id('p3.png')});
    expect(names(), ['p2.png', 'p4.png', 'p5.png']);
    expect(page().name, 'p4.png', reason: 'the open page stays open');

    ws().pickPages({0, 1});
    ws().removePages({...container.read(workspaceProvider).selectedPages});
    expect(names(), ['p5.png']);
    expect(page().name, 'p5.png', reason: 'the open page went: the next one opens');
    expect(container.read(workspaceProvider).selectedPages, isEmpty);

    // Ctrl+Z brings back the last pages taken out, where they were, with
    // the page that was open.
    expect(container.read(workspaceProvider).canUndo, isTrue);
    ws().undo();
    expect(names(), ['p2.png', 'p4.png', 'p5.png']);
    expect(page().name, 'p4.png');
  });

  test('pages taken out come back with their undo history; a change of a page forgets them', () async {
    final more = [
      for (final n in ['p2.png', 'p3.png']) p.join(dir.path, n),
    ];
    for (final f in more) {
      await ImageCodec.writeFile(f, RgbImage.filled(100, 60, 255, 255, 255));
    }
    await ws().addInputs(more);
    List<String> names() => [for (final x in container.read(workspaceProvider).pages) x.name];
    String id(String name) => container.read(workspaceProvider).pages.firstWhere((x) => x.name == name).id;

    final p2 = id('p2.png');
    ws().edit(
      p2,
      (x) => x.copyWith(
        blocks: [TextBlock(xyxy: const BBox(1, 1, 9, 9), translation: 'Привет')],
      ),
    );
    ws().removePages({p2});
    ws().undo();
    expect(names(), ['page.png', 'p2.png', 'p3.png']);
    ws().select(1);
    expect(container.read(workspaceProvider).canUndo, isTrue, reason: 'its own history came back');
    ws().undo();
    expect(page().blocks, isEmpty);

    ws().removePages({id('p3.png')});
    ws().edit(id('page.png'), (x) => x.copyWith(blocks: [TextBlock(xyxy: const BBox(1, 1, 9, 9))]));
    ws().undo();
    expect(names(), ['page.png', 'p2.png'], reason: 'the undo went to the change, not to the removal');
  });
}
