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
import 'dart:math' as math;

import 'package:path/path.dart' as p;

import '../image/cv_bridge.dart';
import '../image/raster.dart';
import '../model/text_block.dart';
import '../render/block_style.dart';
import '../render/text_runs.dart';
import '../translation/llm_protocol.dart';
import 'exchange_answer.dart';
import 'exchange_prompt.dart';
import 'exchange_settings.dart';
import 'exchange_sheets.dart';

const exchangeManifestName = 'exchange.json';
const exchangeAllName = 'ALL.txt';
const exchangePromptName = 'prompt.txt';

/// Small pictures of the pieces for the app (see [ExchangeExport.previews]).
const exchangePreviewsDir = '_pieces';
const exchangePreviewPx = 360;

/// Name of a page's text file without `.txt` (`page_01`); with the
/// original and the translation apart: `page_01_original.txt` and
/// `page_01_translation.txt`, and `ALL_original.txt`, `ALL_translation.txt`.
String exchangePageBase(int page) => 'page_${'$page'.padLeft(2, '0')}';
String exchangePageTextName(int page) => '${exchangePageBase(page)}.txt';
const _allBase = 'ALL';

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
    this.previews = const {},
    this.sheetLabels = const {},
  });

  final String dir;
  final ExchangeMode mode;
  final List<ExchangeItem> items;
  final String prompt;

  /// Files in [dir] to send, in order.
  final List<String> sheets;
  final List<String> contexts;
  final List<String> crops;

  /// The labels on each sheet (file → label codes, in order).
  final Map<String, List<String>> sheetLabels;

  /// Small pictures of the pieces for the app's own view (label code → file
  /// in [dir]); not for the chat.
  final Map<String, String> previews;

  /// Everything to attach in the chat: the pages first, then the sheets (or
  /// the single cut-outs when there are no sheets).
  List<String> get pictures => [...contexts, ...(sheets.isNotEmpty ? sheets : crops)];
}

