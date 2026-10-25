/// PaddleOCR-VL 1.6: a vision-language model (llama.cpp) that reads a whole
/// block at once. The slow reader of the recognition levels "High" and
/// "Ultra" (see `read_level.dart`); chosen by the night experiment of
/// 2026-10-25, where it read the most words right on every kind of page.
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:ct_core/ct_core.dart';
import 'package:ct_llama/ct_llama.dart';

const paddleOcrVlInfo = PluginInfo(
  id: vlmReaderId,
  displayName: 'PaddleOCR-VL 1.6 (slow English reader)',
  description: 'Reads English blocks as a whole for the recognition levels "High" and "Ultra".',
  kind: PluginKind.reader,
  privacy: Privacy.local,
  platforms: {PlatformId.windows},
  models: ['paddleocr-vl-1.6'],
);

final paddleOcrVlFactory = PluginFactory<OcrEngine>(paddleOcrVlInfo, (config, env) async {
  final spec = ModelCatalog.paddleOcrVl;
  final model = await env.models.ensureFile(spec, spec.files[0].name);
  final mmproj = await env.models.ensureFile(spec, spec.files[1].name);
  final log = env.log;
  VisionModel.onError = (line) => log.warn('llama_error', {'line': line});
  final sw = Stopwatch()..start();
  final threads = math.max(1, math.min(8, Platform.numberOfProcessors ~/ 2));
  final vlm = VisionModel.open(model, mmproj, threads: threads);
  log.info('vlm_session', {'model': spec.id, 'threads': threads, 'ms': sw.elapsedMilliseconds});
  return PaddleOcrVlReader(vlm);
});

/// The prompt of PaddleOCR-VL's chat template for plain text recognition.
String paddleOcrVlPrompt(String marker) => '<|begin_of_sentence|>User: ${marker}OCR:\nAssistant:\n';

/// How long one block may be read; the huge blocks of a wall of text took
/// up to 3.5 min on the owner's laptop.
const vlmBlockLimit = Duration(minutes: 5);

class PaddleOcrVlReader implements OcrEngine {
  PaddleOcrVlReader(this._vlm);

  final VisionModel _vlm;

  @override
  PluginInfo get info => paddleOcrVlInfo;

  @override
  Future<void> recognize(
    RgbImage image,
    List<TextBlock> blocks, {
    required String sourceLanguage,
    required PluginContext context,
  }) async {
    final prompt = paddleOcrVlPrompt(VisionModel.marker);
    for (final b in blocks) {
      await context.cancel.checkpoint();
      final box = b.xyxy.clampTo(image.width, image.height);
      if (box.width < 8 || box.height < 8) {
        b
          ..text = ''
          ..texts = [];
        continue;
      }
      final crop = image.crop(box);
      final sw = Stopwatch()..start();
      var looped = false;
      final r = await _vlm.read(
        crop.data,
        crop.width,
        crop.height,
        prompt,
        onToken: (n) async {
          await context.cancel.checkpoint();
          if (sw.elapsed > vlmBlockLimit) return false;
          return true;
        },
        onText: (text) {
          // A model caught in a loop ("Clap Clap Clap ...") stops early.
          final clean = cleanVlmText(text);
          looped = cutRepeats(clean) != clean;
          return !looped;
        },
      );
      final text = cutRepeats(cleanVlmText(r.text));
      b
        ..text = text
        ..texts = text.isEmpty ? [] : [text];
      context.log.info('vlm_block', {
        'written': r.tokens,
        'ms': sw.elapsedMilliseconds,
        if (r.stopped) 'stopped': looped ? 'loop' : 'time',
      });
    }
  }

  @override
  Future<void> dispose() async => _vlm.dispose();
}

/// The reading as one line: markdown and thinking dropped (as the
/// experiment's readers did).
String cleanVlmText(String text) {
  var t = text.replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '');
  t = t.replaceAll(RegExp(r'```\w*'), '').replaceAll(RegExp(r'[#*_]{1,3}'), ' ');
  return [
    for (final l in t.split('\n'))
      if (l.trim().isNotEmpty) l.trim(),
  ].join(' ');
}

/// A reading that ends in a long run of a few repeated words (the model
/// looping on "Clap Clap Clap ...") cut where the run starts, keeping
/// [keep] words of it: a run is [window] or more words with at most
/// [distinct] different ones up to the end.
String cutRepeats(String text, {int window = 24, int distinct = 4, int keep = 4}) {
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.length < window) return text;
  String key(String w) {
    var s = w.toLowerCase();
    var a = 0, b = s.length;
    while (a < b && '.,!?'.contains(s[a])) {
      a++;
    }
    while (b > a && '.,!?'.contains(s[b - 1])) {
      b--;
    }
    return s.substring(a, b);
  }

  // Distinct words of each tail, from the end.
  final seen = <String>{};
  final tailDistinct = List<int>.filled(words.length, 0);
  for (var i = words.length - 1; i >= 0; i--) {
    seen.add(key(words[i]));
    tailDistinct[i] = seen.length;
  }
  for (var i = 0; i <= words.length - window; i++) {
    if (tailDistinct[i] <= distinct) return words.take(math.min(words.length, i + keep)).join(' ');
  }
  return text;
}
