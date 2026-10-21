/// "Use the graphics card": switching it on checks that DirectML runs on a
/// real card, then compares the graphics card with the processor on a test
/// page and says which is faster. When the card fails, a bug report is built
/// at once so it can be sent to the developer.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../../state/batch.dart' show missingModels;
import '../../state/gpu_benchmark.dart';
import '../../state/gpu_check.dart';
import '../../pipeline/pipeline_worker.dart' show PipelinePart;
import '../common/info_hint.dart';
import '../common/labels.dart';
import '../shell_full/main_screen.dart' show showInExplorer;

class GpuSwitch extends ConsumerStatefulWidget {
  const GpuSwitch({super.key});

  @override
  ConsumerState<GpuSwitch> createState() => _GpuSwitchState();
}

class _GpuSwitchState extends ConsumerState<GpuSwitch> {
  /// The last results, kept while the program runs.
  static GpuCheck? _check;
  static GpuBenchmarkResult? _bench;

  /// What runs now: `check`, `cpu`, `gpu`; null when idle.
  String? _step;

  void _set(bool on) => ref.read(settingsProvider.notifier).change((s) => s.useGpu = on);

  Future<void> _turnOn() async {
    setState(() => _step = 'check');
    final check = await GpuCheck.run();
    final services = ref.read(servicesProvider);
    services.appLog.info('gpu_check', {
      'usable': check.usable,
      'adapters': [for (final a in check.adapters) a.toJson()],
      if (!check.usable) 'problem': check.problem,
    });
    _check = check;
    if (!mounted) return;
    if (check.usable) {
      await _speedTest();
      return;
    }
    setState(() => _step = null);
    final l = context.l10n;
    final zip = await services.buildBugReport(note: 'GPU check: ${check.problem}');
    if (!mounted) return;
    final why = check.ort.directmlOk && check.cards.isEmpty
        ? l.gpuNoCard(check.adapters.map((a) => a.name).join(', '))
        : l.gpuDirectmlFailed(check.problem);
    await _dialog(
      l.gpuNotUsableTitle,
      [why, l.gpuNotUsableTail, l.speedTestReport(zip.path)],
      [
        TextButton(onPressed: () => showInExplorer(zip.path), child: Text(l.showInFolder)),
        FilledButton(onPressed: () => Navigator.pop(context), child: Text(l.ok)),
      ],
    );
  }

