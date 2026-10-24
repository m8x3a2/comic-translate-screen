/// The page viewer: tools, the single steps, zoom and pan around the page
/// canvas (original `image_viewer.py` and the manual-mode buttons of
/// `main_window/builders/workspace.py`).
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../../state/batch.dart';
import '../../state/editor.dart';
import '../../state/steps.dart';
import '../../state/page_layout.dart';
import '../../state/workspace.dart';
import '../common/content_kind_switch.dart';
import '../common/labels.dart';
import '../common/panels.dart';
import 'batch_dialogs.dart';
import 'page_canvas.dart';
import 'shortcuts_dialog.dart';
import 'webtoon_strip.dart';

class PageViewer extends ConsumerStatefulWidget {
  const PageViewer({super.key});

  @override
  ConsumerState<PageViewer> createState() => _PageViewerState();
}

class _PageViewerState extends ConsumerState<PageViewer> {
  final _transform = TransformationController();
  final _strip = GlobalKey<WebtoonStripState>();
  Size? _imageSize;
  Size _viewport = Size.zero;
  String? _shownPath;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void dispose() {
    _detach();
    _transform.dispose();
    super.dispose();
  }

  void _detach() {
    if (_listener != null) _stream?.removeListener(_listener!);
    _stream = null;
    _listener = null;
  }

