/// The exchange folder: what the user sends to the chat and where the
/// answer can come back.
///
/// ```
/// prompt.txt            instructions (with the text, when translating)
/// sheet_01.png …        cut-outs with labels, put together
/// page_01_context.jpg   whole pages with the labels (when asked for)
/// crops/01-003.png      single cut-outs (when asked for)
/// ALL.txt, page_01.txt  one line per label: paste the chat's answer here
/// exchange.json         what was sent (pages, blocks, boxes)
/// ```
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../image/cv_bridge.dart';
import '../image/raster.dart';
import '../model/text_block.dart';
import '../translation/llm_protocol.dart';
import 'exchange_answer.dart';
import 'exchange_prompt.dart';
import 'exchange_settings.dart';
import 'exchange_sheets.dart';

const exchangeManifestName = 'exchange.json';
const exchangeAllName = 'ALL.txt';
const exchangePromptName = 'prompt.txt';

String exchangePageTextName(int page) => 'page_${'$page'.padLeft(2, '0')}.txt';

/// A page to send.
class ExchangePage {
  const ExchangePage({
    required this.id,
    required this.number,
    required this.name,
    required this.blocks,
    this.image,
    this.only,
  });

  final String id;

  /// Its place among all pages, from 1 (the first part of the labels).
  final int number;
  final String name;
  final List<TextBlock> blocks;

  /// Needed when pictures are sent.
  final RgbImage? image;

  /// Only these blocks (0-based); null: all.
  final List<int>? only;
}

/// The pieces of [pages] the chat gets for [mode]: every block when it
/// reads the text, blocks with text when it only translates.
List<ExchangeItem> exchangeItems(List<ExchangePage> pages, ExchangeMode mode) => [
  for (final page in pages)
    for (final (i, b) in page.blocks.indexed)
      if ((page.only == null || page.only!.contains(i)) &&
          (mode != ExchangeMode.translate || hasTranslatableContent(b.text)))
        ExchangeItem(
          label: ExchangeLabel(page.number, i + 1),
          pageId: page.id,
          blockIndex: i,
          box: b.xyxy,
          text: b.text,
          translation: b.translation,
        ),
];

/// What [writeExchange] made.
class ExchangeExport {
  const ExchangeExport({
    required this.dir,
    required this.mode,
    required this.items,
    required this.prompt,
    this.sheets = const [],
    this.contexts = const [],
    this.crops = const [],
  });

  final String dir;
  final ExchangeMode mode;
  final List<ExchangeItem> items;
  final String prompt;

  /// Files in [dir] to send, in order.
  final List<String> sheets;
  final List<String> contexts;
  final List<String> crops;

  /// Everything to attach in the chat: the pages first, then the sheets (or
  /// the single cut-outs when there are no sheets).
  List<String> get pictures => [...contexts, ...(sheets.isNotEmpty ? sheets : crops)];
}

