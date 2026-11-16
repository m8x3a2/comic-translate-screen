// The levels of the offline translator: "High" needs the big models.

import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:test/test.dart';

void main() {
  PluginConfig at(String quality) => PluginConfig.resolve(opusMtInfo.settings, {'quality': quality});

  test('"High" needs the big model of the direction, the other levels the usual one', () {
    expect(opusMtInfo.requiredModels('English', at('high')), [ModelCatalog.opusMtBigEnRu.id]);
    expect(opusMtInfo.requiredModels('Russian', at('high')), [ModelCatalog.opusMtBigRuEn.id]);
    expect(opusMtInfo.requiredModels('English', at('better')), [ModelCatalog.opusMtEnRu.id]);
    expect(opusMtInfo.requiredModels('Russian', at('fast')), [ModelCatalog.opusMtRuEn.id]);
    // Without the settings, as before.
    expect(opusMtInfo.requiredModels('English'), [ModelCatalog.opusMtEnRu.id]);
    // No model from another language.
    expect(opusMtInfo.requiredModels('Japanese', at('high')), opusMtInfo.models);
  });

  test('the big English model is asked for Russian; the models are in the catalog', () {
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
  });
}
