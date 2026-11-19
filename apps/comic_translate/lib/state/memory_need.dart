/// How much memory (RAM) the chosen settings and each level need, next to
/// what the device has (the owner's wish of 2026-11-19). The numbers are
/// measured: the peak memory of a `cts` run with one model on a big comic
/// page on the processor, less the run without a model
/// (self/ram-measure, ModelSpec.memoryMb). The worker keeps the models of
/// all steps loaded at once, so they add up.
library;

import 'dart:io';

import 'package:ct_core/ct_core.dart';

import '../services/system_memory.dart';

import 'batch.dart';

/// The app itself with a page open, without models.
const appBaseMb = 400;

/// Memory the models of [ids] take together (unknown ones count nothing).
int modelsMemoryMb(Iterable<String> ids) => ids.fold(0, (sum, id) => sum + (ModelCatalog.byId(id)?.memoryMb ?? 0));

/// What [settings] need while a page is processed: the app and the models of
/// every step.
int settingsMemoryMb(PluginRegistry registry, AppSettings settings) =>
    appBaseMb + modelsMemoryMb(chosenModelIds(registry, settings));

/// What working at [level] needs: the bigger of comics and screens.
int levelMemoryMb(PluginRegistry registry, AppSettings settings, ReadLevel level) =>
    [for (final kind in ContentKind.values) settingsMemoryMb(registry, levelSettings(settings, level, kind))]
        .reduce((a, b) => a > b ? a : b);

/// How [needMb] sits against [freeMb]: fits with room, fits tightly (other
/// programs may be pushed into the page file), or does not fit.
enum MemoryFit { ok, tight, short }

MemoryFit memoryFit(int needMb, int freeMb, int totalMb) {
  if (needMb > totalMb * 0.85) return MemoryFit.short;
  if (needMb > freeMb) return MemoryFit.tight;
  return MemoryFit.ok;
}

/// [mb] megabytes as text ("1.4 GB").
String formatMb(int mb) => formatBytes(mb << 20);

/// Memory the networks may take on a device with [totalMb]: a phone keeps
/// most for the system and other apps (the owner's phone: 12 GB, plan for
/// 5.5 free), a computer keeps 4 GB and at least 40 %.
int memoryBudgetMb(int totalMb, {required bool phone}) {
  if (phone) return (totalMb * 0.45).round();
  final keep = totalMb - 4096;
  final share = (totalMb * 0.6).round();
  return keep < share ? keep : share;
}

/// The recognition level "Automatically by memory" picks: the highest of
/// "Simple", "Medium" and "High" that fits [budgetMb] ("Ultra" is slow on
/// purpose, so only by hand); "High" only where its slow reader exists.
ReadLevel autoReadLevel(PluginRegistry registry, AppSettings settings, int budgetMb) {
  var best = ReadLevel.simple;
  for (final level in const [ReadLevel.medium, ReadLevel.high]) {
    if (level == ReadLevel.high && !registry.contains(vlmReaderId)) continue;
    if (levelMemoryMb(registry, settings, level) <= budgetMb) best = level;
  }
  return best;
}

/// The budget of this device; null when its memory is unknown.
int? deviceBudgetMb() {
  final m = SystemMemory.read();
  return m == null ? null : memoryBudgetMb(m.totalMb, phone: Platform.isAndroid || Platform.isIOS);
}

/// With "Automatically by memory" on, sets both recognition levels to what
/// fits this device (at start and when it is switched on).
Future<void> applyAutoLevel(
  AppSettings settings,
  Future<void> Function(void Function(AppSettings)) change,
  PluginRegistry registry,
) async {
  if (!settings.levelAuto) return;
  final budget = deviceBudgetMb();
  if (budget == null) return;
  final level = autoReadLevel(registry, settings, budget);
  if (settings.readLevel == level && settings.screenReadLevel == level) return;
  await change(
    (s) => s
      ..readLevel = level
      ..screenReadLevel = level,
  );
}
