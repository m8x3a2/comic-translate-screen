// The levels of the offline translator: Low is OPUS-MT tc-big (the small
// models, the former "Fast" and "Better", were dropped on 2026-11-19);
// Medium, High and Ultra are Index-Translate networks of llama.cpp.

import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:test/test.dart';

void main() {
  PluginConfig at(String level) => PluginConfig.resolve(opusMtInfo.settings, {'level': level});

  test('Low needs the big OPUS-MT model of the direction', () {
    expect(opusMtInfo.requiredModels('English', at('low')), [ModelCatalog.opusMtBigEnRu.id]);
    expect(opusMtInfo.requiredModels('Russian', at('low')), [ModelCatalog.opusMtBigRuEn.id]);
    // An old saved level changes nothing.
    final old = PluginConfig.resolve(opusMtInfo.settings, {'quality': 'fast', 'level': 'low'});
    expect(opusMtInfo.requiredModels('English', old), [ModelCatalog.opusMtBigEnRu.id]);
  });

  test('Medium, High and Ultra need one network for every direction', () {
    expect(opusMtInfo.requiredModels('English', at('medium')), [ModelCatalog.indexTranslate2b.id]);
    expect(opusMtInfo.requiredModels('Russian', at('high')), [ModelCatalog.indexTranslate9b.id]);
    expect(opusMtInfo.requiredModels('Japanese', at('ultra')), [ModelCatalog.indexTranslate9bQ6.id]);
  });

  test('automatically: the highest level that fits with room for the other steps', () {
    String auto(int budget) => resolveOfflineLevel('auto', budgetMb: budget);
    expect(auto(2000), 'low');
    // The owner's laptop: 8 GB, budget 4 GB.
    expect(auto(4096), 'medium');
    // 16 GB.
    expect(auto(memoryBudgetMb(16 * 1024, phone: false)), 'high');
    expect(auto(memoryBudgetMb(32 * 1024, phone: false)), 'ultra');
    // The owner's phone (12 GB, 5.5 free): Medium (no llama.cpp there yet anyway).
    expect(auto(memoryBudgetMb(12 * 1024, phone: true)), 'medium');
    expect(resolveOfflineLevel('high'), 'high');
    expect(resolveOfflineLevel('nonsense'), 'low');
    expect(opusMtInfo.field('level')!.defaultValue, 'auto');
    expect(opusMtInfo.field('follow_notes')!.defaultValue, isTrue);
  });

  test('the models are in the catalog with their memory', () {
    expect(opusMtBigModels['English']!.$3, '>>rus<<');
    expect(opusMtBigModels['Russian']!.$3, isNull);
    for (final spec in [ModelCatalog.opusMtBigEnRu, ModelCatalog.opusMtBigRuEn]) {
      expect(ModelCatalog.byId(spec.id), same(spec));
      expect(spec.files.map((f) => f.name), [
        'source.spm',
        'vocab.json',
        'encoder_model_quantized.onnx',
        'decoder_model_merged_quantized.onnx',
      ]);
    }
    for (final spec in offlineLevelModels.values.whereType<ModelSpec>()) {
      expect(ModelCatalog.byId(spec.id), same(spec));
      expect(spec.memoryMb, greaterThan(spec.totalSize >> 20));
    }
    expect(ModelCatalog.all, isNot(contains(ModelCatalog.opusMtEnRu)));
    expect(ModelCatalog.all, isNot(contains(ModelCatalog.opusMtRuEn)));
  });

  test('the answer is cleaned: no reasoning, label or added quotes', () {
    expect(cleanOfflineLlmReply('<think>\n\n</think>\n\nПривет!', 'Hi!'), 'Привет!');
    expect(cleanOfflineLlmReply('Translation: Привет', 'Hi'), 'Привет');
    expect(cleanOfflineLlmReply('«Привет»', 'Hi'), 'Привет');
    expect(cleanOfflineLlmReply('«Привет»', '"Hi"'), '«Привет»');
  });

  test('the prompt carries the notes and the block name only when asked', () {
    expect(offlineLlmPrompt('Hi', 'Russian'), contains('into Russian'));
    expect(offlineLlmPrompt('Hi', 'Russian'), isNot(contains('notes')));
    final withNotes = offlineLlmPrompt('Hi', 'Russian', notes: 'Glossary: Ash → Эш', key: 'block_2');
    expect(withNotes, contains('Glossary: Ash → Эш'));
    expect(withNotes, contains('block_2'));
  });
}
