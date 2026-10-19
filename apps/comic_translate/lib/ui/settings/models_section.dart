/// Models: status, download, check, delete, folder and offline import.
library;

import 'package:ct_core/ct_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../state/app_state.dart';
import '../common/labels.dart';
import '../shell_full/main_screen.dart' show showInExplorer;
import 'settings_screen.dart' show SettingsGroup;

class ModelsSection extends ConsumerStatefulWidget {
  const ModelsSection({super.key});

  @override
  ConsumerState<ModelsSection> createState() => _ModelsSectionState();
}

class _ModelsSectionState extends ConsumerState<ModelsSection> {
  Map<String, ModelStatus> _status = {};

  /// Model id → download progress (0…1) while downloading.
  final Map<String, double> _progress = {};
  final Map<String, CancelToken> _cancels = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    for (final c in _cancels.values) {
      c.cancel();
    }
    super.dispose();
  }

  ModelManager get _models => ref.read(servicesProvider).models;

  Future<void> _refresh() async {
    final status = {for (final m in ModelCatalog.all) m.id: await _models.status(m)};
    if (mounted) setState(() => _status = status);
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), showCloseIcon: true));

  Future<void> _download(ModelSpec spec) async {
    final cancel = _cancels[spec.id] = CancelToken();
    final total = spec.files.fold<int>(0, (a, f) => a + f.size);
    setState(() => _progress[spec.id] = 0);
    try {
      await _models.download(
        spec,
        cancel: cancel,
        onProgress: (d) {
          if (mounted) setState(() => _progress[spec.id] = d.received / total);
        },
      );
    } on CancelledException {
      // Stopped by the user.
    } catch (e) {
      if (mounted) _snack(context.l10n.downloadFailed('$e'));
    } finally {
      _cancels.remove(spec.id);
      if (mounted) setState(() => _progress.remove(spec.id));
      await _refresh();
    }
  }

  Future<void> _verify(ModelSpec spec) async {
    final l = context.l10n;
    final bad = await _models.verify(spec);
    if (mounted) {
      _snack(
        bad.isEmpty ? '${spec.displayName}: ${l.verifyOk}' : '${spec.displayName}: ${l.verifyBad(bad.join(', '))}',
      );
    }
    await _refresh();
  }

  Future<void> _delete(ModelSpec spec) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(l.deleteModelConfirm(spec.displayName)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.delete)),
        ],
      ),
    );
    if (ok != true) return;
    await _models.delete(spec);
    await _refresh();
  }

  Future<void> _import() async {
    final files = await openFiles();
    if (files.isEmpty) return;
    final results = await _models.importFiles([for (final f in files) f.path]);
    await _refresh();
    if (!mounted) return;
    final l = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.importModelsDone('${results.where((r) => r.imported).length}')),
        content: SizedBox(
          width: 520,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final r in results)
                ListTile(
                  dense: true,
                  leading: Icon(r.imported ? Icons.check_circle_outline : Icons.block, size: 20),
                  title: Text(p.basename(r.path)),
                  subtitle: Text(r.imported ? l.importedAs(r.model!) : l.notAModelFile),
                ),
            ],
          ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: Text(l.close))],
      ),
    );
  }

  Future<void> _changeFolder() async {
    final dir = await getDirectoryPath();
    if (dir == null) return;
    await ref.read(settingsProvider.notifier).change((s) => s.modelsDir = dir);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final root = ref.watch(servicesProvider).models.root.path;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          title: l.modelsFolder,
          children: [
            SelectableText(root),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(onPressed: () => showInExplorer(root), child: Text(l.open)),
                OutlinedButton(onPressed: _changeFolder, child: Text(l.changeFolder)),
                if (settings.modelsDir.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      await ref.read(settingsProvider.notifier).change((s) => s.modelsDir = '');
                      await _refresh();
                    },
                    child: Text(l.defaultFolder),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(l.modelsFolderHelp, style: theme.textTheme.bodySmall),
          ],
        ),
        SettingsGroup(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _import,
                icon: const Icon(Icons.upload_file),
                label: Text(l.importModels),
              ),
            ),
            const SizedBox(height: 4),
            Text(l.importModelsHelp, style: theme.textTheme.bodySmall),
          ],
        ),
        SettingsGroup(children: [for (final spec in ModelCatalog.all) _tile(spec, l, theme)]),
      ],
    );
  }

  Widget _tile(ModelSpec spec, dynamic l, ThemeData theme) {
    final status = _status[spec.id];
    final progress = _progress[spec.id];
    final size = formatBytes(spec.files.fold(0, (a, f) => a + f.size));
    final hosts = {for (final f in spec.files) f.host}.join(', ');
    final (label, color) = switch (status) {
      ModelStatus.installed => (context.l10n.modelInstalled, theme.colorScheme.primary),
      ModelStatus.corrupt => (context.l10n.modelCorrupt, theme.colorScheme.error),
      _ => (context.l10n.modelMissing, theme.colorScheme.onSurfaceVariant),
    };
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(spec.displayName, style: theme.textTheme.titleSmall)),
                Text(label, style: theme.textTheme.labelMedium?.copyWith(color: color)),
              ],
            ),
            const SizedBox(height: 2),
            Text('$size · $hosts · ${spec.license}', style: theme.textTheme.bodySmall),
            if (progress != null) ...[const SizedBox(height: 8), LinearProgressIndicator(value: progress)],
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [
                if (progress != null)
                  TextButton(onPressed: () => _cancels[spec.id]?.cancel(), child: Text(context.l10n.cancel))
                else if (status != ModelStatus.installed)
                  TextButton.icon(
                    onPressed: () => _download(spec),
                    icon: const Icon(Icons.download, size: 18),
                    label: Text(context.l10n.download),
                  ),
                if (status != null && status != ModelStatus.missing && progress == null) ...[
                  TextButton(onPressed: () => _verify(spec), child: Text(context.l10n.verify)),
                  TextButton(onPressed: () => _delete(spec), child: Text(context.l10n.delete)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