/// Writes the exchange folder [dir] for [pages]. [groups]: the user's own
/// grouping of the pieces into sheets (see [parseSheetGroups]).
Future<ExchangeExport> writeExchange(
  Directory dir,
  List<ExchangePage> pages,
  ExchangeMode mode,
  ExchangeSettings settings, {
  required String sourceLanguage,
  required String targetLanguage,
  String extraContext = '',
  bool screens = false,
  List<List<int>> groups = const [],
}) async {
  await dir.create(recursive: true);
  final items = exchangeItems(pages, mode);
  // Sheets of cut-outs when the chat reads; pictures of whole pages when
  // asked for (they help when only translating too).
  final pictures = mode.sendsImages;
  final contextWanted = settings.contextImage != ContextImage.off;
  final sheets = <String>[], contexts = <String>[], crops = <String>[];
  final sheetLabels = <List<String>>[];
  if ((pictures || contextWanted) && items.isNotEmpty) {
    final byId = {for (final pg in pages) pg.id: pg};
    final pieces = <SheetPiece>[];
    final onSheet = settings.contextImage == ContextImage.onSheet && pictures && settings.images.hasSheets;
    for (final page in pages) {
      final image = page.image;
      final own = [
        for (final it in items)
          if (it.pageId == page.id) it,
      ];
      if (image == null || own.isEmpty) continue;
      if (contextWanted) {
        final boxes = [for (final it in own) (it.label, it.box)];
        if (onSheet) {
          pieces.add(
            SheetPiece(
              contextPicture(image, boxes, (settings.sheetMaxPx * 0.6).round()),
              page: page.number,
              context: true,
            ),
          );
        } else {
          final name = 'page_${'${page.number}'.padLeft(2, '0')}_context.jpg';
          await File(p.join(dir.path, name))
              .writeAsBytes(ImageCodec.encodeJpeg(contextPicture(image, boxes, settings.sheetMaxPx), quality: 90));
          contexts.add(name);
        }
      }
      if (!pictures) continue;
      for (final it in own) {
        pieces.add(
          SheetPiece(
            cropForExchange(image, byId[it.pageId]!.blocks[it.blockIndex]),
            label: it.label,
            page: page.number,
          ),
        );
      }
    }
    if (pictures && settings.images.hasSheets) {
      final built = buildSheets(
        pieces,
        grouping: settings.grouping,
        perSheet: settings.perSheet,
        maxPx: settings.sheetMaxPx,
        sheetPerPage: settings.sheetPerPage,
        groups: groups,
      );
      for (final (n, s) in built.indexed) {
        final name = 'sheet_${'${n + 1}'.padLeft(2, '0')}.png';
        await File(p.join(dir.path, name)).writeAsBytes(ImageCodec.encodePng(s.image));
        sheets.add(name);
        sheetLabels.add([for (final l in s.labels) l.code]);
      }
    }
    if (pictures && settings.images.hasCrops) {
      final cuts = pieces.where((s) => !s.context).toList();
      final batch = settings.cropsPerFolder;
      final folders = cuts.length > batch;
      for (final (n, piece) in cuts.indexed) {
        final sub = folders ? p.join('crops', 'batch_${'${n ~/ batch + 1}'.padLeft(2, '0')}') : 'crops';
        final name = p.join(sub, '${piece.label!.code}.png');
        final file = File(p.join(dir.path, name));
        await file.parent.create(recursive: true);
        await file.writeAsBytes(ImageCodec.encodePng(piece.image));
        crops.add(name);
      }
    }
  }

  final prompt = exchangePrompt(
    mode,
    items,
    sourceLanguage: sourceLanguage,
    targetLanguage: targetLanguage,
    template: settings.promptFor(mode),
    extraContext: extraContext,
    screens: screens,
    contextPictures: contextWanted,
  );
  await File(p.join(dir.path, exchangePromptName)).writeAsString(prompt);

  // Templates to fill: the text to translate, or empty lines.
  String template(Iterable<ExchangeItem> list) =>
      '${[for (final it in list) mode == ExchangeMode.translate ? '${it.label} ${it.text.replaceAll('\n', ' ')}' : '${it.label} '].join('\n')}\n';
  if (settings.textFiles.hasAll) {
    await File(p.join(dir.path, exchangeAllName)).writeAsString(template(items));
  }
  if (settings.textFiles.hasPages) {
    for (final page in pages) {
      final own = items.where((it) => it.pageId == page.id);
      if (own.isEmpty) continue;
      await File(p.join(dir.path, exchangePageTextName(page.number))).writeAsString(template(own));
    }
  }

  await File(p.join(dir.path, exchangeManifestName)).writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'mode': mode.name,
      'created': DateTime.now().toIso8601String(),
      'source_language': sourceLanguage,
      'target_language': targetLanguage,
      'pages': [
        for (final page in pages) {'id': page.id, 'number': page.number, 'name': page.name},
      ],
      'items': [for (final it in items) it.toJson()],
      'sheets': [
        for (final (n, s) in sheets.indexed) {'file': s, 'labels': sheetLabels[n]},
      ],
      'contexts': contexts,
      'crops': crops,
    }),
  );
  return ExchangeExport(
    dir: dir.path,
    mode: mode,
    items: items,
    prompt: prompt,
    sheets: sheets,
    contexts: contexts,
    crops: crops,
  );
}

/// An exchange folder read back.
class ExchangeManifest {
  const ExchangeManifest({
    required this.mode,
    required this.items,
    required this.pages,
    this.sourceLanguage = '',
    this.targetLanguage = '',
    this.export,
  });

  final ExchangeMode mode;
  final List<ExchangeItem> items;

  /// The folder as [writeExchange] made it (pictures and instructions).
  final ExchangeExport? export;

  /// Page id → its number in the labels.
  final Map<String, int> pages;
  final String sourceLanguage;
  final String targetLanguage;

  static Future<ExchangeManifest> read(Directory dir) async {
    final json = jsonDecode(await File(p.join(dir.path, exchangeManifestName)).readAsString()) as Map<String, Object?>;
    final mode = ExchangeMode.parse(json['mode'] as String?);
    final items = [
      for (final it in (json['items'] as List? ?? const [])) ExchangeItem.fromJson((it as Map).cast<String, Object?>()),
    ];
    final promptFile = File(p.join(dir.path, exchangePromptName));
    return ExchangeManifest(
      mode: mode,
      items: items,
      pages: {
        for (final pg in (json['pages'] as List? ?? const []))
          (pg as Map)['id'] as String: (pg['number'] as num).toInt(),
      },
      sourceLanguage: json['source_language'] as String? ?? '',
      targetLanguage: json['target_language'] as String? ?? '',
      export: ExchangeExport(
        dir: dir.path,
        mode: mode,
        items: items,
        prompt: await promptFile.exists() ? await promptFile.readAsString() : '',
        sheets: [for (final s in (json['sheets'] as List? ?? const [])) (s as Map)['file'] as String],
        contexts: [...?(json['contexts'] as List?)?.whereType<String>()],
        crops: [...?(json['crops'] as List?)?.whereType<String>()],
      ),
    );
  }
}