/// Writes the exchange folder [dir] for [pages]. [groups]: the user's own
/// grouping of the pieces into sheets (see [parseSheetGroups]).
/// [keepTexts]: text files already there stay (the user may have written
/// into them). [promptText]: instructions changed by the user for this time.
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
  bool keepTexts = false,
  String? promptText,
  bool previews = false,
}) async {
  await dir.create(recursive: true);
  // Pictures of an earlier writing of this folder go: fewer sheets must not
  // leave old ones behind.
  await for (final f in dir.list()) {
    final name = p.basename(f.path);
    if (f is File && RegExp(r'^(sheet_\d+\.png|page_\d+_context\.jpg)$').hasMatch(name)) await f.delete();
    if (f is Directory && (name == 'crops' || name == exchangePreviewsDir)) await f.delete(recursive: true);
  }
  final items = exchangeItems(pages, mode);
  // Sheets of cut-outs when the chat reads; pictures of whole pages when
  // asked for (they help when only translating too).
  final pictures = mode.sendsImages;
  final contextWanted = settings.contextImage != ContextImage.off;
  final sheets = <String>[], contexts = <String>[], crops = <String>[];
  final previewFiles = <String, String>{};
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
    if (pictures && previews) {
      for (final piece in pieces.where((s) => !s.context)) {
        final img = piece.image;
        final f = math.min(1.0, exchangePreviewPx / math.max(img.width, img.height));
        final small = f < 1.0
            ? resizeRgb(img, math.max(1, (img.width * f).round()), math.max(1, (img.height * f).round()))
            : img;
        final name = p.join(exchangePreviewsDir, '${piece.label!.code}.jpg');
        final file = File(p.join(dir.path, name));
        await file.parent.create(recursive: true);
        await file.writeAsBytes(ImageCodec.encodeJpeg(small, quality: 85));
        previewFiles[piece.label!.code] = name;
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

  final kind = settings.promptKind(mode);
  final prompt =
      promptText ??
      exchangePrompt(
        kind,
        items,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        template: settings.promptFor(kind),
        extraContext: extraContext,
        screens: screens,
        contextPictures: contextWanted,
        separator: settings.separator,
      );
  await File(p.join(dir.path, exchangePromptName)).writeAsString(prompt);

  // Templates to fill: the text to translate, or empty lines. With the
  // apart files too, the original goes in `_original.txt` and the
  // translation in `_translation.txt` besides the one file, the same in
  // every mode; the answer is taken from whichever is filled in.
  final split = settings.splitFiles;
  Future<void> writeTexts(String base, Iterable<ExchangeItem> list) async {
    String lines(String Function(ExchangeItem it) text) =>
        '${[for (final it in list) '${it.label} ${text(it)}'].join('\n')}\n';
    String source(ExchangeItem it) => mode == ExchangeMode.translate ? it.text.replaceAll('\n', ' ') : '';
    final files = {
      '$base.txt': lines(source),
      if (split) ...{'${base}_original.txt': lines(source), '${base}_translation.txt': lines((_) => '')},
    };
    for (final MapEntry(key: name, value: text) in files.entries) {
      final file = File(p.join(dir.path, name));
      // Filled in by the user already: kept when only the pictures change.
      if (keepTexts && await file.exists()) continue;
      await file.writeAsString(text);
    }
  }

  if (settings.textFiles.hasAll) await writeTexts(_allBase, items);
  if (settings.textFiles.hasPages) {
    for (final page in pages) {
      final own = items.where((it) => it.pageId == page.id);
      if (own.isNotEmpty) await writeTexts(exchangePageBase(page.number), own);
    }
  }

  await File(p.join(dir.path, exchangeManifestName)).writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'mode': mode.name,
      'separator': settings.separator,
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
    previews: previewFiles,
    sheetLabels: {for (final (n, s) in sheets.indexed) s: sheetLabels[n]},
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
    this.separator = defaultExchangeSeparator,
    this.export,
  });

  final ExchangeMode mode;
  final List<ExchangeItem> items;

  /// Between the original and the translation in the answers.
  final String separator;

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
      separator: json['separator'] as String? ?? defaultExchangeSeparator,
      export: ExchangeExport(
        dir: dir.path,
        mode: mode,
        items: items,
        prompt: await promptFile.exists() ? await promptFile.readAsString() : '',
        sheets: [for (final s in (json['sheets'] as List? ?? const [])) (s as Map)['file'] as String],
        sheetLabels: {
          for (final s in (json['sheets'] as List? ?? const []))
            (s as Map)['file'] as String: [...?(s['labels'] as List?)?.whereType<String>()],
        },
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
    final reply = ignoreUnchanged ? _filledIn(item, e.value, mode) : e.value;
    if (reply != null) replies[e.key] = reply;
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

/// What the user wrote into a template line: empty parts and, when
/// translating, the text sent left as it was are not an answer. Null:
/// nothing written.
ExchangeReply? _filledIn(ExchangeItem item, ExchangeReply reply, ExchangeMode mode) {
  String? written(String? s) =>
      s == null || s.trim().isEmpty || (mode == ExchangeMode.translate && s.trim() == item.text.trim()) ? null : s;
  final original = written(reply.original), translation = written(reply.translation);
  if (original == null && translation == null) return null;
  if (original == reply.original && translation == reply.translation) return reply;
  return ExchangeReply(original: original, translation: translation, missingArrow: reply.missingArrow);
}

/// Reads the answers written into the text files of [dir]: `ALL.txt` first,
/// then each page's file for what is still missing.
Future<ExchangeMatch> readExchangeFolder(Directory dir, ExchangeManifest manifest) async {
  final merged = <ExchangeLabel, ExchangeReply>{};
  final sources = <ExchangeLabel, String>{};
  final repeated = <ExchangeLabel>[];
  final mode = manifest.mode;
  Future<ExchangeAnswer?> parse(String name, ExchangeMode as) async {
    final file = File(p.join(dir.path, name));
    if (!await file.exists()) return null;
    return parseExchangeAnswer(await file.readAsString(), as, separator: manifest.separator);
  }

  Future<void> take(String base) async {
    // The original and the translation apart, then the one file: each piece
    // takes what was filled in, wherever it is.
    // In every mode: a corrected original (when translating) or a
    // translation that came along (when reading) counts too.
    final translations = await parse('${base}_translation.txt', ExchangeMode.translate);
    final originals = await parse('${base}_original.txt', ExchangeMode.recognize);
    final single = await parse('$base.txt', mode);
    final answers = [
      if (translations != null || originals != null)
        (
          mergeExchangeAnswers(originals ?? const ExchangeAnswer({}), translations ?? const ExchangeAnswer({})),
          (ExchangeReply reply) => [
            if (reply.original != null) '${base}_original.txt',
            if (reply.translation != null) '${base}_translation.txt',
          ].join(' + '),
        ),
      if (single != null) (single, (ExchangeReply _) => '$base.txt'),
    ];
    for (final (answer, nameOf) in answers) {
      repeated.addAll(answer.repeated);
      final match = matchExchangeAnswer(manifest.items, answer, mode, ignoreUnchanged: true);
      for (final MapEntry(key: label, value: reply) in match.replies.entries) {
        final name = nameOf(reply);
        final had = merged[label];
        if (had == null) {
          merged[label] = reply;
          sources[label] = name;
        } else if (had.original == null || had.translation == null) {
          // Half of it in one file (the original), the rest in another.
          final original = had.original ?? reply.original, translation = had.translation ?? reply.translation;
          if (original == had.original && translation == had.translation) continue;
          merged[label] = ExchangeReply(
            original: original,
            translation: translation,
            missingArrow: had.missingArrow && reply.original == null,
          );
          sources[label] = '${sources[label]}, $name';
        }
      }
    }
  }

  await take(_allBase);
  for (final number in {...manifest.pages.values}.toList()..sort()) {
    await take(exchangePageBase(number));
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
/// is not empty). Returns whether the block changed. Words of a new
/// translation between stars (`*НЕ*`) become bold words of the block; the
/// words styled for the old translation go.
bool applyExchangeReply(TextBlock block, ExchangeReply? reply, ExchangeMode mode, {String placeholder = ''}) {
  final oldText = block.text, oldTranslation = block.translation, oldStyle = block.style;
  if (reply == null) {
    if (placeholder.isEmpty) return false;
    if (mode == ExchangeMode.recognize) {
      block.text = placeholder;
    } else {
      block.translation = placeholder;
    }
  } else {
    // What was given, in any mode (a translation may come along with the
    // reading, a corrected original with the translation). Nothing after
    // the label empties what the mode asked for.
    if (reply.original != null || (reply.isEmpty && mode != ExchangeMode.translate)) {
      block.text = reply.original ?? '';
    }
    if (reply.translation != null || (reply.isEmpty && mode != ExchangeMode.recognize)) {
      block.translation = reply.translation ?? '';
    }
  }
  if (block.translation != oldTranslation) {
    final (text, runs) = boldFromStars(block.translation);
    block.translation = text;
    final style = (block.style ?? const BlockStyle()).copyWith(runs: runs);
    block.style = style.isEmpty ? null : style;
  }
  return block.text != oldText || block.translation != oldTranslation || block.style != oldStyle;
}