  /// Reads the page size (to fit it into the window) when the page changes.
  void _watchImage(String path) {
    if (path == _shownPath) return;
    _shownPath = path;
    _detach();
    final stream = FileImage(File(path)).resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(() => _imageSize = Size(info.image.width.toDouble(), info.image.height.toDouble()));
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
    }, onError: (_, _) {});
    _stream = stream..addListener(_listener!);
  }

  void _fit() {
    if (!mounted) return;
    if (ref.read(workspaceProvider).webtoon) return _strip.currentState?.fit();
    final size = _imageSize;
    if (size == null || _viewport.isEmpty || !mounted) return;
    final s = math.min(_viewport.width / size.width, _viewport.height / size.height) * 0.98;
    final dx = (_viewport.width - size.width * s) / 2, dy = (_viewport.height - size.height * s) / 2;
    _transform.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(s, s, 1, 1);
    setState(() {});
  }

  void _zoom(double factor) {
    final c = _viewport.center(Offset.zero);
    _transform.value = Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(factor, factor, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1)
      ..multiply(_transform.value);
    setState(() {});
  }

  /// Screen pixels per page pixel, in percent.
  double _percent(double dpr) => _transform.value.entry(0, 0) * dpr * 100;

  /// One page pixel per screen pixel.
  void _actualSize() => _zoom(100 / _percent(MediaQuery.devicePixelRatioOf(context)));

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ws = ref.watch(workspaceProvider);
    final page = ws.currentPage;
    if (page == null) return const SizedBox.shrink();
    ref.listen(workspaceProvider.select((s) => s.currentPage?.id), (_, _) {
      if (ref.read(workspaceProvider).webtoon) return;
      _shownPath = null;
      _imageSize = null;
    });
    // Back from the strip: the page fitted into the window again.
    ref.listen(workspaceProvider.select((s) => s.webtoon), (_, on) {
      if (on) return;
      _shownPath = null;
      _imageSize = null;
    });
    // A panel folded or opened: the page fitted into the new room (after
    // the next layout, which measures it).
    ref.listen(settingsProvider.select((s) => (List.of(s.hiddenPanels)..sort()).join(',')), (_, _) {
      if (ref.read(workspaceProvider).webtoon) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => WidgetsBinding.instance.addPostFrameCallback((_) => _fit()));
    });
    if (!ws.webtoon) _watchImage(page.path);
    final editor = ref.watch(editorProvider);
    final steps = ref.watch(stepsProvider);
    final batchRunning = ref.watch(batchProvider) is BatchRunning;
    final stepHere = steps.running && steps.pageId == page.id;
    final readOnly = batchRunning || stepHere || page.status == PageStatus.running;
    bool readOnlyPage(PageEntry p) =>
        batchRunning || (steps.running && steps.pageId == p.id) || p.status == PageStatus.running;
    final theme = Theme.of(context);
    return Column(
      children: [
        if (panelHidden(ref, Panels.tools))
          FoldedToolBar(label: l.panelTools)
        else ...[
          const _ToolBar(),
          _StepStrip(page: page),
        ],
        const Divider(height: 1),
        Expanded(
          child: ClipRect(
            child: ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final viewport = constraints.biggest;
                  if (viewport != _viewport) {
                    final first = _viewport.isEmpty;
                    _viewport = viewport;
                    if (first) WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
                  }
                  final size = _imageSize;
                  return Stack(
                    children: [
                      if (ws.webtoon)
                        WebtoonStrip(key: _strip, transform: _transform, readOnly: readOnlyPage, pan: batchRunning)
                      else
                        InteractiveViewer(
                          transformationController: _transform,
                          constrained: false,
                          minScale: 0.02,
                          maxScale: 32,
                          panEnabled: editor.tool == EditorTool.pan || readOnly,
                          boundaryMargin: const EdgeInsets.all(double.infinity),
                          onInteractionUpdate: (_) => setState(() {}),
                          child: size == null
                              ? const SizedBox(width: 1, height: 1)
                              : SizedBox(
                                  width: size.width,
                                  height: size.height,
                                  child: PageCanvas(
                                    key: ValueKey(page.id),
                                    page: page,
                                    size: size,
                                    transform: _transform,
                                    readOnly: readOnly,
                                  ),
                                ),
                        ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Card(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _EnlargedBadge(),
                              IconButton(
                                tooltip: l.zoomOut,
                                onPressed: () => _zoom(1 / 1.25),
                                icon: const Icon(Icons.zoom_out),
                              ),
                              // The strip zooms and scrolls on its own: follow it.
                              ListenableBuilder(
                                listenable: _transform,
                                builder: (context, _) => SizedBox(
                                  width: 48,
                                  child: Text(
                                    '${_percent(MediaQuery.devicePixelRatioOf(context)).round()}%',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: l.zoomIn,
                                onPressed: () => _zoom(1.25),
                                icon: const Icon(Icons.zoom_in),
                              ),
                              IconButton(
                                tooltip: l.zoomFit,
                                onPressed: _fit,
                                icon: const Icon(Icons.fit_screen_outlined),
                              ),
                              IconButton(
                                tooltip: l.zoomActual,
                                onPressed: _actualSize,
                                icon: const Icon(Icons.crop_original),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (page.status == PageStatus.running || stepHere)
                        Positioned(
                          left: 12,
                          top: 12,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    stepHere && steps.stage == 'download'
                                        ? l.stageDownloading('${((steps.download ?? 0) * 100).round()}')
                                        : stageLabel(l, stepHere ? steps.stage : page.stage),
                                  ),
                                  const SizedBox(width: 4),
                                  if (stepHere)
                                    TextButton(
                                      onPressed: () => ref.read(stepsProvider.notifier).cancel(),
                                      child: Text(l.cancel),
                                    )
                                  else
                                    const SizedBox(width: 8, height: 40),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (page.status == PageStatus.skipped && !stepHere)
                        Positioned(
                          left: 12,
                          right: 12,
                          top: 12,
                          child: Card(
                            color: theme.colorScheme.errorContainer,
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(
                                l.statusSkipped(reasonLabel(l, page.reason)),
                                style: TextStyle(color: theme.colorScheme.onErrorContainer),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// View, tools, brush size, undo and redo.
/// Pixels the "all boxes" menu adds or takes on each side (the original's
/// default).
const allBoxesStep = 3;

/// How much the current page is enlarged before its translation is drawn
/// (setting "Enlarge pages"), as export will do it; nothing at ×1.
class _EnlargedBadge extends ConsumerWidget {
  const _EnlargedBadge();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(pageLayoutProvider.select((layout) => layout?.scale ?? 1.0));
    if (scale <= 1.0) return const SizedBox.shrink();
    final factor = formatFactor(context, scale);
    return Tooltip(
      message: context.l10n.pageEnlarged(factor),
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [const Icon(Icons.zoom_out_map, size: 16), const SizedBox(width: 4), Text('×$factor')],
        ),
      ),
    );
  }
}

class _ToolBar extends ConsumerWidget {
  const _ToolBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final editor = ref.watch(editorProvider);
    final ws = ref.watch(workspaceProvider);
    final page = ws.currentPage;
    final notifier = ref.read(editorProvider.notifier);
    Widget tool(EditorTool t, IconData icon, String tip) => IconButton(
      tooltip: tip,
      isSelected: editor.tool == t,
      onPressed: () => notifier.setTool(t),
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: editor.tool == t ? Theme.of(context).colorScheme.secondaryContainer : null,
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<ViewMode>(
                  segments: [
                    ButtonSegment(value: ViewMode.original, label: Text(l.viewOriginal)),
                    ButtonSegment(value: ViewMode.result, label: Text(l.viewTranslated)),
                  ],
                  selected: {editor.view},
                  onSelectionChanged: (s) => notifier.setView(s.first),
                  showSelectedIcon: false,
                ),
                const SizedBox(width: 8),
                tool(EditorTool.pan, Icons.pan_tool_outlined, l.toolPan),
                tool(EditorTool.boxes, Icons.crop_free, l.toolBoxes),
                tool(EditorTool.text, Icons.text_fields_outlined, l.toolText),
                tool(EditorTool.brush, Icons.brush_outlined, l.toolBrush),
                tool(EditorTool.eraser, Icons.auto_fix_off_outlined, l.toolEraser),
                if (editor.paints) ...[
                  Tooltip(
                    message: l.brushSize,
                    child: SizedBox(
                      width: 150,
                      child: Slider(
                        value: editor.brushSize,
                        min: minBrushSize,
                        max: maxBrushSize,
                        onChanged: notifier.setBrushSize,
                      ),
                    ),
                  ),
                  SizedBox(width: 44, child: Text('${editor.brushSize.round()} px')),
                  IconButton(
                    tooltip: l.clearMask,
                    onPressed: page != null && page.hasMask
                        ? () => ref.read(workspaceProvider.notifier).clearMask()
                        : null,
                    icon: const Icon(Icons.layers_clear_outlined),
                  ),
                ],
                if (editor.tool == EditorTool.boxes)
                  MenuAnchor(
                    menuChildren: [
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.zoom_out_map),
                        onPressed: () => ref.read(workspaceProvider.notifier).growAllBlocks(allBoxesStep),
                        child: Text(l.boxesGrow('$allBoxesStep')),
                      ),
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.zoom_in_map),
                        onPressed: () => ref.read(workspaceProvider.notifier).growAllBlocks(-allBoxesStep),
                        child: Text(l.boxesShrink('$allBoxesStep')),
                      ),
                      MenuItemButton(
                        leadingIcon: const Icon(Icons.delete_sweep_outlined),
                        onPressed: () => ref.read(workspaceProvider.notifier).deleteAllBlocks(),
                        child: Text(l.boxesDeleteAll),
                      ),
                    ],
                    builder: (context, controller, _) => TextButton.icon(
                      onPressed: page == null || page.blocks.isEmpty
                          ? null
                          : () => controller.isOpen ? controller.close() : controller.open(),
                      icon: const Icon(Icons.select_all),
                      label: Text(l.boxesAll),
                    ),
                  ),
                if (editor.tool == EditorTool.pan)
                  FilterChip(
                    label: Text(l.showBoxes),
                    selected: editor.showBoxes,
                    onSelected: (_) => notifier.toggleBoxes(),
                  ),
              ],
            ),
          ),
          ContentKindSwitch(compact: true, onSwitched: (_) => _offerFindAgain(context, ref)),
          const SizedBox(width: 4),
          Tooltip(
            message: l.webtoonModeHelp,
            child: FilterChip(
              avatar: const Icon(Icons.view_day_outlined, size: 18),
              label: Text(l.webtoonMode),
              selected: ws.webtoon,
              showCheckmark: false,
              onSelected: (on) => ref.read(workspaceProvider.notifier).setWebtoon(on),
            ),
          ),
          IconButton(
            tooltip: l.shortcutsTooltip,
            onPressed: () => showShortcuts(context),
            icon: const Icon(Icons.keyboard_outlined),
          ),
          IconButton(
            tooltip: l.undo,
            onPressed: ws.canUndo ? () => ref.read(workspaceProvider.notifier).undo() : null,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: l.redo,
            onPressed: ws.canRedo ? () => ref.read(workspaceProvider.notifier).redo() : null,
            icon: const Icon(Icons.redo),
          ),
        ],
      ),
    );
  }
}

/// The steps of the manual mode, in order.
class _StepStrip extends ConsumerWidget {
  const _StepStrip({required this.page});

  final PageEntry page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final steps = ref.watch(stepsProvider);
    final busy = steps.running || ref.watch(batchProvider) is BatchRunning || page.status == PageStatus.running;
    final items = [
      (ManualStep.detect, Icons.document_scanner_outlined, l.stepDetect, l.stepDetectHelp),
      (ManualStep.recognize, Icons.abc, l.stepRecognize, l.stepRecognizeHelp),
      (ManualStep.translate, Icons.translate, l.stepTranslate, l.stepTranslateHelp),
      (ManualStep.mask, Icons.layers_outlined, l.stepMask, l.stepMaskHelp),
      (ManualStep.clean, Icons.cleaning_services_outlined, l.stepClean, l.stepCleanHelp),
    ];
    final picked = ref.watch(workspaceProvider.select((s) => s.selectedPages.length));
    final note = steps.running && steps.pages > 1
        ? l.progressPage('${steps.page}', '${steps.pages}')
        : picked > 1
        ? l.stepsForPicked('$picked')
        : null;
    return LayoutBuilder(
      builder: (context, c) {
        // The note sits outside the scrolling row so it is never cut off; the buttons lose their labels
        // first to leave it room.
        final compact = c.maxWidth < (note == null ? 720 : 900);
        final children = <Widget>[];
        for (final (i, (step, icon, label, help)) in items.indexed) {
          if (i > 0) children.add(Icon(Icons.chevron_right, size: 18, color: Theme.of(context).disabledColor));
          final running = steps.step == step && steps.pageId == page.id;
          final onPressed = busy ? null : () => ref.read(stepsProvider.notifier).run(step, DialogBatchUi(context));
          final iconWidget = running
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(icon, size: 20);
          children.add(
            Tooltip(
              message: '$label — $help',
              child: compact
                  ? IconButton(onPressed: onPressed, icon: iconWidget)
                  : TextButton.icon(onPressed: onPressed, icon: iconWidget, label: Text(label)),
            ),
          );
        }
        // Hidden while anything runs; a new run of a step or of "Translate all" replaces it.
        final last = busy ? null : steps.last;
        final strip = Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Row(
            children: [
              PanelToggle(Panels.tools, label: l.panelTools),
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: children),
                ),
              ),
              if (note != null)
                // Laid out before the buttons: they scroll when there is no room for both.
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: c.maxWidth * 0.6),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
            ],
          ),
        );
        if (last == null) return strip;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            strip,
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      stepResultLine(context, last),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// After "Comics / Sites and games" is switched: the boxes on the page were
/// found the other way and stay until the text is found again, so that is
/// offered.
void _offerFindAgain(BuildContext context, WidgetRef ref) {
  final page = ref.read(workspaceProvider).currentPage;
  if (page == null || page.blocks.isEmpty) return;
  final l = context.l10n;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(l.contentSwitchedHint),
        duration: const Duration(seconds: 10),
        showCloseIcon: true,
        action: SnackBarAction(
          label: l.findTextAgain,
          onPressed: () {
            if (context.mounted) ref.read(stepsProvider.notifier).run(ManualStep.detect, DialogBatchUi(context));
          },
        ),
      ),
    );
}

