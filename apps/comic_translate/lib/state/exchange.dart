/// The exchange with a chat AI by hand: which rounds the chosen engines
/// need, the exchange folder (written in the background) and the chat's
/// answer written into the pages.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:path/path.dart' as p;

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
  final old = root.listSync().whereType<Directory>().toList()..sort((a, b) => b.path.compareTo(a.path));
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
    final withImages = [
      for (final page in pages)
        ExchangePage(
          id: page.id,
          number: page.number,
          name: page.name,
          blocks: page.blocks,
          only: page.only,
          image: (mode.sendsImages || exchange.contextImage != ContextImage.off) && paths[page.id] != null
              ? await ImageCodec.readFile(paths[page.id]!)
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
/// Returns how many blocks changed and the pieces whose block is gone.
({int changed, List<ExchangeLabel> lost}) applyExchange(
  WorkspaceNotifier workspace,
  WorkspaceState ws,
  List<ExchangeItem> items,
  ExchangeMatch match,
  ExchangeMode mode, {
  String placeholder = '',
}) {
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
        blocks[i] = b;
        changed++;
        any = true;
      }
    }
    if (any) workspace.edit(id, (p) => p.copyWith(blocks: blocks), byHand: false);
  }
  return (changed: changed, lost: lost);
}
