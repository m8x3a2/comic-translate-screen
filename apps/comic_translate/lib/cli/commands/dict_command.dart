import 'package:ct_core/ct_core.dart';

import '../cli.dart';
import '../cli_context.dart';

/// `cts dict <word or phrase>...`: what the offline dictionary says (the
/// dictionary is downloaded with `cts models download dict-en-ru`).
class DictCommand extends CtsCommand {
  DictCommand(super.holder);

  @override
  String get name => 'dict';

  @override
  String get description => 'Look up English words or phrases in the offline dictionary (English to Russian).';

  @override
  String get invocation => 'cts dict <word or phrase>...';

  @override
  Future<int> run() async {
    final words = argResults!.rest;
    if (words.isEmpty) {
      ctx.err.writeln('Give a word or a phrase, e.g. cts dict "gave up".');
      return ExitCodes.usage;
    }
    const spec = ModelCatalog.dictEnRu;
    final models = ctx.services.models;
    if (await models.status(spec) != ModelStatus.installed) {
      ctx.err.writeln('The dictionary is not downloaded: cts models download ${spec.id}');
      return ExitCodes.failure;
    }
    final dict = OfflineDictionary.open(models.fileOf(spec, ModelCatalog.dictionaryFile).path);
    try {
      final sw = Stopwatch()..start();
      final found = {for (final w in words) w: dict.lookup(w)};
      final ms = sw.elapsedMicroseconds / 1000;
      if (ctx.json) {
        ctx.printJson({
          'ms': ms,
          'words': {
            for (final MapEntry(:key, :value) in found.entries) key: [for (final c in value) _cardJson(c)],
          },
        });
      } else {
        for (final MapEntry(:key, :value) in found.entries) {
          ctx.say('«$key»${value.isEmpty ? ': not in the dictionary' : ''}');
          for (final c in value) {
            ctx.say('■ ${c.headword}${c.note == null ? '' : '  (${c.note})'}');
            for (final part in c.parts) {
              ctx.say('  [${part.pos}]');
              for (final f in part.formOf) {
                ctx.say('    ↪ $f');
              }
              for (final t in part.translations) {
                ctx.say('    • ${t.words.join(', ')}${t.sense.isEmpty ? '' : '  — ${t.sense}'}');
              }
              for (final s in part.russian) {
                ctx.say('    ru: ${s.gloss}');
              }
              for (final s in part.english) {
                ctx.say('    en: ${s.gloss}${s.tags.isEmpty ? '' : '  ${s.tags}'}');
              }
            }
          }
        }
        ctx.say('${ms.toStringAsFixed(1)} ms');
      }
      return ExitCodes.ok;
    } finally {
      dict.dispose();
    }
  }

  static Map<String, Object?> _cardJson(DictCard c) => {
    'headword': c.headword,
    'note': ?c.note,
    'parts': [
      for (final p in c.parts)
        {
          'pos': p.pos,
          'of': p.formOf,
          'tr': [
            for (final t in p.translations) {'sense': t.sense, 'words': t.words},
          ],
          'ru': [for (final s in p.russian) s.gloss],
          'en': [for (final s in p.english) s.gloss],
        },
    ],
  };
}
