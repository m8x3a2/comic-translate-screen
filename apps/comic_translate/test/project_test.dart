// Projects: saving, opening, autosave and crash recovery.

import 'dart:io';

import 'package:comic_translate/bootstrap.dart';
import 'package:comic_translate/state/app_state.dart';
import 'package:comic_translate/state/batch.dart';
import 'package:comic_translate/state/exchange.dart';
import 'package:comic_translate/state/project.dart';
import 'package:comic_translate/state/shelf.dart';
import 'package:comic_translate/state/workspace.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/fake_plugins.dart';

class _YesUi implements BatchUi {
  @override
  Future<bool> exchange(ExchangeRequest request) async => false;

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
  void showError(Object error) => fail('$error');

  @override
  Future<({EmptyFrames choice, bool remember})?> confirmEmptyFrames(int count) async =>
      (choice: EmptyFrames.read, remember: false);

  @override
  Future<HandEditedChoice> confirmHandEdited(int count) async => HandEditedChoice.translate;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late AppServices services;
  final containers = <ProviderContainer>[];

  ProviderContainer start() {
    final c = ProviderContainer(
      overrides: [
        servicesProvider.overrideWithValue(services),
        initialSettingsProvider.overrideWithValue(fakeSettings()),
        workerRegistryProvider.overrideWithValue(fakeRegistry),
      ],
    );
    c.listen(projectProvider, (_, _) {});
    containers.add(c);
    return c;
  }

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('cts_project_app_test_');
    services = AppServices.create(
      dataDirOverride: dir.path,
      secretStore: MemorySecretStore(),
      registry: fakeRegistry(),
    );
    Directory(p.join(dir.path, 'chapter')).createSync();
    for (final (i, name) in ['001.png', '002.png'].indexed) {
      await ImageCodec.writeFile(p.join(dir.path, 'chapter', name), RgbImage.filled(80 + i, 60, 255, 255, 255));
    }
  });

  tearDown(() async {
    for (final c in containers) {
      c.dispose();
    }
    containers.clear();
    // A project remembered just before the end is still being written to the
    // settings; the folder goes only after that.
    await services.settingsStore.flush();
    await services.dispose();
    try {
      dir.deleteSync(recursive: true);
    } on FileSystemException {
      // still open; the folder is in temp
    }
  });

  Future<void> openPages(ProviderContainer c) =>
      c.read(workspaceProvider.notifier).addInputs([p.join(dir.path, 'chapter')]);

  void translate(ProviderContainer c, String id, String text) => c
      .read(workspaceProvider.notifier)
      .edit(
        id,
        (page) => page.copyWith(
          status: PageStatus.done,
          blocks: [
            TextBlock(
              xyxy: const BBox(5, 5, 50, 30),
              text: 'Hello',
              translation: text,
              style: const BlockStyle(bold: true, fontSizePt: 18),
            ),
          ],
          strokes: const [
            MaskStroke(points: [Point2(10, 10)], width: 8),
          ],
        ),
      );

  Future<void> until(bool Function() done, {Duration limit = const Duration(seconds: 15)}) async {
    final sw = Stopwatch()..start();
    while (!done()) {
      if (sw.elapsed > limit) fail('timed out');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  test('save, close and open again: pages, text, style, strokes and status come back', () async {
    final c = start();
    await openPages(c);
    final ws = c.read(workspaceProvider);
    translate(c, ws.pages.first.id, 'Привет');
    c.read(workspaceProvider.notifier)
      ..select(1)
      ..setGlossary('Kai --> Кай\n');
    expect(c.read(projectProvider).dirty, isTrue);
    expect(c.read(projectProvider).path, isNull);

    final path = p.join(dir.path, 'out', 'Глава 1.ctsproj');
    expect(await c.read(projectProvider.notifier).save(to: path), isTrue);
    expect(c.read(projectProvider).path, path);
    expect(c.read(projectProvider).dirty, isFalse);
    expect(c.read(settingsProvider).recentProjects.first, path);
    expect(ProjectFile.info(path).pages, 2);

    c.read(workspaceProvider.notifier).clear();
    expect(c.read(projectProvider).path, isNull, reason: 'closing all pages closes the project');
    expect(c.read(workspaceProvider).glossary, '', reason: 'the glossary goes with the project');

    await c.read(projectProvider.notifier).open(path);
    final back = c.read(workspaceProvider);
    expect(back.pages.map((x) => x.name), ['001.png', '002.png']);
    expect(back.current, 1);
    expect(back.glossary, 'Kai --> Кай\n');
    final first = back.pages.first;
    expect(first.status, PageStatus.done);
    expect(first.blocks.single.translation, 'Привет');
    expect(first.blocks.single.style!.fontSizePt, 18);
    expect(first.strokes.single.width, 8);
    expect(File(first.path).existsSync(), isTrue);
    expect(c.read(projectProvider).dirty, isFalse, reason: 'opening is not a change');

    // A change saves itself shortly after.
    translate(c, first.id, 'Привет!');
    expect(c.read(projectProvider).dirty, isTrue);
    await until(() => !c.read(projectProvider).dirty);
    final saved = ProjectFile.load(path, Directory(p.join(dir.path, 'check')));
    expect(saved.pages.first.blocks.single.translation, 'Привет!');
  });

  test('touch-ups: one undo step each, drawn into a file, kept by the project', () async {
    final c = start();
    await openPages(c);
    final ws = c.read(workspaceProvider.notifier);
    final id = c.read(workspaceProvider).pages.first.id;
    ws.addPaint(
      const PaintOp(kind: PaintKind.brush, points: [Point2(20, 20)], width: 10, color: 0xFFFF0000),
      pageId: id,
    );
    ws.addPaint(
      const PaintOp(kind: PaintKind.fill, color: 0xFF0000FF, runs: [0, 0, 5]),
      pageId: id,
    );
    var page = c.read(workspaceProvider).byId(id)!;
    expect(page.paints, hasLength(2));
    expect(page.paintsReady, isFalse);
    expect(page.finalBasePath, page.path, reason: 'until drawn in, the cleaned page');

    page = (await ws.ensurePainted(id))!;
    expect(page.paintedPath, isNotNull);
    final image = await ImageCodec.readFile(page.finalBasePath);
    (int, int, int) at(int x, int y) {
      final i = image.offset(x, y);
      return (image.data[i], image.data[i + 1], image.data[i + 2]);
    }

    expect(at(20, 20), (255, 0, 0));
    expect(at(2, 0), (0, 0, 255));
    expect(at(60, 50), (255, 255, 255));
    expect(File(page.path).existsSync(), isTrue);

    // Undo takes the fill back; the drawn file was made after it, so it goes too.
    ws.undo();
    page = c.read(workspaceProvider).byId(id)!;
    expect(page.paints.single.kind, PaintKind.brush);
    expect(page.paintedPath, isNull);

    final path = p.join(dir.path, 'out', 'paints.ctsproj');
    expect(await c.read(projectProvider.notifier).save(to: path), isTrue);
    ws.clear();
    await c.read(projectProvider.notifier).open(path);
    final back = c.read(workspaceProvider).pages.first;
    expect(back.paints.single.toJson(), page.paints.single.toJson());

    // Removing them all is one step too.
    ws.select(0);
    ws.clearPaints();
    expect(c.read(workspaceProvider).pages.first.paints, isEmpty);
    ws.undo();
    expect(c.read(workspaceProvider).pages.first.paints, hasLength(1));
  });

  test('the shelf is kept in the project; closing the pages empties it', () async {
    final c = start();
    await openPages(c);
    final ws = c.read(workspaceProvider);
    translate(c, ws.pages.first.id, 'На полку');
    c.read(shelfProvider.notifier).putBubbles([0]);
    expect(c.read(shelfProvider).single.block!.translation, 'На полку');
    final path = p.join(dir.path, 'out', 'shelf.ctsproj');
    expect(await c.read(projectProvider.notifier).save(to: path), isTrue);
    c.read(workspaceProvider.notifier).clear();
    expect(c.read(shelfProvider), isEmpty);
    await c.read(projectProvider.notifier).open(path);
    expect(c.read(shelfProvider).single.block!.translation, 'На полку');
    expect(c.read(projectProvider).dirty, isFalse);
    c.read(shelfProvider.notifier).remove(0);
    expect(c.read(projectProvider).dirty, isTrue, reason: 'a change of the shelf is a change of the project');
  });

  test('autosave can be turned off; Ctrl+S still saves', () async {
    final c = start();
    await c.read(settingsProvider.notifier).change((s) => s.projectAutosave = false);
    await openPages(c);
    final path = p.join(dir.path, 'manual.ctsproj');
    await c.read(projectProvider.notifier).save(to: path);
    translate(c, c.read(workspaceProvider).pages.first.id, 'Да');
    await Future<void>.delayed(ProjectNotifier.autosaveDelay + const Duration(seconds: 1));
    expect(c.read(projectProvider).dirty, isTrue);
    expect(ProjectFile.load(path, Directory(p.join(dir.path, 'c1'))).pages.first.blocks, isEmpty);
    expect(await c.read(projectProvider.notifier).save(), isTrue);
    expect(ProjectFile.load(path, Directory(p.join(dir.path, 'c2'))).pages.first.blocks.single.translation, 'Да');
  });

  test('unsaved work is copied for recovery; the next run can restore it', () async {
    final first = start();
    await openPages(first);
    translate(first, first.read(workspaceProvider).pages.first.id, 'Спасено');
    await first.read(projectProvider.notifier).writeRecovery();
    expect(first.read(projectProvider.notifier).findRecovery()!.pages, 2);

    // A second window does not take over the copy.
    final second = start();
    expect(second.read(projectProvider.notifier).findRecovery(), isNull);
    second.dispose();
    containers.remove(second);

    // The program "crashed"; it starts again.
    first.dispose();
    containers.remove(first);
    final next = start();
    final recovery = next.read(projectProvider.notifier).findRecovery();
    expect(recovery, isNotNull);
    expect(recovery!.saved, isNotNull);
    await next.read(projectProvider.notifier).restoreRecovery();
    final ws = next.read(workspaceProvider);
    expect(ws.pages.first.blocks.single.translation, 'Спасено');
    expect(next.read(projectProvider).dirty, isTrue);
    expect(next.read(projectProvider).path, isNull);

    // Saving it as a project removes the copy.
    expect(await next.read(projectProvider.notifier).save(to: p.join(dir.path, 'saved.ctsproj')), isTrue);
    expect(next.read(projectProvider.notifier).findRecovery(), isNull);
  });

  test('each page keeps its languages: translate all uses them, the project keeps them', () async {
    final c = start();
    await openPages(c);
    final ws = c.read(workspaceProvider.notifier);
    expect(c.read(workspaceProvider).pages.map((x) => x.targetLanguage), ['Russian', 'Russian']);
    ws.select(1);
    ws.setLanguages(target: 'German');
    expect(c.read(workspaceProvider).pages.map((x) => x.targetLanguage), ['Russian', 'German']);

    await c.read(batchProvider.notifier).run(_YesUi());
    final pages = c.read(workspaceProvider).pages;
    expect(pages.first.blocks.single.translation, startsWith('[ru]'));
    expect(pages.last.blocks.single.translation, startsWith('[de]'));

    final path = p.join(dir.path, 'langs.ctsproj');
    await c.read(projectProvider.notifier).save(to: path);
    await c.read(projectProvider.notifier).open(path);
    expect(c.read(workspaceProvider).pages.map((x) => x.targetLanguage), ['Russian', 'German']);

    // "For all pages".
    ws.setLanguages(source: 'Japanese', target: 'English', all: true);
    expect(c.read(workspaceProvider).pages.map((x) => '${x.sourceLanguage}>${x.targetLanguage}'), [
      'Japanese>English',
      'Japanese>English',
    ]);
  });

  test('skip reasons survive a project file', () {
    for (final reason in <SkipReason>[
      const ModelMissingReason('aot'),
      const TranslationFailedReason(TranslationErrorKind.credits, 'HTTP 402'),
      const WorkerStoppedReason(),
      const UnreadableImageReason(),
      const OtherReason('x'),
    ]) {
      final back = skipReasonFromJson(skipReasonToJson(reason));
      expect(back.runtimeType, reason.runtimeType);
      expect(skipReasonToJson(back!), skipReasonToJson(reason));
    }
  });
}
