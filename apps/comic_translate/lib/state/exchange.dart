/// The exchange with a chat AI by hand: which rounds the chosen engines
/// need, the exchange folder (written in the background) and the chat's
/// answer written into the pages.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:path/path.dart' as p;

import '../pipeline/page_pipeline.dart';
import '../render/mask_raster.dart' show imageFileSize;
import 'background.dart';
import 'workspace.dart';

/// What the exchange window works on.
class ExchangeRequest {
  const ExchangeRequest({
    required this.pageIds,
    required this.mode,
    this.only = const {},
    this.fromRun = false,
    this.modeFixed = false,
  });

  /// In page order.
  final List<String> pageIds;
  final ExchangeMode mode;

  /// Page id → only these blocks (0-based); pages not named: all blocks.
  final Map<String, List<int>> only;

  /// Opened by "Translate all" or a step: the work goes on after "Apply".
  final bool fromRun;

  /// "Translate all" goes on in its own order after "Apply": the window
  /// cannot switch to another mode.
  final bool modeFixed;
}

/// The rounds of the exchange that reading ([read]) and translating
/// ([translate]) with the engines of [settings] need, in order.
List<ExchangeMode> chatRounds(AppSettings settings, {bool read = true, bool translate = true}) {
  final r = read && readsThroughChat(settings), t = translate && translatesThroughChat(settings);
  if (r && t) {
    return settings.exchange.together ? [ExchangeMode.both] : [ExchangeMode.recognize, ExchangeMode.translate];
  }
  return [if (r) ExchangeMode.recognize, if (t) ExchangeMode.translate];
}

/// Exchange folders kept in the data folder (older ones are removed when a
/// new exchange window opens, never while one is open).
const keptExchangeFolders = 20;

/// A new folder under `exchange` in the data folder, one per exchange
/// window.
Directory newExchangeDir(AppPaths paths) {
  final root = Directory(p.join(paths.root.path, 'exchange'))..createSync(recursive: true);
  // An exchange with answers not applied yet stays (see [ExchangeDraft]).
  final old = root.listSync().whereType<Directory>().where((d) => !ExchangeDraft.holdsAnswers(d)).toList()
    ..sort((a, b) => b.path.compareTo(a.path));
  for (final d in old.skip(keptExchangeFolders - 1)) {
    try {
      d.deleteSync(recursive: true);
    } on FileSystemException {
      // Open in Explorer or in use: next time.
    }
  }
  final t = DateTime.now();
  String two(int v) => '$v'.padLeft(2, '0');
  final stamp = '${t.year}${two(t.month)}${two(t.day)}_${two(t.hour)}${two(t.minute)}${two(t.second)}';
  var dir = Directory(p.join(root.path, stamp));
  for (var n = 2; dir.existsSync(); n++) {
    dir = Directory(p.join(root.path, '${stamp}_$n'));
  }
  return dir..createSync();
}

/// The pages of [request] (without pictures), numbered by their place
/// among all pages.
List<ExchangePage> exchangePages(WorkspaceState ws, ExchangeRequest request) => [
  for (final id in request.pageIds)
    if (ws.pages.indexWhere((p) => p.id == id) case final i when i >= 0)
      ExchangePage(id: id, number: i + 1, name: ws.pages[i].name, blocks: ws.pages[i].blocks, only: request.only[id]),
];

/// Writes the exchange folder for [pages] in the background (see
/// [writeExchange] for [keepTexts], [promptText] and [lead]).
Future<ExchangeExport> exportExchange(
  Directory dir,
  WorkspaceState ws,
  List<ExchangePage> pages,
  ExchangeMode mode,
  AppSettings settings, {
  List<List<int>> groups = const [],
  bool keepTexts = false,
  String? promptText,
  String lead = '',
}) {
  final first = ws.byId(pages.isEmpty ? '' : pages.first.id);
  final source = first?.sourceOf(settings) ?? settings.sourceLanguage;
  final target = first?.targetOf(settings) ?? settings.targetLanguage;
  final paths = {for (final page in pages) page.id: ws.byId(page.id)?.path};
  final exchange = settings.exchange;
  final context = settings.extraContext;
  final glossary = ws.glossary;
  final screens = settings.contentKind == ContentKind.screens;
  return Isolate.run(() async {
    // Each page is read when its pieces are cut, not all of them first.
    final withImages = [
      for (final page in pages)
        ExchangePage(
          id: page.id,
          number: page.number,
          name: page.name,
          blocks: page.blocks,
          only: page.only,
          loadImage: (mode.sendsImages || exchange.contextImage != ContextImage.off) && paths[page.id] != null
              ? () => ImageCodec.readFile(paths[page.id]!)
              : null,
        ),
    ];
    return writeExchange(
      dir,
      withImages,
      mode,
      exchange,
      sourceLanguage: source,
      targetLanguage: target,
      extraContext: context,
      glossary: glossary,
      screens: screens,
      groups: groups,
      keepTexts: keepTexts,
      promptText: promptText,
      lead: lead,
      previews: true,
    );
  });
}

