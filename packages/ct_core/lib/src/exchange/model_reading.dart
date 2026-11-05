/// Reading by a language model through the network, the exchange with a
/// chat without hands: the same sheets of labelled cut-outs and the same
/// instructions of "Read" go to the model, its answer is read the same way.
/// New in this project.
library;

import '../image/raster.dart';
import '../model/text_block.dart';
import 'exchange_answer.dart';
import 'exchange_files.dart';
import 'exchange_prompt.dart';
import 'exchange_settings.dart';
import 'exchange_sheets.dart';

/// What a model reading some blocks of a page gets.
class ReadingRequest {
  const ReadingRequest(this.items, this.sheets, this.prompt);

  /// The blocks asked for (labels of page 1).
  final List<ExchangeItem> items;

  /// Pictures of the labelled cut-outs.
  final List<RgbImage> sheets;
  final String prompt;
}

/// The request for [blocks] of [image] ([only]: these indexes, all when
/// null): sheets of at most [sheetPx] on their longer side.
ReadingRequest readingRequest(
  RgbImage image,
  List<TextBlock> blocks, {
  required String sourceLanguage,
  List<int>? only,
  int sheetPx = 1600,
  bool screens = false,
}) {
  final page = ExchangePage(id: 'page', number: 1, name: '', blocks: blocks, image: image, only: only);
  final items = exchangeItems([page], ExchangeMode.recognize);
  final sheets = buildSheets([
    for (final it in items) SheetPiece(cropForExchange(image, blocks[it.blockIndex]), label: it.label, page: 1),
  ], maxPx: sheetPx);
  final prompt = exchangePrompt(
    ExchangePrompt.recognize,
    items,
    sourceLanguage: sourceLanguage,
    targetLanguage: '',
    screens: screens,
  );
  return ReadingRequest(items, [for (final s in sheets) s.image], prompt);
}

/// Writes the model's [answer] to [request] into [blocks]; returns the
/// indexes of the blocks it had nothing for. An answer [cut] at the length
/// limit may end in the middle of its last piece: that one counts as
/// missing.
List<int> applyReadingAnswer(List<TextBlock> blocks, ReadingRequest request, String answer, {bool cut = false}) {
  final replies = parseExchangeAnswer(answer, ExchangeMode.recognize).replies;
  final last = cut && replies.isNotEmpty ? replies.keys.last : null;
  final missing = <int>[];
  for (final it in request.items) {
    final text = it.label == last ? null : replies[it.label]?.original;
    if (text == null) {
      missing.add(it.blockIndex);
    } else {
      blocks[it.blockIndex].text = text;
    }
  }
  return missing;
}
