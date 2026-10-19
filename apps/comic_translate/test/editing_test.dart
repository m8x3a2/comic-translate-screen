// Editing a page: undo history and the single steps of the editor.

import 'dart:io';

import 'package:comic_translate/bootstrap.dart';
import 'package:comic_translate/state/app_state.dart';
import 'package:comic_translate/state/batch.dart';
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

    final drawn = await drawMissingPages(container.read, [page().id]);
    expect(File(drawn.single.translatedPath!).existsSync(), isTrue);
    expect(container.read(stepsProvider).running, isFalse);
  });
}
