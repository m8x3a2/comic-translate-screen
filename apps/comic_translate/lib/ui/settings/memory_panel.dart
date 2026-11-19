// Memory in Settings → Models: what the current settings need against the
// device, with what may happen when it is short and the criteria; on demand
// the memory now (refreshed every 5 s, a cheap system call); "Unload models".

import 'dart:async';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../../state/memory_need.dart';
import '../../state/worker_pool.dart';
import '../common/info_hint.dart';
import '../common/labels.dart';

/// The colour of [fit]: none when it fits, amber when tight, red when short.
Color? memoryFitColor(MemoryFit fit, ThemeData theme) => switch (fit) {
  MemoryFit.ok => null,
  MemoryFit.tight => Colors.amber.shade800,
  MemoryFit.short => theme.colorScheme.error,
};

class MemoryPanel extends ConsumerStatefulWidget {
  const MemoryPanel({super.key});

  @override
  ConsumerState<MemoryPanel> createState() => _MemoryPanelState();
}

class _MemoryPanelState extends ConsumerState<MemoryPanel> {
  Timer? _live;
  SystemMemory? _have = SystemMemory.read();
  int _appMb = ProcessInfo.currentRss >> 20;

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  void _toggleLive() {
    if (_live != null) {
      _live!.cancel();
      setState(() => _live = null);
      return;
    }
    _read();
    _live = Timer.periodic(const Duration(seconds: 5), (_) => _read());
  }

  void _read() {
    if (!mounted) return;
    setState(() {
      _have = SystemMemory.read();
      _appMb = ProcessInfo.currentRss >> 20;
    });
  }

  Future<void> _unload() async {
    final l = context.l10n;
    final done = await ref.read(workerPoolProvider).unload();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(done ? l.memoryUnloaded : l.memoryUnloadBusy), showCloseIcon: true));
    // The memory goes back to the system a moment later.
    Timer(const Duration(seconds: 1), _read);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;
    final settings = ref.watch(settingsProvider);
    final have = _have;
    final need = settingsMemoryMb(ref.read(servicesProvider).registry, settings);
    final fit = have == null ? MemoryFit.ok : memoryFit(need, have.freeMb, have.totalMb);
    final color = memoryFitColor(fit, theme);
    final loaded = ref.read(workerPoolProvider).isRunning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (have != null) Text(l.memoryHave(formatMb(have.totalMb), formatMb(have.freeMb)), style: small),
        titleWithInfo(
          l.memoryNeed(formatMb(need)),
          l.memoryInfo,
          style: small?.copyWith(color: color, fontWeight: color == null ? null : FontWeight.w600),
        ),
        if (fit != MemoryFit.ok)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: color!),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(fit == MemoryFit.tight ? l.memoryTight : l.memoryShort, style: small),
          ),
        if (_live != null && have != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l.memoryNow(formatMb(_appMb), formatMb(have.totalMb - have.freeMb), formatMb(have.totalMb)) +
                  (loaded ? ' ${l.memoryModelsLoaded}' : ''),
              style: small?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _toggleLive,
              icon: Icon(_live == null ? Icons.memory : Icons.stop_circle_outlined, size: 18),
              label: Text(_live == null ? l.memoryShowNow : l.memoryHideNow),
            ),
            TextButton.icon(
              onPressed: _unload,
              icon: const Icon(Icons.eject_outlined, size: 18),
              label: Text(l.memoryUnload),
            ),
            InfoHint(l.memoryUnloadInfo),
          ],
        ),
        Text(l.memoryCriteria, style: small?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
