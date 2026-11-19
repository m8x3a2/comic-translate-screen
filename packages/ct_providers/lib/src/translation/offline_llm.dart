/// The levels of the offline translator above "Low" (OPUS-MT tc-big): a
/// translation model of llama.cpp (Index-Translate) on this computer.
/// Chosen on 2026-11-19 (self/Koharu — отчёт.md, self/Решения — 2026-11-19.md):
/// live speech reads more naturally than with OPUS-MT, and the model
/// follows notes (glossary, who speaks). New in this project.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:ct_core/ct_core.dart';
import 'package:ct_llama/ct_llama.dart';

import 'opus_mt.dart' show prepareComicText;

/// The model of each level; "low" is OPUS-MT tc-big.
const offlineLevelModels = <String, ModelSpec?>{
  'low': null,
  'medium': ModelCatalog.indexTranslate2b,
  'high': ModelCatalog.indexTranslate9b,
  'ultra': ModelCatalog.indexTranslate9bQ6,
};

/// Memory left to the other steps (finding text, reading, cleaning) when
/// "auto" picks the translator's level.
const offlineOtherStepsMb = 1500;

/// The translation models run where llama.cpp is bundled (Windows for now).
bool get offlineLlmAvailable => Platform.isWindows;

/// [level] of the settings with "auto" resolved: the highest level whose
/// model fits the budget of this device ([budgetMb] in tests) with room
/// for the other steps; "low" when the memory is unknown.
String resolveOfflineLevel(String level, {int? budgetMb}) {
  if (!offlineLlmAvailable) return 'low';
  if (level != 'auto') return offlineLevelModels.containsKey(level) ? level : 'low';
  final budget = budgetMb ?? deviceMemoryBudgetMb();
  if (budget == null) return 'low';
  var best = 'low';
  for (final l in const ['medium', 'high', 'ultra']) {
    if (offlineLevelModels[l]!.memoryMb! + offlineOtherStepsMb <= budget) best = l;
  }
  return best;
}

/// The request to the model for one bubble: Index-Translate's own prompt,
/// with the notes of the comic (glossary, who speaks, the story) when they
/// are to be followed.
String offlineLlmPrompt(String text, String target, {String notes = '', String? key}) {
  if (notes.isEmpty) {
    return 'Translate the following text into $target. Output the translation directly, without any explanation:'
        '\n\n$text';
  }
  return 'Translate the text below into $target. Output the translation directly, without any explanation. '
      'Follow these notes about the comic (names and terms, who speaks${key == null ? '' : '; this text is $key'}):'
      '\n$notes\n\nText:\n$text';
}

final _think = RegExp(r'<think>.*?</think>', dotAll: true);
final _label = RegExp(r'^(translation|перевод|text|текст)\s*:\s*', caseSensitive: false);

/// The model's answer as the translation: no reasoning block, no "Translation:"
/// label, no quotes the source did not have.
String cleanOfflineLlmReply(String reply, String source) {
  var t = reply.replaceAll(_think, '').trim().replaceFirst(_label, '').trim();
  const quotes = {'"': '"', '«': '»', '“': '”'};
  final quoted = quotes.keys.any(source.trimLeft().startsWith);
  for (final MapEntry(key: open, value: close) in quotes.entries) {
    if (!quoted && t.length > 1 && t.startsWith(open) && t.endsWith(close)) {
      t = t.substring(1, t.length - 1).trim();
    }
  }
  return t;
}

class OfflineLlmTranslator implements Translator {
  OfflineLlmTranslator(this._models, this.spec, {required this.info, this.followNotes = true, this.log});

  final ModelManager _models;
  final ModelSpec spec;
  @override
  final PluginInfo info;

  /// Glossary, who speaks and the notes of the comic go to the model.
  final bool followNotes;
  final EventLog? log;
  TextModel? _model;

  Future<TextModel> _open() async {
    final made = _model;
    if (made != null) return made;
    final path = await _models.ensureFile(spec, spec.files.first.name);
    final threads = math.max(1, math.min(8, Platform.numberOfProcessors));
    final sw = Stopwatch()..start();
    final model = TextModel.open(path, threads: threads, contextSize: 4096);
    log?.info('translator_session', {'model': spec.id, 'threads': threads, 'ms': sw.elapsedMilliseconds});
    return _model = model;
  }

  @override
  Future<void> translate(TranslationRequest request, PluginContext context) async {
    final model = await _open();
    final notes = followNotes ? request.extraContext.trim() : '';
    final done = <String, String>{};
    final sw = Stopwatch()..start();
    var tokens = 0;
    for (var i = 0; i < request.blocks.length; i++) {
      final b = request.blocks[i];
      final source = prepareComicText(b.text);
      if (!RegExp(r'\p{L}', unicode: true).hasMatch(source)) {
        b.translation = b.text;
        continue;
      }
      await context.cancel.checkpoint();
      final cached = done[source];
      if (cached != null) {
        b.translation = cached;
        continue;
      }
      final prompt = model.chatPrompt([
        ('user', offlineLlmPrompt(source, request.targetLanguage, notes: notes, key: request.keyOf(i))),
      ]);
      final reply = await model.generate(
        prompt,
        // A translation is rarely more than four times its source's tokens.
        sampling: TextSampling(maxTokens: math.min(1024, 64 + source.length * 2)),
        onToken: (_) async {
          await context.cancel.checkpoint();
          return true;
        },
      );
      tokens += reply.tokens;
      b.translation = done[source] = cleanOfflineLlmReply(reply.text, source);
    }
    context.log.info('offline_llm_done', {
      'model': spec.id,
      'blocks': request.blocks.length,
      'written_tokens': tokens,
      'ms': sw.elapsedMilliseconds,
    });
  }

  @override
  Future<void> dispose() async {
    _model?.dispose();
    _model = null;
  }
}