/// Writes the chat's answers into the pages (one undo step per page).
/// Blocks whose original text the chat gave anew get their letters measured
/// on the page, as after our own reading ("Pick a font", "Style as in the
/// original"). Returns how many blocks changed and the pieces whose block is
/// gone.
Future<({int changed, List<ExchangeLabel> lost})> applyExchange(
  WorkspaceNotifier workspace,
  WorkspaceState ws,
  List<ExchangeItem> items,
  ExchangeMatch match,
  ExchangeMode mode, {
  String placeholder = '',
}) async {
  var changed = 0;
  final lost = <ExchangeLabel>[];
  final byPage = <String, List<ExchangeItem>>{};
  for (final it in items) {
    (byPage[it.pageId] ??= []).add(it);
  }
  for (final MapEntry(key: id, value: own) in byPage.entries) {
    final page = ws.byId(id);
    if (page == null) {
      lost.addAll(own.map((it) => it.label));
      continue;
    }
    final blocks = [...page.blocks];
    final read = <int>{};
    var any = false;
    for (final it in own) {
      // Left as it was in the text files: the bubble stays (no placeholder).
      if (match.unchanged.contains(it.label)) continue;
      final i = findExchangeBlock(blocks, it);
      if (i == null) {
        lost.add(it.label);
        continue;
      }
      final b = blocks[i].copy();
      if (applyExchangeReply(b, match.replies[it.label], mode, placeholder: placeholder)) {
        if (b.text != blocks[i].text) read.add(i);
        blocks[i] = b;
        changed++;
        any = true;
      }
    }
    if (read.isNotEmpty) {
      final which = read.toList()..sort();
      try {
        final styles = await measureStylesInBackground(page.path, [for (final i in which) blocks[i]]);
        for (final (k, i) in which.indexed) {
          blocks[i].sourceStyle = styles[k];
        }
      } on Object {
        // The page image is gone or unreadable: the text is still the chat's.
      }
    }
    if (any) workspace.edit(id, (p) => p.copyWith(blocks: blocks), byHand: false);
  }
  return (changed: changed, lost: lost);
}

/// Share of the length that fits a bubble well once letters at the size
/// they came out are made 1.3 times larger (the area grows with its square).
const _roomierShare = 1 / (1.3 * 1.3);

/// The translations of [match] that would come out at the smallest font
/// size or not fit their bubbles, each with how many characters would fit
/// well. They are laid out as export draws them, with the page enlarged as
/// usual (not further, as it would be for many that do not fit).
Future<List<ShorterAsk>> tooLongReplies(
  WorkspaceState ws,
  AppSettings settings,
  List<ExchangeItem> items,
  ExchangeMatch match,
  ExchangeMode mode,
) async {
  final byPage = <String, List<ExchangeItem>>{};
  for (final it in items) {
    if (match.replies[it.label]?.translation?.trim().isNotEmpty ?? false) (byPage[it.pageId] ??= []).add(it);
  }
  final found = <ShorterAsk>[];
  for (final MapEntry(key: id, value: own) in byPage.entries) {
    final page = ws.byId(id);
    if (page == null) continue;
    final blocks = [for (final b in page.blocks) b.copy()];
    final asked = <int, ExchangeLabel>{};
    for (final it in own) {
      final i = findExchangeBlock(blocks, it);
      if (i == null) continue;
      applyExchangeReply(blocks[i], match.replies[it.label], mode);
      asked[i] = it.label;
    }
    if (asked.isEmpty) continue;
    final target = page.targetOf(settings);
    final (w, h) = await imageFileSize(page.path);
    final engines = await loadTextEngines(settings, target, blocks);
    final up = settings.upscale;
    final scale = up.mode == UpscaleMode.auto ? autoUpscaleFactor(blocks, w, h) : fixedUpscaleFactor(up, w, h);
    final layout = layoutRender(w, h, blocks, settings, engines, targetLanguage: target, scale: scale);
    for (final (k, item) in layout.items.indexed) {
      if (k >= layout.blockIndex.length) break;
      final i = layout.blockIndex[k];
      final label = asked[i];
      if (label == null) continue;
      final s = item.settings ?? settings.render;
      final over = textOverflows(item, settings.render);
      // A size set by hand (the smallest and the largest the same) is no sign.
      final smallest = s.minFontSize < s.maxFontSize && item.fontSizePt <= s.minFontSize;
      if (!over && !smallest) continue;
      final box = blocks[i].xyxy;
      final spill = box.width * box.height <= 0
          ? 1.0
          : (item.width * item.height / (box.width * box.height)).clamp(1.0, double.infinity);
      final text = blocks[i].translation;
      final limit = (text.length * _roomierShare / spill).floor().clamp(2, text.length);
      found.add(ShorterAsk(label, limit, text));
    }
  }
  return found..sort((a, b) => a.label.compareTo(b.label));
}
