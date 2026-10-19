/// The main window: toolbar, page list, page viewer, text panel, status bar.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show AppExitResponse;

import 'package:ct_core/ct_core.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../app_info.dart';
import '../../state/app_state.dart';
import '../../state/batch.dart';
import '../../state/editor.dart';
import '../../state/export.dart';
import '../../state/project.dart';
import '../../state/steps.dart';
import '../../state/window_mode.dart';
import '../../state/workspace.dart';
import '../common/labels.dart';
import '../common/plugin_strings.dart';
import '../settings/settings_screen.dart';
import 'batch_dialogs.dart';
import 'export_dialog.dart';
import 'home_view.dart';
import 'page_list.dart';
import 'page_viewer.dart';
import 'shortcuts_dialog.dart';
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
  String? _title;
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(onExitRequested: _confirmExit);

  /// Closing asks about unsaved work (a project with autosave saves itself
  /// first); a normal exit removes the recovery copy.
  Future<AppExitResponse> _confirmExit() async {
    if (!await _settleUnsaved()) return AppExitResponse.cancel;
    await ref.read(projectProvider.notifier).discardRecovery();
    return AppExitResponse.exit;
  }

  /// Before the open pages go away (exit, closing all, opening a project):
  /// saves them, or lets the user choose. False: stay.
  Future<bool> _settleUnsaved() async {
    final project = ref.read(projectProvider);
    if (ref.read(workspaceProvider).pages.isEmpty || !project.dirty) return true;
    if (project.path != null &&
        ref.read(settingsProvider).projectAutosave &&
        await ref.read(projectProvider.notifier).save()) {
      return true;
    }
    if (!mounted) return false;
    final l = context.l10n;
    final choice = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.unsavedTitle),
        content: Text(project.path == null ? l.unsavedNew : l.unsavedProject(project.name!)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.pop(c, 'discard'), child: Text(l.dontSave)),
          FilledButton(
            onPressed: () => Navigator.pop(c, 'save'),
            child: Text(project.path == null ? l.saveAs : l.save),
          ),
        ],
      ),
    );
    return switch (choice) {
      'discard' => true,
      'save' => _saveProject(),
      _ => false,
    };
  }

  /// Ctrl+S: into the project's file (a new one the first time).
  Future<bool> _saveProject({bool asNew = false}) async {
    if (ref.read(workspaceProvider).pages.isEmpty) return false;
    String? to;
    if (asNew || ref.read(projectProvider).path == null) {
      to = await _askProjectPath();
      if (to == null) return false;
    }
    final ok = await ref.read(projectProvider.notifier).save(to: to);
    if (!ok && mounted) _snack(context.l10n.projectSaveFailed(ref.read(projectProvider).error ?? ''));
    return ok;
  }

  Future<String?> _askProjectPath() async {
    final l = context.l10n;
    final ws = ref.read(workspaceProvider);
    final project = ref.read(projectProvider);
    final first = ws.pages.first;
    final cache = ref.read(servicesProvider).paths.cache.path;
    final from = first.source ?? first.path;
    final String name;
    if (project.name != null) {
      name = project.name!;
    } else if (first.source != null) {
      name = p.basenameWithoutExtension(first.source!);
    } else {
      name = ws.pages.length > 1 ? p.basename(p.dirname(first.path)) : p.basenameWithoutExtension(first.name);
    }
    final location = await getSaveLocation(
      acceptedTypeGroups: [
        XTypeGroup(label: l.projectFileType, extensions: [ProjectFile.extension.substring(1)]),
      ],
      initialDirectory: project.path != null
          ? p.dirname(project.path!)
          : p.isWithin(cache, from)
          ? null
          : p.dirname(from),
      suggestedName: '$name${ProjectFile.extension}',
      confirmButtonText: l.save,
    );
    if (location == null) return null;
    return isProjectPath(location.path) ? location.path : '${location.path}${ProjectFile.extension}';
  }

  /// Opens a project ([path], or one the user picks) instead of the open
  /// pages.
  Future<void> _openProject([String? path]) async {
    final l = context.l10n;
    path ??= (await openFile(
      acceptedTypeGroups: [
        XTypeGroup(label: l.projectFileType, extensions: [ProjectFile.extension.substring(1)]),
      ],
    ))?.path;
    if (path == null || !mounted || !await _settleUnsaved() || !mounted) return;
    final notifier = ref.read(projectProvider.notifier);
    try {
      await _withProgress(l.openingProject, (_) => notifier.open(path!));
    } on Object catch (e, st) {
      ref.read(servicesProvider).appLog.error('project_open_failed', e, st);
      if (!mounted) return;
      final why = switch (e) {
        ProjectFormatException(newerVersion: true) => l.projectNewer,
        ProjectFormatException(:final message) when message.contains('damaged') => l.projectDamaged,
        ProjectFormatException() => l.projectNotProject,
        FileSystemException(osError: null) => l.fileNotFound,
        FileSystemException(:final osError) => osError!.message,
        _ => '$e',
      };
      _snack(l.projectOpenFailed(why));
    }
  }

  /// After a crash: offers the copy of the unsaved work.
  Future<void> _offerRecovery() async {
    final notifier = ref.read(projectProvider.notifier);
    final recovery = notifier.findRecovery();
    if (recovery == null || !mounted || ref.read(workspaceProvider).pages.isNotEmpty) return;
    final l = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final when = recovery.saved == null ? '' : DateFormat.yMd(locale).add_Hm().format(recovery.saved!);
    final restore = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.restore),
        title: Text(l.recoveryTitle),
        content: Text(l.recoveryBody('${recovery.pages}', when)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.recoveryDiscard)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.recoveryRestore)),
        ],
      ),
    );
    if (!mounted) return;
    if (restore != true) {
      await notifier.discardRecovery();
      return;
    }
    try {
      await _withProgress(l.openingProject, (_) => notifier.restoreRecovery());
      if (mounted) _snack(l.recoveryRestored);
    } on Object catch (e, st) {
      ref.read(servicesProvider).appLog.error('recovery_restore_failed', e, st);
      if (mounted) _snack(l.projectOpenFailed('$e'));
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onHardwareKey);
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onHardwareKey);
    _lifecycle;
    final section = ref.read(settingsOnStartProvider);
    if (section != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openSettings(SettingsSection.values.asNameMap()[section] ?? SettingsSection.general),
      );
    }
    final inputs = ref.read(initialInputsProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _offerRecovery();
      if (inputs.isEmpty || !mounted) return;
      await _open(inputs);
      if (mounted && ref.read(translateOnStartProvider)) await _translate();
    });
  }

  void _snack(String text, {SnackBarAction? action}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), action: action, showCloseIcon: true));

  Future<void> _open(List<String> paths) async {
    if (paths.isEmpty) return;
    final project = paths.where(isProjectPath).firstOrNull;
    if (project != null) {
      await _openProject(project);
      return;
    }
    final l = context.l10n;
    final outcome = await ref.read(workspaceProvider.notifier).addInputs(paths);
    if (!mounted) return;
    for (final e in outcome.errors.entries) {
      final why = e.value is ArchiveToolMissingException ? l.needsArchiveTool : '${e.value}';
      _snack(l.importFailed(p.basename(e.key), why));
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
            for (final e in [...imageExtensions, ...archiveExtensions, ...pdfExtensions, ProjectFile.extension])
              e.substring(1),
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

  /// The Export window, then the files.
  Future<void> _export() async {
    final l = context.l10n;
    final ws = ref.read(workspaceProvider);
    final done = [
      for (final page in ws.pages)
        if (page.isDone) page,
    ];
    if (done.isEmpty) {
      _snack(l.nothingToExport);
      return;
    }
    final current = ws.currentPage;
    final choice = await showExportDialog(
      context,
      initial: ref.read(settingsProvider).export,
      pageCount: done.length,
      chapters: chapterCount(done),
      currentAvailable: current != null && current.isDone,
      hasSevenZip: findSevenZip() != null,
    );
    if (choice == null || !mounted) return;
    await ref.read(settingsProvider.notifier).change((s) => s.export = choice.settings);
    final pages = choice.currentOnly ? [current!] : done;
    final options = choice.settings.options;
    final split = options.byChapter && chapterCount(pages) > 1;
    final chapter = chapterOf(pages.first);
    final book =
        ref.read(projectProvider).name ??
        (chapter.isNotEmpty ? chapter : (choice.currentOnly ? p.basenameWithoutExtension(pages.first.name) : 'comic'));
    String? target;
    if (options.container == ExportContainer.folder || split) {
      target = await getDirectoryPath(confirmButtonText: l.export);
    } else {
      final ext = options.container.extension;
      final location = await getSaveLocation(
        acceptedTypeGroups: [
          XTypeGroup(label: ext.substring(1).toUpperCase(), extensions: [ext.substring(1)]),
        ],
        suggestedName: '${safeFileStem(book)}$ext',
        confirmButtonText: l.export,
      );
      target = location == null
          ? null
          : location.path.toLowerCase().endsWith(ext)
          ? location.path
          : '${location.path}$ext';
    }
    if (target == null || !mounted) return;
    final ids = [for (final page in pages) page.id];
    final ExportResult result;
    try {
      result = await _withProgress(
        options.translated ? l.drawingPages : l.exportingPages,
        (progress) => exportOpenPages(ref.read, ids, options, target!, bookName: book, onProgress: progress),
      );
    } catch (e, st) {
      ref.read(servicesProvider).appLog.error('export_failed', e, st, {'container': options.container.name});
      if (mounted) {
        _snack(switch (e) {
          ArchiveToolMissingException() => l.exportNeeds7zip,
          FileSystemException(:final osError, :final message) => l.exportFailed(osError?.message ?? message),
          _ => l.exportFailed('$e'),
        });
      }
      return;
    }
    ref.read(servicesProvider).appLog.info('exported', {
      'container': options.container.name,
      'pages': result.pages,
      'files': result.outputs.length,
    });
    if (options.translated) ref.read(workspaceProvider.notifier).markExported(ids);
    if (mounted) {
      final shown = result.outputs.length == 1 ? result.outputs.single : target;
      _snack(
        l.exportSaved(shown),
        action: SnackBarAction(label: l.showInFolder, onPressed: () => showInExplorer(shown)),
      );
    }
  }

  /// Runs [work] behind a dialog with its progress (done of total).
  Future<T> _withProgress<T>(String label, Future<T> Function(void Function(int done, int total) progress) work) async {
    final value = ValueNotifier<double?>(null);
    final dialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: 12),
              ValueListenableBuilder(
                valueListenable: value,
                builder: (_, v, _) => LinearProgressIndicator(value: v),
              ),
            ],
          ),
        ),
      ),
    );
    try {
      return await work((done, total) => value.value = total == 0 ? null : done / total);
    } finally {
      if (mounted) Navigator.of(context).pop();
      await dialog;
      value.dispose();
    }
  }

  /// Closes the pages (and the project), after saving or asking.
  Future<void> _closeAll() async {
    if (await _settleUnsaved()) ref.read(workspaceProvider.notifier).clear();
  }

  void _openSettings([SettingsSection section = SettingsSection.general]) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsScreen(initial: section)));

  @override
  Widget build(BuildContext context) {
    final ws = ref.watch(workspaceProvider);
    final running = ref.watch(batchProvider) is BatchRunning;
    final project = ref.watch(projectProvider);
    final title = ws.pages.isEmpty
        ? AppInfo.name
        : '${project.name ?? context.l10n.untitledProject}${project.dirty ? ' *' : ''} — ${AppInfo.name}';
    if (title != _title) {
      _title = title;
      setWindowTitle(title);
    }
    return Focus(
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
                    onOpenProject: _openProject,
                    onSaveProject: () => _saveProject(),
                    onSaveProjectAs: () => _saveProject(asNew: true),
                    onTranslate: _translate,
                    onExport: _export,
                    onCloseAll: _closeAll,
                    onSettings: _openSettings,
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ws.pages.isEmpty
                        ? HomeView(
                            onOpenFiles: _pickFiles,
                            onOpenFolder: _pickFolder,
                            onOpenProject: _openProject,
                            busy: ws.importing,
                          )
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
                      child: Icon(Icons.file_download_outlined, size: 96, color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Shortcuts work wherever the focus is, but only on this screen (not in
  /// the settings or under a dialog).
  bool _onHardwareKey(KeyEvent e) => mounted && (ModalRoute.of(context)?.isCurrent ?? true) && _onKey(e);

  /// Keyboard shortcuts of the window (original `app/shortcuts.py` plus the
  /// tools). Letters and editing keys do nothing while a text field has the
  /// focus, so typing is never taken over.
  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return false;
    final keyboard = HardwareKeyboard.instance;
    final ctrl = keyboard.isControlPressed, shift = keyboard.isShiftPressed, alt = keyboard.isAltPressed;
    final typing = FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<EditableText>() != null;
    final key = e.logicalKey;
    final ws = ref.read(workspaceProvider.notifier);
    final state = ref.read(workspaceProvider);
    final running = ref.read(batchProvider) is BatchRunning;
    final busy = running || ref.read(stepsProvider).running;
    final editor = ref.read(editorProvider.notifier);
    if (ctrl && !alt) {
      if (key == LogicalKeyboardKey.keyS) {
        if (state.pages.isNotEmpty) _saveProject(asNew: shift);
        return true;
      }
      if (key == LogicalKeyboardKey.keyO) {
        if (!running) _pickFiles();
        return true;
      }
      if (key == LogicalKeyboardKey.enter) {
        if (!busy && state.pages.isNotEmpty) _translate();
        return true;
      }
      if (key == LogicalKeyboardKey.keyF || key == LogicalKeyboardKey.keyH) {
        if (state.pages.isNotEmpty) ref.read(findOpenProvider.notifier).set(true);
        return true;
      }
      if (typing || busy) return false;
      if (key == LogicalKeyboardKey.keyZ && !shift) {
        ws.undo();
        return true;
      }
      if (key == LogicalKeyboardKey.keyY || (key == LogicalKeyboardKey.keyZ && shift)) {
        ws.redo();
        return true;
      }
      return false;
    }
    if (key == LogicalKeyboardKey.f1 && !ctrl && !alt) {
      showShortcuts(context);
      return true;
    }
    if (typing || alt) return false;
    if (key == LogicalKeyboardKey.pageDown) {
      ws.select(state.current + 1);
      return true;
    }
    if (key == LogicalKeyboardKey.pageUp) {
      ws.select(state.current - 1);
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (state.selectedBlock == null) return false;
      ws.selectBlock(null);
      return true;
    }
    if (state.pages.isEmpty) return false;
    final tools = {
      LogicalKeyboardKey.keyH: EditorTool.pan,
      LogicalKeyboardKey.keyV: EditorTool.pan,
      LogicalKeyboardKey.keyR: EditorTool.boxes,
      LogicalKeyboardKey.keyT: EditorTool.text,
      LogicalKeyboardKey.keyB: EditorTool.brush,
      LogicalKeyboardKey.keyE: EditorTool.eraser,
    };
    if (tools[key] case final tool?) {
      editor.setTool(tool);
      return true;
    }
    if (key == LogicalKeyboardKey.bracketLeft || key == LogicalKeyboardKey.bracketRight) {
      final size = ref.read(editorProvider).brushSize;
      final step = math.max(1.0, size * 0.15);
      editor.setBrushSize(key == LogicalKeyboardKey.bracketLeft ? size - step : size + step);
      return true;
    }
    if ((key == LogicalKeyboardKey.delete || key == LogicalKeyboardKey.backspace) && !busy) {
      final i = state.selectedBlock;
      if (i == null) return false;
      ws.deleteBlock(i);
      return true;
    }
    return false;
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.onOpenFiles,
    required this.onOpenFolder,
    required this.onOpenProject,
    required this.onSaveProject,
    required this.onSaveProjectAs,
    required this.onTranslate,
    required this.onExport,
    required this.onCloseAll,
    required this.onSettings,
  });

  final VoidCallback onOpenFiles;
  final VoidCallback onOpenFolder;
  final void Function([String? path]) onOpenProject;
  final VoidCallback onSaveProject;
  final VoidCallback onSaveProjectAs;
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
    final recent = ref.watch(settingsProvider.select((s) => s.recentProjects));
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
                  const Divider(),
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.auto_stories_outlined),
                    onPressed: () => onOpenProject(),
                    child: Text(l.openProject),
                  ),
                  if (recent.isNotEmpty)
                    SubmenuButton(
                      leadingIcon: const Icon(Icons.history),
                      menuChildren: [
                        for (final path in recent)
                          MenuItemButton(
                            onPressed: () => onOpenProject(path),
                            child: Text(p.basenameWithoutExtension(path)),
                          ),
                      ],
                      child: Text(l.recentProjects),
                    ),
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.save_outlined),
                    onPressed: hasPages ? onSaveProject : null,
                    child: Text(l.saveProject),
                  ),
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.save_as_outlined),
                    onPressed: hasPages ? onSaveProjectAs : null,
                    child: Text(l.saveProjectAs),
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
                  onPressed: hasPages && !ref.watch(stepsProvider).running ? onTranslate : null,
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
    final ws = ref.watch(workspaceProvider);
    final page = ws.currentPage;
    final source = page?.sourceOf(settings) ?? settings.sourceLanguage;
    final target = page?.targetOf(settings) ?? settings.targetLanguage;
    final differ = ws.pages.any((p) => p.sourceOf(settings) != source || p.targetOf(settings) != target);
    // The pickers show the current page's languages (original); new pages
    // take them too.
    void choose({String? source, String? target}) {
      ref.read(settingsProvider.notifier).change((s) {
        if (source != null) s.sourceLanguage = source;
        if (target != null) s.targetLanguage = target;
      });
      ref.read(workspaceProvider.notifier).setLanguages(source: source, target: target);
    }

    Widget picker(
      String tooltip,
      String value,
      Iterable<Language> options,
      void Function(String v) apply,
    ) => Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 136,
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
          onChanged: running ? null : (v) => apply(v!),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        picker(l.sourceLanguage, source, Languages.all.where((x) => x.source), (v) => choose(source: v)),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Icon(Icons.arrow_forward, size: 18)),
        picker(l.targetLanguage, target, Languages.all.where((x) => x.target), (v) => choose(target: v)),
        // Only while the pages have different languages.
        if (differ)
          IconButton(
            tooltip: l.languagesForAll,
            visualDensity: VisualDensity.compact,
            onPressed: running
                ? null
                : () => ref.read(workspaceProvider.notifier).setLanguages(source: source, target: target, all: true),
            icon: const Icon(Icons.playlist_add_check, size: 20),
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
    final project = ref.watch(projectProvider);
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall;
    final Widget saved;
    if (ws.pages.isEmpty) {
      saved = const SizedBox.shrink();
    } else {
      final status = project.saving
          ? l.projectSaving
          : project.error != null
          ? l.projectSaveFailed(project.error!)
          : project.path == null
          ? l.projectNoFile
          : project.dirty || project.savedAt == null
          ? l.projectUnsaved
          : l.projectSavedAt(DateFormat.Hm(Localizations.localeOf(context).toString()).format(project.savedAt!));
      saved = Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              project.error != null ? Icons.error_outline : Icons.save_outlined,
              size: 14,
              color: project.error != null ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                [if (project.name != null) project.name!, status].join(' · '),
                style: project.error != null ? style?.copyWith(color: theme.colorScheme.error) : style,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
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
          saved,
        ],
      );
    } else {
      content = Row(
        children: [
          Expanded(
            child: Text(ws.pages.isEmpty ? '' : l.pagesSummary('${ws.pages.length}', '${ws.doneCount}'), style: style),
          ),
          saved,
        ],
      );
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
