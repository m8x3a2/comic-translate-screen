// How much memory the settings and the levels need, against the device.

import 'package:comic_translate/services/system_memory.dart';
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
    final need = settingsMemoryMb(registry, s);
    expect(need, greaterThan(appBaseMb + ModelCatalog.opusMtBigEnRu.memoryMb!));
    // The translator by key needs no model, so less.
    expect(settingsMemoryMb(registry, s..translator = 'openrouter'), need - ModelCatalog.opusMtBigEnRu.memoryMb!);
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
}
