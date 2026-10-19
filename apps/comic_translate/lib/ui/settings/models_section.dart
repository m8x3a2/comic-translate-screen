/// Models: status, download, check, delete, folder and offline import. The
/// models are grouped: the main ones, one per source language, extras.
library;

import 'package:ct_core/ct_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../../state/batch.dart' show missingModels;
import '../common/info_hint.dart';
import '../common/labels.dart';
import '../shell_full/batch_dialogs.dart' show DialogBatchUi;
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

  /// Several models are being downloaded or checked one after another.
  var _bulk = false;

  static final _shown = [
    for (final m in ModelCatalog.all)
      if (modelGroupOf(m.id) != ModelGroup.hidden) m,
  ];

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

  /// Whether [spec] was downloaded (false: failed or cancelled).
  Future<bool> _download(ModelSpec spec) async {
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
      return true;
    } on CancelledException {
      // Stopped by the user.
      return false;
    } catch (e) {
      if (mounted) _snack(context.l10n.downloadFailed('$e'));
      return false;
    } finally {
      _cancels.remove(spec.id);
      if (mounted) setState(() => _progress.remove(spec.id));
      await _refresh();
    }
  }

  /// Downloads [specs] one after another (after showing what and from where),
  /// stopping at the first failure.
  Future<void> _downloadAll(List<ModelSpec> specs) async {
    if (specs.isEmpty) return _snack(context.l10n.modelsNothingNeeded);
    if (!await DialogBatchUi(context).confirmDownload(specs) || !mounted) return;
    setState(() => _bulk = true);
    try {
      for (final spec in specs) {
        if (!mounted || !await _download(spec)) break;
      }
    } finally {
      if (mounted) setState(() => _bulk = false);
    }
  }

  Future<void> _downloadNeeded() async {
    final services = ref.read(servicesProvider);
    final needed = await missingModels(services.registry, services.models, ref.read(settingsProvider));
    if (mounted) await _downloadAll(needed);
  }

  Future<void> _verifyAll() async {
    final l = context.l10n;
    setState(() => _bulk = true);
    final bad = <String>[];
    try {
      for (final spec in _shown) {
        if (_status[spec.id] == ModelStatus.missing) continue;
        if ((await _models.verify(spec)).isNotEmpty) bad.add(modelText(l, spec).$1);
      }
    } finally {
      if (mounted) setState(() => _bulk = false);
    }
    await _refresh();
    if (mounted) _snack(bad.isEmpty ? l.modelsVerifyAllOk : l.modelsVerifyAllBad(bad.join(', ')));
  }

  Future<void> _verify(ModelSpec spec) async {
    final l = context.l10n;
    final bad = await _models.verify(spec);
    if (mounted) {
      _snack(
        bad.isEmpty
            ? '${modelText(l, spec).$1}: ${l.verifyOk}'
            : '${modelText(l, spec).$1}: ${l.verifyBad(bad.join(', '))}',
      );
    }
    await _refresh();
  }

  Future<void> _delete(ModelSpec spec) async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(l.deleteModelConfirm(modelText(l, spec).$1)),
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
        _overview(l, theme, settings),
        for (final (group, title, help) in [
          (ModelGroup.core, l.modelsCore, null),
          (ModelGroup.language, l.modelsLanguages, l.modelsLanguagesHelp),
          (ModelGroup.extra, l.modelsExtra, null),
        ])
          SettingsGroup(
            title: title,
            children: [
              if (help != null) ...[Text(help, style: theme.textTheme.bodySmall), const SizedBox(height: 8)],
              for (final spec in _shown)
                if (modelGroupOf(spec.id) == group) _tile(spec, theme),
            ],
          ),
      ],
    );
  }

  /// How many are downloaded, and the buttons for several models at once.
  Widget _overview(AppLocalizations l, ThemeData theme, AppSettings settings) {
    final installed = [
      for (final m in _shown)
        if (_status[m.id] == ModelStatus.installed) m,
    ];
    final size = installed.fold<int>(0, (a, m) => a + m.totalSize);
    final busy = _bulk || _progress.isNotEmpty;
    final language = Languages.byName(settings.sourceLanguage)?.nativeLabel ?? settings.sourceLanguage;
    return SettingsGroup(
      children: [
        Text(
          l.modelsSummary('${installed.length}', '${_shown.length}', formatBytes(size)),
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: busy ? null : _downloadNeeded,
              icon: const Icon(Icons.download),
              label: Text(l.modelsNeeded(language)),
            ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => _downloadAll([
                      for (final m in _shown)
                        if (_status[m.id] != ModelStatus.installed) m,
                    ]),
              child: Text(l.modelsAll),
            ),
            OutlinedButton(onPressed: busy || installed.isEmpty ? null : _verifyAll, child: Text(l.modelsVerifyAll)),
          ],
        ),
      ],
    );
  }

  Widget _tile(ModelSpec spec, ThemeData theme) {
    final status = _status[spec.id];
    final progress = _progress[spec.id];
    final size = formatBytes(spec.totalSize);
    final (title, info) = modelText(context.l10n, spec);
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
                Flexible(child: Text(title, style: theme.textTheme.titleSmall)),
                InfoHint('$info\n\n${spec.displayName}'),
                const Spacer(),
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
                    onPressed: _bulk ? null : () => _download(spec),
                    icon: const Icon(Icons.download, size: 18),
                    label: Text(context.l10n.download),
                  ),
                if (status != null && status != ModelStatus.missing && progress == null) ...[
                  TextButton(onPressed: _bulk ? null : () => _verify(spec), child: Text(context.l10n.verify)),
                  TextButton(onPressed: _bulk ? null : () => _delete(spec), child: Text(context.l10n.delete)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