/// The name of a step on its button.
String stepLabel(AppLocalizations l, ManualStep s) => switch (s) {
  ManualStep.detect => l.stepDetect,
  ManualStep.recognize => l.stepRecognize,
  ManualStep.translate => l.stepTranslate,
  ManualStep.mask => l.stepMask,
  ManualStep.clean => l.stepClean,
};

/// What a finished step did and how long it took: «Распознано пузырей: 12 —
/// за 3,2 с»; on several pages the average per page, and the steps it had
/// to do first each with its time.
String stepResultLine(BuildContext context, StepResult r) {
  final l = context.l10n;
  final what = switch (r.step) {
    ManualStep.detect => l.stepDoneDetect('${r.count}'),
    ManualStep.recognize => l.stepDoneRecognize('${r.count}'),
    ManualStep.translate => l.stepDoneTranslate('${r.count}'),
    ManualStep.mask => l.stepDoneMask,
    ManualStep.clean => l.stepDoneClean,
  };
  final parts = [
    l.stepDoneTime(what, formatStepTime(context, r.totalMs)),
    if (r.pages > 1) l.stepDonePages('${r.pages}', formatStepTime(context, r.totalMs ~/ r.pages)),
  ];
  var line = parts.join(', ');
  if (r.ms.length > 1) {
    final each = [
      for (final s in ManualStep.values)
        if (r.ms[s] case final ms?) keepTogether('${stepLabel(l, s)} ${formatStepTime(context, ms)}'),
    ];
    line = '$line (${each.join(' · ')})';
  }
  return line;
}
