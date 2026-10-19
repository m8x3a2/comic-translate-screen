/// The main window: toolbar, page list, page viewer, text panel, status bar.
library;

import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../state/app_state.dart';
import '../../state/batch.dart';
import '../../state/workspace.dart';
import '../common/labels.dart';
import '../common/plugin_strings.dart';
import '../settings/settings_screen.dart';
import 'batch_dialogs.dart';
import 'home_view.dart';
import 'page_list.dart';
import 'page_viewer.dart';
import 'text_panel.dart';

/// Opens [path] in Windows Explorer (selecting it when it is a file).
Future<void> showInExplorer(String path) async {
  if (!Platform.isWindows) return;
  if (FileSystemEntity.isFileSync(path)) {
    await Process.run('explorer.exe', ['/select,', path]);
  } else {
    await Process.run('explorer.exe', [path]);
  }
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    final inputs = ref.read(initialInputsProvider);
    if (inputs.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _open(inputs);
        if (mounted && ref.read(translateOnStartProvider)) await _translate();
      });
    }
  }

  void _snack(String text, {SnackBarAction? action}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), action: action, showCloseIcon: true));

  Future<void> _open(List<String> paths) async {
    if (paths.isEmpty) return;
    final l = context.l10n;
    final outcome = await ref.read(workspaceProvider.notifier).addInputs(paths);
    if (!mounted) return;
    for (final e in outcome.errors.entries) {
      _snack(l.importFailed(p.basename(e.key), '${e.value}'));
    }
    if (outcome.skipped.isNotEmpty) _snack(l.skippedFiles(outcome.skipped.map(p.basename).join(', ')));
    if (outcome.added == 0 && outcome.errors.isEmpty && outcome.skipped.isEmpty) _snack(l.noPagesFound);
  }

  Future<void> _pickFiles() async {
    final files = await openFiles(
      acceptedTypeGroups: [
        XTypeGroup(
          label: context.l10n.supportedFormats,
          extensions: [
            for (final e in [...imageExtensions, ...archiveExtensions, ...pdfExtensions]) e.substring(1),
          ],
        ),
      ],
    );
    await _open([for (final f in files) f.path]);
  }

  Future<void> _pickFolder() async {
    final dir = await getDirectoryPath();
    if (dir != null) await _open([dir]);
  }

  Future<void> _translate() async {
    final l = context.l10n;
    await ref.read(batchProvider.notifier).run(DialogBatchUi(context));
    if (!mounted) return;
    final report = switch (ref.read(batchProvider)) {
      BatchIdle(:final last) => last,
      _ => null,
    };
    if (report == null) return;
    if (report.skipped.isNotEmpty || report.cancelled || report.exportDirs.isNotEmpty) {
      await showBatchReport(context, report);
    } else {
      _snack(l.reportSummary('${report.done}', '${report.total}', formatDuration(report.duration)));
    }
  }

  Future<void> _export() async {
    final l = context.l10n;
    final pages = ref.read(workspaceProvider).pages;
    if (!pages.any((p) => p.isDone)) {
      _snack(l.nothingToExport);
      return;
    }
    final dir = await getDirectoryPath(confirmButtonText: l.export);
    if (dir == null) return;
    final count = await exportTranslatedPages(pages, dir, ref.read(settingsProvider).export.imageFormat);
    if (mounted) {
      _snack(
        l.exportDone('$count', dir),
        action: SnackBarAction(label: l.showInFolder, onPressed: () => showInExplorer(dir)),
      );
    }
  }

  Future<void> _closeAll() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(l.closeAllConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.closeAll)),
        ],
      ),
    );
    if (ok ?? false) ref.read(workspaceProvider.notifier).clear();
  }

  void _openSettings([SettingsSection section = SettingsSection.general]) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsScreen(initial: section)));

  @override
  Widget build(BuildContext context) {
    final ws = ref.watch(workspaceProvider);
    final running = ref.watch(batchProvider) is BatchRunning;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): _pickFiles,
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (!running && ws.pages.isNotEmpty) _translate();
        },
        const SingleActivator(LogicalKeyboardKey.pageDown): () =>
            ref.read(workspaceProvider.notifier).select(ws.current + 1),
        const SingleActivator(LogicalKeyboardKey.pageUp): () =>
            ref.read(workspaceProvider.notifier).select(ws.current - 1),
      },
      child: Focus(
        autofocus: true,
        child: DropTarget(
          onDragEntered: (_) => setState(() => _dragging = true),
          onDragExited: (_) => setState(() => _dragging = false),
          onDragDone: (d) {
            setState(() => _dragging = false);
            _open([for (final f in d.files) f.path]);
          },
          child: Scaffold(
            body: Stack(
              children: [
                Column(
                  children: [
                    _TopBar(
                      onOpenFiles: _pickFiles,
                      onOpenFolder: _pickFolder,
                      onTranslate: _translate,
                      onExport: _export,
                      onCloseAll: _closeAll,
                      onSettings: _openSettings,
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ws.pages.isEmpty
                          ? HomeView(onOpenFiles: _pickFiles, onOpenFolder: _pickFolder, busy: ws.importing)
                          : LayoutBuilder(
                              builder: (context, c) => Row(
                                children: [
                                  SizedBox(
                                    width: c.maxWidth < 1200 ? 200 : 230,
                                    child: PageList(onAdd: running ? null : _pickFiles),
                                  ),
                                  const VerticalDivider(width: 1),
                                  const Expanded(child: PageViewer()),
                                  const VerticalDivider(width: 1),
                                  SizedBox(width: (c.maxWidth * 0.22).clamp(240.0, 340.0), child: const TextPanel()),
                                ],
                              ),
                            ),
                    ),
                    const Divider(height: 1),
                    const _StatusBar(),
                  ],
                ),
                if (_dragging)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.file_download_outlined,
                          size: 96,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.onOpenFiles,
    required this.onOpenFolder,
    required this.onTranslate,
    required this.onExport,
    required this.onCloseAll,
    required this.onSettings,
  });

  final VoidCallback onOpenFiles;
  final VoidCallback onOpenFolder;
  final VoidCallback onTranslate;
  final VoidCallback onExport;
  final VoidCallback onCloseAll;
  final void Function([SettingsSection section]) onSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final ws = ref.watch(workspaceProvider);
    final batch = ref.watch(batchProvider);
    final running = batch is BatchRunning;
    final hasPages = ws.pages.isNotEmpty;
    final last = batch is BatchIdle ? batch.last : null;
    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 1200;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              MenuAnchor(
                menuChildren: [
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.insert_drive_file_outlined),
                    onPressed: onOpenFiles,
                    child: Text(l.openFiles),
                  ),
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.folder_open_outlined),
                    onPressed: onOpenFolder,
                    child: Text(l.openFolder),
                  ),
                  if (hasPages) ...[
                    const Divider(),
                    MenuItemButton(
                      leadingIcon: const Icon(Icons.close),
                      onPressed: running ? null : onCloseAll,
                      child: Text(l.closeAll),
                    ),
                  ],
                ],
                builder: (context, controller, _) {
                  void toggle() => controller.isOpen ? controller.close() : controller.open();
                  return compact
                      ? IconButton.filledTonal(
                          tooltip: l.openFiles,
                          onPressed: running ? null : toggle,
                          icon: const Icon(Icons.folder_open),
                        )
                      : FilledButton.tonalIcon(
                          onPressed: running ? null : toggle,
                          icon: const Icon(Icons.folder_open),
                          label: Text(l.openFiles.replaceAll('…', '')),
                        );
                },
              ),
              const SizedBox(width: 16),
              const _LanguagePickers(),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _TranslatorChip(onTap: () => onSettings(SettingsSection.translator), compact: compact),
                ),
              ),
              const SizedBox(width: 12),
              if (running)
                OutlinedButton.icon(
                  onPressed: (batch).stopping ? null : () => ref.read(batchProvider.notifier).stop(),
                  icon: const Icon(Icons.stop),
                  label: Text(batch.stopping ? l.stopping : l.stop),
                )
              else
                FilledButton.icon(
                  onPressed: hasPages ? onTranslate : null,
                  icon: const Icon(Icons.translate),
                  label: Text(hasPages && ws.pages.every((p) => p.isDone) ? l.translateAgain : l.translateAll),
                ),
              if (last != null) ...[
                const SizedBox(width: 8),
                _ToolButton(
                  compact: compact,
                  icon: last.skipped.isEmpty ? Icons.fact_check_outlined : Icons.warning_amber,
                  label: l.report,
                  onPressed: () => showBatchReport(context, last),
                ),
              ],
              const SizedBox(width: 8),
              _ToolButton(
                compact: compact,
                icon: Icons.save_alt,
                label: l.export,
                onPressed: ws.doneCount > 0 && !running ? onExport : null,
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: l.settings,
                onPressed: running ? null : () => onSettings(),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A text button that becomes an icon with a tooltip in narrow windows.
class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.compact, required this.icon, required this.label, required this.onPressed});

  final bool compact;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => compact
      ? IconButton(tooltip: label, onPressed: onPressed, icon: Icon(icon))
      : TextButton.icon(onPressed: onPressed, icon: Icon(icon), label: Text(label));
}

