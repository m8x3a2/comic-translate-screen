/// Reading by a language model through the network, the exchange with a
/// chat without hands: the same sheets of labelled cut-outs and the same
/// instructions of "Read" (or "Read and translate") go to the model, its
/// answer is read the same way. New in this project.
library;

import 'dart:math' as math;

import '../image/raster.dart';
import '../plugins/engines.dart';
import 'exchange_answer.dart';
import 'exchange_checks.dart';
import 'exchange_files.dart';
import 'exchange_prompt.dart';
import 'exchange_settings.dart';
import 'exchange_sheets.dart';

/// What a model reading some blocks of some pages gets.
class ReadingRequest {
  const ReadingRequest(this.items, this.sheets, this.prompt, {this.translation});

  /// The blocks asked for: the labels number the pages of this request from
  /// 1, `ExchangeItem.pageId` is the index of the page in the list given.
  final List<ExchangeItem> items;

  /// Pictures: the whole pages (when asked for) and the sheets of labelled
  /// cut-outs.
  final List<RgbImage> sheets;
  final String prompt;

  /// Translated in the same request.
  final ReadingTranslation? translation;
}

/// Blocks of one page in a part of several ([readingParts]).
typedef ReadingPart = List<({int page, List<int> blocks})>;

/// The request for [pages] (with [only]: these blocks of each page, all
/// when null or its entry is null): sheets of at most [sheetPx] on their
/// longer side; with [pagePictures] each page goes whole too, with the
/// labels on it, to show what happens and who speaks.
ReadingRequest readingRequest(
  List<OcrPage> pages, {
  required String sourceLanguage,
  List<List<int>?>? only,
  ReadingTranslation? translation,
  bool pagePictures = false,
  int sheetPx = 1600,
  bool screens = false,
}) {
  final mode = translation == null ? ExchangeMode.recognize : ExchangeMode.both;
  final items = exchangeItems([
    for (final (k, page) in pages.indexed)
      ExchangePage(
        id: '$k',
        number: k + 1,
        name: '',
        blocks: page.blocks,
        image: page.image,
        only: only == null ? null : only[k],
      ),
  ], mode);
  final wholePages = <RgbImage>[];
  final pieces = <SheetPiece>[];
  for (final (k, page) in pages.indexed) {
    final own = [
      for (final it in items)
        if (it.pageId == '$k') it,
    ];
    if (own.isEmpty) continue;
    if (pagePictures) wholePages.add(contextPicture(page.image, [for (final it in own) (it.label, it.box)], sheetPx));
    for (final it in own) {
      pieces.add(SheetPiece(cropForExchange(page.image, page.blocks[it.blockIndex]), label: it.label, page: k + 1));
    }
  }
  final sheets = buildSheets(pieces, maxPx: sheetPx);
  final prompt = exchangePrompt(
    translation == null ? ExchangePrompt.recognize : ExchangePrompt.both,
    items,
    sourceLanguage: sourceLanguage,
    targetLanguage: translation?.targetLanguage ?? '',
    extraContext: translation?.extraContext ?? '',
    contextPictures: pagePictures && translation != null,
    screens: screens,
  );
  return ReadingRequest(items, [...wholePages, for (final s in sheets) s.image], prompt, translation: translation);
}

/// The blocks of [pages] in parts of at most [maxBlocks] for one request
/// each, pages in order: a page that does not fit in the room left starts a
/// part of its own; one with more blocks than [maxBlocks] is cut into parts
/// of about the same size. Pages without blocks are left out.
List<ReadingPart> readingParts(List<int> blocksPerPage, int maxBlocks) {
  final max = math.max(1, maxBlocks);
  final parts = <ReadingPart>[];
  var part = <({int page, List<int> blocks})>[];
  var count = 0;
  void close() {
    if (part.isNotEmpty) parts.add(part);
    part = [];
    count = 0;
  }

  for (final (page, n) in blocksPerPage.indexed) {
    if (n == 0) continue;
    if (n > max) {
      close();
      final pieces = (n / max).ceil(), size = (n / pieces).ceil();
      for (var from = 0; from < n; from += size) {
        parts.add([
          (page: page, blocks: [for (var i = from; i < math.min(n, from + size); i++) i]),
        ]);
      }
      continue;
    }
    if (count + n > max) close();
    part.add((page: page, blocks: [for (var i = 0; i < n; i++) i]));
    count += n;
  }
  close();
  return parts;
}

/// [part] in two halves of about the same number of blocks (a page may be
/// cut between them).
(ReadingPart, ReadingPart) halveReadingPart(ReadingPart part) {
  final all = [
    for (final p in part)
      for (final b in p.blocks) (p.page, b),
  ];
  ReadingPart gather(Iterable<(int, int)> some) {
    final out = <({int page, List<int> blocks})>[];
    for (final (page, b) in some) {
      if (out.isNotEmpty && out.last.page == page) {
        out.last.blocks.add(b);
      } else {
        out.add((page: page, blocks: [b]));
      }
    }
    return out;
  }

  final half = all.length ~/ 2;
  return (gather(all.take(half)), gather(all.skip(half)));
}

/// What [applyReadingAnswer] left to ask again: the blocks the answer had
/// nothing for, or no translation for, or a translation that looks left
/// untranslated (as [untranslatedReplies] tells).
typedef ReadingMissing = List<({int page, int block})>;

/// Writes the model's [answer] to [request] into [pages] (as an answer of a
/// chat: words between stars become bold words of a translation); returns
/// what it had nothing for. An answer [cut] at the length limit may end in
/// the middle of its last piece: that one counts as missing.
ReadingMissing applyReadingAnswer(List<OcrPage> pages, ReadingRequest request, String answer, {bool cut = false}) {
  final translation = request.translation;
  final mode = translation == null ? ExchangeMode.recognize : ExchangeMode.both;
  final replies = parseExchangeAnswer(answer, mode).replies;
  final last = cut && replies.isNotEmpty ? replies.keys.last : null;
  if (last != null) replies.remove(last);
  final untranslated = translation == null
      ? const <ExchangeLabel>{}
      : untranslatedReplies(request.items, replies, targetLanguage: translation.targetLanguage).toSet();
  final missing = <({int page, int block})>[];
  for (final it in request.items) {
    final page = int.parse(it.pageId);
    final block = pages[page].blocks[it.blockIndex];
    var reply = replies[it.label];
    // No arrow: the model only read it (asked to read first, it would not
    // write the translation alone); the translation is asked for again.
    if (reply != null && reply.missingArrow) reply = ExchangeReply(original: reply.translation);
    if (reply?.original == null) {
      missing.add((page: page, block: it.blockIndex));
      continue;
    }
    if (translation == null) {
      block.text = reply!.original!;
      continue;
    }
    applyExchangeReply(block, reply, mode);
    if (reply!.translation == null || untranslated.contains(it.label)) {
      missing.add((page: page, block: it.blockIndex));
    }
  }
  return missing;
}