/// How the answer matched the pieces that were sent.
class ExchangeMatch {
  const ExchangeMatch({
    required this.replies,
    required this.missing,
    required this.unknown,
    this.missingArrow = const [],
    this.repeated = const [],
    this.sources = const {},
  });

  /// Answers for pieces that were sent.
  final Map<ExchangeLabel, ExchangeReply> replies;

  /// Pieces the answer has nothing for.
  final List<ExchangeLabel> missing;

  /// Labels in the answer that were not sent.
  final List<ExchangeLabel> unknown;
  final List<ExchangeLabel> missingArrow;
  final List<ExchangeLabel> repeated;

  /// For answers from files: label → file name.
  final Map<ExchangeLabel, String> sources;
}

/// Matches [answer] with [items]. [ignoreUnchanged]: lines still as they
/// were written to the text files (not filled in) count as missing.
ExchangeMatch matchExchangeAnswer(
  List<ExchangeItem> items,
  ExchangeAnswer answer,
  ExchangeMode mode, {
  bool ignoreUnchanged = false,
  Map<ExchangeLabel, String> sources = const {},
}) {
  final sent = {for (final it in items) it.label: it};
  final replies = <ExchangeLabel, ExchangeReply>{};
  for (final e in answer.replies.entries) {
    final item = sent[e.key];
    if (item == null) continue;
    if (ignoreUnchanged && _unchanged(item, e.value, mode)) continue;
    replies[e.key] = e.value;
  }
  return ExchangeMatch(
    replies: replies,
    missing: [
      for (final it in items)
        if (!replies.containsKey(it.label)) it.label,
    ],
    unknown: [
      for (final l in answer.replies.keys)
        if (!sent.containsKey(l)) l,
    ],
    missingArrow: [
      for (final e in replies.entries)
        if (e.value.missingArrow) e.key,
    ],
    repeated: answer.repeated,
    sources: {
      for (final e in sources.entries)
        if (replies.containsKey(e.key)) e.key: e.value,
    },
  );
}

bool _unchanged(ExchangeItem item, ExchangeReply reply, ExchangeMode mode) =>
    reply.isEmpty || (mode == ExchangeMode.translate && reply.translation?.trim() == item.text.trim());

/// Reads the answers written into the text files of [dir]: `ALL.txt` first,
/// then each page's file for what is still missing.
Future<ExchangeMatch> readExchangeFolder(Directory dir, ExchangeManifest manifest) async {
  final merged = <ExchangeLabel, ExchangeReply>{};
  final sources = <ExchangeLabel, String>{};
  final repeated = <ExchangeLabel>[];
  Future<void> take(String name) async {
    final file = File(p.join(dir.path, name));
    if (!await file.exists()) return;
    final answer = parseExchangeAnswer(await file.readAsString(), manifest.mode);
    repeated.addAll(answer.repeated);
    final match = matchExchangeAnswer(manifest.items, answer, manifest.mode, ignoreUnchanged: true);
    for (final e in match.replies.entries) {
      if (merged.containsKey(e.key)) continue;
      merged[e.key] = e.value;
      sources[e.key] = name;
    }
  }

  await take(exchangeAllName);
  for (final number in {...manifest.pages.values}.toList()..sort()) {
    await take(exchangePageTextName(number));
  }
  return matchExchangeAnswer(
    manifest.items,
    ExchangeAnswer(merged, repeated: repeated),
    manifest.mode,
    sources: sources,
  );
}

/// The block of [blocks] that [item] was made from: the same place when
/// its box is still there, else the block that overlaps the old box most.
int? findExchangeBlock(List<TextBlock> blocks, ExchangeItem item) {
  final i = item.blockIndex;
  if (i < blocks.length && (blocks[i].xyxy == item.box || blocks[i].xyxy.iou(item.box) > 0.5)) return i;
  int? best;
  var bestIou = 0.3;
  for (final (k, b) in blocks.indexed) {
    final v = b.xyxy.iou(item.box);
    if (v > bestIou) {
      bestIou = v;
      best = k;
    }
  }
  return best;
}

/// Writes [reply] into [block] (a missing reply puts [placeholder] when it
/// is not empty). Returns whether the block changed.
bool applyExchangeReply(TextBlock block, ExchangeReply? reply, ExchangeMode mode, {String placeholder = ''}) {
  final oldText = block.text, oldTranslation = block.translation;
  if (reply == null) {
    if (placeholder.isEmpty) return false;
    if (mode == ExchangeMode.recognize) {
      block.text = placeholder;
    } else {
      block.translation = placeholder;
    }
  } else {
    switch (mode) {
      case ExchangeMode.recognize:
        block.text = reply.original ?? '';
      case ExchangeMode.translate:
        block.translation = reply.translation ?? '';
      case ExchangeMode.both:
        if (reply.original != null || reply.isEmpty) block.text = reply.original ?? '';
        block.translation = reply.translation ?? '';
    }
  }
  return block.text != oldText || block.translation != oldTranslation;
}
