// The offline translator: the big model of each direction (the small ones,
// the former "Fast" and "Better" levels, were dropped on 2026-11-19).

import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:test/test.dart';

void main() {
  test('each direction needs its big model; no level setting is left', () {
    expect(opusMtInfo.requiredModels('English'), [ModelCatalog.opusMtBigEnRu.id]);
    expect(opusMtInfo.requiredModels('Russian'), [ModelCatalog.opusMtBigRuEn.id]);
    // An old saved level changes nothing.
    final old = PluginConfig.resolve(opusMtInfo.settings, {'quality': 'fast'});
    expect(opusMtInfo.requiredModels('English', old), [ModelCatalog.opusMtBigEnRu.id]);
    expect(opusMtInfo.settings, isEmpty);
    // No model from another language.
    expect(opusMtInfo.requiredModels('Japanese'), opusMtInfo.models);
  });

  test('the big English model is asked for Russian; the models are in the catalog, the small ones are not', () {
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
    expect(ModelCatalog.all, isNot(contains(ModelCatalog.opusMtEnRu)));
    expect(ModelCatalog.all, isNot(contains(ModelCatalog.opusMtRuEn)));
  });
}