class _LanguagePickers extends ConsumerWidget {
  const _LanguagePickers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider);
    final running = ref.watch(batchProvider) is BatchRunning;
    Widget picker(
      String tooltip,
      String value,
      Iterable<Language> options,
      void Function(AppSettings s, String v) apply,
    ) => Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 150,
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          borderRadius: BorderRadius.circular(8),
          items: [
            for (final lang in options)
              DropdownMenuItem(
                value: lang.name,
                child: Text(lang.nativeLabel, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: running ? null : (v) => ref.read(settingsProvider.notifier).change((s) => apply(s, v!)),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        picker(
          l.sourceLanguage,
          settings.sourceLanguage,
          Languages.all.where((x) => x.source),
          (s, v) => s.sourceLanguage = v,
        ),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward, size: 18)),
        picker(
          l.targetLanguage,
          settings.targetLanguage,
          Languages.all.where((x) => x.target),
          (s, v) => s.targetLanguage = v,
        ),
      ],
    );
  }
}

/// The chosen translator and where it sends text.
class _TranslatorChip extends ConsumerWidget {
  const _TranslatorChip({required this.onTap, this.compact = false});

  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final services = ref.watch(servicesProvider);
    if (!services.registry.contains(settings.translator)) return const SizedBox.shrink();
    final info = services.registry.info(settings.translator);
    final endpoint = info.endpointFor(PluginConfig.resolve(info.settings, settings.pluginValues(info.id)));
    return Tooltip(
      message: endpoint == null ? context.l10n.privacyLocal : context.l10n.sendsDataWarning(endpoint.host),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          // The badge matters more than the name: the name goes first when
          // space is short, then the badge's words.
          child: LayoutBuilder(
            builder: (context, box) => box.maxWidth < 36
                ? const SizedBox.shrink()
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!compact && box.maxWidth > 240) ...[
                        Flexible(child: Text(pluginName(context, info), overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 6),
                      ],
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: box.maxWidth),
                        child: PrivacyBadge(endpoint?.privacy ?? Privacy.local, iconOnly: box.maxWidth < 80),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _StatusBar extends ConsumerWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final batch = ref.watch(batchProvider);
    final ws = ref.watch(workspaceProvider);
    final style = Theme.of(context).textTheme.bodySmall;
    final Widget content;
    if (batch is BatchRunning) {
      final stage = batch.stage == 'download'
          ? l.stageDownloading('${((batch.download ?? 0) * 100).round()}')
          : stageLabel(l, batch.stage);
      final page = batch.pageName == null ? '' : '${l.progressPage('${batch.done + 1}', '${batch.total}')} · ';
      final left = batch.remaining;
      final value = batch.stage == 'download'
          ? batch.download
          : batch.pageName == null
          ? null
          : (batch.done + stageFraction(batch.stage)) / batch.total;
      content = Row(
        children: [
          Expanded(
            child: Text(
              '$page$stage${left == null ? '' : ' · ${l.remaining(formatDuration(left))}'}',
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 240, child: LinearProgressIndicator(value: value)),
        ],
      );
    } else {
      content = Text(ws.pages.isEmpty ? '' : l.pagesSummary('${ws.pages.length}', '${ws.doneCount}'), style: style);
    }
    return SizedBox(
      height: 30,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Align(alignment: Alignment.centerLeft, child: content),
      ),
    );
  }
}