  Future<void> _speedTest() async {
    final l = context.l10n;
    final services = ref.read(servicesProvider);
    final settings = ref.read(settingsProvider);
    final missing = await missingModels(
      services.registry,
      services.models,
      settings,
      parts: const {PipelinePart.detector, PipelinePart.ocr, PipelinePart.inpainter},
      sourceLanguages: const {'English'},
    );
    if (!mounted) return;
    if (missing.isNotEmpty) {
      setState(() => _step = null);
      await _dialog(
        l.speedTestTitle,
        [l.speedTestNeedsModels(missing.map((m) => modelText(l, m).$1).join(', '))],
        [FilledButton(onPressed: () => Navigator.pop(context), child: Text(l.ok))],
      );
      return;
    }
    setState(() => _step = 'cpu');
    final result = await runGpuBenchmark(
      services,
      settings,
      ref.read(workerRegistryProvider),
      onStep: (s) {
        if (mounted) setState(() => _step = s);
      },
    );
    _bench = result;
    final failed = result.verdict == GpuVerdict.gpuFailed;
    final zip = failed ? await services.buildBugReport(note: 'GPU speed test: ${jsonEncode(result.toJson())}') : null;
    if (!mounted) return;
    setState(() => _step = null);
    final lines = [
      _cpuLine(l, result),
      _gpuLine(l, result),
      switch (result.verdict) {
        GpuVerdict.gpuFaster => l.speedTestGpuFaster,
        GpuVerdict.cpuBetter when result.gainPercent > 0 => l.speedTestSmallGain('${result.gainPercent}'),
        GpuVerdict.cpuBetter => l.speedTestCpuBetter,
        GpuVerdict.gpuFailed => l.speedTestGpuFailedVerdict,
      },
      if (zip != null) l.speedTestReport(zip.path),
    ];
    final useGpu = await _dialog<bool>(l.speedTestTitle, lines, switch (result.verdict) {
      GpuVerdict.gpuFaster => [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.speedTestKeepCpu)),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.speedTestUseGpu)),
      ],
      GpuVerdict.cpuBetter => [
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l.speedTestUseGpuAnyway)),
        FilledButton(onPressed: () => Navigator.pop(context, false), child: Text(l.speedTestKeepCpu)),
      ],
      GpuVerdict.gpuFailed => [
        TextButton(onPressed: () => showInExplorer(zip!.path), child: Text(l.showInFolder)),
        FilledButton(onPressed: () => Navigator.pop(context, false), child: Text(l.ok)),
      ],
    });
    _set(useGpu ?? result.verdict == GpuVerdict.gpuFaster);
  }

  String _seconds(BuildContext context, int ms) => context.l10n.speedSeconds(formatFactor(context, ms / 1000));

  String _cpuLine(AppLocalizations l, GpuBenchmarkResult r) =>
      r.cpuMs == null ? l.speedTestCpuFailed(r.cpuError ?? '?') : l.speedTestCpu(_seconds(context, r.cpuMs!));

  String _gpuLine(AppLocalizations l, GpuBenchmarkResult r) {
    if (r.verdict == GpuVerdict.gpuFailed) {
      final reason = r.gpuError ?? (r.fallbacks.isEmpty ? '?' : r.fallbacks.first.reason);
      return l.speedTestGpuFailed(reason.length > 300 ? '${reason.substring(0, 300)}…' : reason);
    }
    return l.speedTestGpu(_seconds(context, r.gpuMs!));
  }

  Future<T?> _dialog<T>(String title, List<String> lines, List<Widget> actions) => showDialog<T>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.speed),
      title: Text(title),
      content: SizedBox(width: 480, child: SelectableText(lines.join('\n\n'))),
      actions: actions,
    ),
  );

  String _status(AppLocalizations l, bool on) {
    final bench = _bench;
    final check = _check;
    final lines = [
      if (bench != null)
        switch (bench.verdict) {
          GpuVerdict.gpuFailed => l.speedTestLastFailed,
          _ => l.speedTestLast(_seconds(context, bench.cpuMs ?? 0), _seconds(context, bench.gpuMs ?? 0)),
        },
      if (on && check != null && check.usable) ...[
        l.gpuFound(check.cards.map(gpuLabel).join(', ')),
        if (check.onlyIntegrated) l.gpuOnlyIntegrated,
        if (check.oldDrivers(DateTime.now()) case final old when old.isNotEmpty)
          l.gpuOldDrivers(old.map((a) => '${a.name} (${a.driverDate!.year})').join(', ')),
      ],
    ];
    return lines.isEmpty ? l.useGpuHelp : lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final on = ref.watch(settingsProvider.select((s) => s.useGpu));
    final step = _step;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: titleWithInfo(l.useGpu, l.useGpuInfo),
          subtitle: step != null
              ? Row(
                  children: [
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(switch (step) {
                        'cpu' => l.speedTestRunning(l.speedTestOnCpu),
                        'gpu' => l.speedTestRunning(l.speedTestOnGpu),
                        _ => l.gpuChecking,
                      }),
                    ),
                  ],
                )
              : Text(_status(l, on)),
          value: on,
          onChanged: step != null
              ? null
              : (v) {
                  if (v) {
                    _turnOn();
                  } else {
                    _set(false);
                  }
                },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: step != null ? null : _turnOn,
            icon: const Icon(Icons.speed),
            label: Text(l.speedTestButton),
          ),
        ),
      ],
    );
  }
}
