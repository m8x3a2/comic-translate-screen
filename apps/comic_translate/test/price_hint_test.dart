// The price hint under a model by key (the owner's idea): what 10 bubbles
// cost by the earlier requests of that model.

import 'package:comic_translate/ui/settings/usage_section.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  HistoryEntry entry({
    String plugin = 'openrouter_ocr',
    String model = 'google/gemini-3.1-flash-lite',
    int blocks = 10,
    double? cost = 0.001,
    bool again = false,
    String error = '',
  }) => HistoryEntry(
    time: DateTime(2026, 11, 5),
    plugin: plugin,
    host: 'openrouter.ai',
    model: model,
    blocks: blocks,
    cost: cost,
    again: again,
    error: error,
  );

  test('the cost of the requests of that model for every 10 bubbles; asking again costs but adds none', () {
    final price = pricePerTenBubbles(
      [
        entry(blocks: 30, cost: 0.003),
        entry(blocks: 10, cost: 0.001),
        entry(blocks: 2, cost: 0.0004, again: true),
        entry(model: 'other/model', cost: 1),
        entry(plugin: 'openrouter', cost: 1),
        entry(cost: null),
        entry(cost: 1, error: 'no connection'),
      ],
      'openrouter_ocr',
      'google/gemini-3.1-flash-lite',
    )!;
    expect(price.requests, 3);
    expect(price.cost, closeTo(0.0044 * 10 / 40, 1e-12));
  });

  test('no request with a price yet: no hint', () {
    expect(pricePerTenBubbles([entry(cost: null)], 'openrouter_ocr', 'google/gemini-3.1-flash-lite'), isNull);
    expect(pricePerTenBubbles(const [], 'openrouter_ocr', 'm'), isNull);
  });
}
