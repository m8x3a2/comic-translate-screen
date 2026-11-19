// How much memory the settings and the levels need, against the device.

import 'package:comic_translate/state/memory_need.dart';
import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every model but the dictionary has its memory measured', () {
    for (final spec in ModelCatalog.all) {
      if (spec.id == ModelCatalog.dictEnRu.id) continue;
      expect(spec.memoryMb, isNotNull, reason: spec.id);
    }
  });

  test('the models of all steps add up to the app', () {
    final registry = builtInRegistry();
    final s = AppSettings()
      ..translator = 'opus_mt'
      ..sourceLanguage = 'English';
    s.plugins['opus_mt'] = {'level': 'low'};
    final need = settingsMemoryMb(registry, s);
    final opus = modelsMemoryMb([ModelCatalog.opusMtBigEnRu.id]);
    expect(opus, (ModelCatalog.opusMtBigEnRu.memoryMb! * onnxShare).round());
    expect(need, greaterThan(appBaseMb + opus));
    // The translator by key needs no model, so less (rounding aside).
    expect(settingsMemoryMb(registry, s..translator = 'openrouter'), closeTo(need - opus, 1));
  });

  test('a higher level needs more; "Ultra" reads with the slow reader alone, so less than "High"', () {
    final registry = builtInRegistry();
    final s = AppSettings();
    final [simple, medium, high, ultra] = [for (final level in ReadLevel.values) levelMemoryMb(registry, s, level)];
    expect(medium, greaterThan(simple));
    expect(high, greaterThan(medium));
    expect(ultra, greaterThan(medium));
    expect(ultra, lessThan(high));
  });

  test('fit: room, tight when more than free, short near all memory', () {
    expect(memoryFit(2000, 4000, 8000), MemoryFit.ok);
    expect(memoryFit(5000, 4000, 8000), MemoryFit.tight);
    expect(memoryFit(7500, 4000, 8000), MemoryFit.short);
  });

  test('this device tells its memory', () {
    final m = SystemMemory.read();
    expect(m, isNotNull);
    expect(m!.totalMb, greaterThan(1000));
    expect(m.freeMb, inInclusiveRange(1, m.totalMb));
  });

  test('budget: a phone gives the networks 45 %, a computer all but 4 GB and at most 60 %', () {
    expect(memoryBudgetMb(12 * 1024, phone: true), 5530);
    expect(memoryBudgetMb(8 * 1024, phone: false), 4096);
    expect(memoryBudgetMb(32 * 1024, phone: false), (32 * 1024 * 0.6).round());
  });

  test('automatic level: the highest of Simple, Medium, High that fits, never Ultra', () {
    final registry = builtInRegistry();
    final s = AppSettings();
    final medium = levelMemoryMb(registry, s, ReadLevel.medium);
    final high = levelMemoryMb(registry, s, ReadLevel.high);
    expect(autoReadLevel(registry, s, medium - 1), ReadLevel.simple);
    expect(autoReadLevel(registry, s, medium), ReadLevel.medium);
    expect(autoReadLevel(registry, s, high), ReadLevel.high);
    expect(autoReadLevel(registry, s, 1 << 30), ReadLevel.high);
  });

  test('the automatic choice is saved with the settings', () {
    final s = AppSettings.fromJson((AppSettings()..levelAuto = true).toJson());
    expect(s.levelAuto, isTrue);
    expect(AppSettings().levelAuto, isFalse);
  });

  test('the offline translator counts the network of its level', () {
    final registry = builtInRegistry();
    final s = AppSettings()
      ..translator = 'opus_mt'
      ..sourceLanguage = 'English';
    s.plugins['opus_mt'] = {'level': 'low'};
    final low = settingsMemoryMb(registry, s);
    s.plugins['opus_mt'] = {'level': 'high'};
    // A llama.cpp network counts in full.
    expect(
      settingsMemoryMb(registry, s) - low,
      closeTo(ModelCatalog.indexTranslate9b.memoryMb! - modelsMemoryMb([ModelCatalog.opusMtBigEnRu.id]), 1),
    );
  });
}
