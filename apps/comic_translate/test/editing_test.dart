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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/fake_plugins.dart';

class _YesUi implements BatchUi {
  @override
  Future<bool> exchange(ExchangeRequest request) async => false;

  final errors = <Object>[];

  @override
  Future<void> explainMissingKey(PluginInfo translator, String host) async {}

  @override
  Future<bool> confirmDownload(List<ModelSpec> models) async => true;

  @override
  Future<NetworkChoice> confirmNetwork(
    PluginInfo translator,
    PluginEndpoint endpoint, {
    required bool sendsImage,
  }) async => NetworkChoice.once;

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
      registry: fakeRegistry(),
    );
    container = ProviderContainer(
      overrides: [
        servicesProvider.overrideWithValue(services),
        initialSettingsProvider.overrideWithValue(fakeSettings()),
        workerRegistryProvider.overrideWithValue(fakeRegistry),
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
    expect([for (final r in repeats) (r.name, r.sameAs, r.sameAsNumber, p.basename(r.sameAsPath))], [
      ('copy of b.png', 'b.png', 3, 'b.png'),
      ('a.png', 'a.png', 5, 'a.png'),
    ]);
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
}
