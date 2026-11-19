/// Settings (original `app/ui/settings/*`, without the account and
/// credits pages). Every change is saved at once.
library;

import 'dart:async';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart'
    show httpRequestSpec, llmPromptSetting, llmStreamSetting, resolveOfflineLevel;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_info.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_state.dart';
import '../../state/memory_need.dart';
import '../../state/settings_reset.dart';
import '../../render/text_renderer.dart' show defaultFontFamily;
import '../common/content_kind_switch.dart';
import '../common/fonts.dart';
import '../shell_full/font_suggest.dart';
import '../common/help_dialog.dart';
import '../common/info_hint.dart';
import '../common/labels.dart';
import '../common/plugin_form.dart';
import '../common/plugin_strings.dart';
import '../common/translator_history_dialog.dart';
import '../shell_full/main_screen.dart' show showInExplorer;
import '../shell_full/prompt_presets.dart';
import 'app_icon_section.dart';
import 'gpu_section.dart';
import 'keys_section.dart';
import 'models_section.dart';
import 'offline_translate_check.dart';
import 'own_server_profiles.dart';
import 'model_prompt.dart';
import 'request_templates.dart';
import 'settings_place.dart';
import 'settings_search.dart';
import 'settings_sets.dart';
import 'translator_test_chat.dart';
import 'usage_section.dart';

enum SettingsSection { general, translator, exchange, ocr, cleaning, text, upscale, export, keys, models, about }

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.initial = SettingsSection.general, this.panel = false});

  final SettingsSection initial;

  /// Shown as a panel beside the page (see `settings_place.dart`), not over
  /// the whole window.
  final bool panel;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late var _section = widget.initial;

  /// Changes after a reset, so every field shows the default again.
  var _resets = 0;

  // The search through the settings.
  final _search = TextEditingController();
  final _searchFocus = FocusNode();

  /// The settings found are shown instead of the section.
  var _results = false;

  /// The panel's search row is open.
  var _panelSearch = false;

  /// What can be found, per section (gathered from the sections built out
  /// of sight); null until gathered for this search.
  Map<SettingsSection, List<SettingUnit>>? _index;
  List<SettingHit> _hits = const [];
  final _hidden = {for (final s in SettingsSection.values) s: GlobalKey()};
  final _shown = GlobalKey();
  final _area = GlobalKey();

  /// The setting just gone to, lit for a moment (in [_area]).
  Rect? _flash;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    // Ctrl+F over the whole window: wherever the focus is (the panel's comes
    // from the window's keys).
    if (!widget.panel) HardwareKeyboard.instance.addHandler(_onKey);
  }

  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || e.logicalKey != LogicalKeyboardKey.keyF) return false;
    final keys = HardwareKeyboard.instance;
    if (!keys.isControlPressed || keys.isShiftPressed || keys.isAltPressed) return false;
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return false;
    _openSearch();
    return true;
  }

  @override
  void dispose() {
    if (!widget.panel) HardwareKeyboard.instance.removeHandler(_onKey);
    _search.dispose();
    _searchFocus.dispose();
    _flashTimer?.cancel();
    super.dispose();
  }

  bool get _searching => _results && _search.text.trim().isNotEmpty;

  Widget _sectionBody(SettingsSection s) => switch (s) {
    SettingsSection.general => const _GeneralSection(),
    SettingsSection.translator => const _TranslatorSection(),
    SettingsSection.exchange => const _ExchangeSection(),
    SettingsSection.ocr => const _OcrSection(),
    SettingsSection.cleaning => const _CleaningSection(),
    SettingsSection.text => const _TextSection(),
    SettingsSection.upscale => const _UpscaleSection(),
    SettingsSection.export => const _ExportSection(),
    SettingsSection.keys => const KeysSection(),
    SettingsSection.models => const ModelsSection(),
    SettingsSection.about => const _AboutSection(),
  };

  void _openSearch() {
    setState(() => _panelSearch = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocus.requestFocus();
      _search.selection = TextSelection(baseOffset: 0, extentOffset: _search.text.length);
      if (_search.text.trim().isNotEmpty) _showResults();
    });
  }

  void _showResults() {
    if (_results) return;
    setState(() {
      _results = true;
      _index = null;
    });
  }

  /// Esc: clears the words; with none, closes the panel's search row.
  void _clearSearch() {
    if (_search.text.isEmpty) {
      setState(() => _panelSearch = false);
      _searchFocus.unfocus();
      return;
    }
    _search.clear();
    setState(() => _results = false);
  }

  /// Gathers what can be found from the sections built out of sight.
  void _gather() {
    if (!mounted || !_searching || _index != null) return;
    final index = <SettingsSection, List<SettingUnit>>{};
    for (final e in _hidden.entries) {
      final context = e.value.currentContext;
      if (context is Element) index[e.key] = collectSettings(context);
    }
    setState(() => _index = index);
  }

  /// Opens the section of [hit] and scrolls to the setting, lit for a moment.
  void _go(SettingHit hit) {
    _searchFocus.unfocus();
    setState(() {
      _section = hit.section;
      _results = false;
      _flash = null;
    });
    if (hit.index >= 0) WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(hit));
  }

  Future<void> _reveal(SettingHit hit) async {
    final context = _shown.currentContext;
    if (!mounted || context is! Element) return;
    final units = collectSettings(context);
    final unit = hit.index < units.length && units[hit.index].label == hit.label
        ? units[hit.index]
        : units.where((u) => u.label == hit.label).firstOrNull;
    if (unit == null) return;
    await Scrollable.ensureVisible(
      unit.element,
      alignment: 0.2,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
    if (!mounted || !unit.element.mounted) return;
    final box = unit.element.renderObject, area = _area.currentContext?.findRenderObject();
    if (box is! RenderBox || area is! RenderBox || !box.attached || !box.hasSize) return;
    setState(() => _flash = box.localToGlobal(Offset.zero, ancestor: area) & box.size);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  Widget _searchField(BuildContext context) {
    final l = context.l10n;
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _clearSearch},
      child: TextField(
        key: const ValueKey('settings-search'),
        controller: _search,
        focusNode: _searchFocus,
        decoration: InputDecoration(
          isDense: true,
          hintText: l.settingsSearchHint,
          hintStyle: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(tooltip: l.settingsSearchClear, icon: const Icon(Icons.close), onPressed: _clearSearch),
        ),
        onChanged: (text) {
          if (text.trim().isEmpty) {
            setState(() => _results = false);
          } else if (!_results) {
            _showResults();
          } else {
            setState(() {});
          }
        },
        onTap: () {
          if (_search.text.trim().isNotEmpty) _showResults();
        },
        // Enter goes to the first setting found; with none, the words stay to be changed.
        onEditingComplete: () {},
        onSubmitted: (_) {
          if (_searching && _hits.isNotEmpty) _go(_hits.first);
        },
      ),
    );
  }

  /// The settings found (and, out of sight, every section built to gather
  /// them).
  Widget _resultsView(BuildContext context, Map<SettingsSection, (IconData, String)> titles) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final index = _index;
    if (index == null) WidgetsBinding.instance.addPostFrameCallback((_) => _gather());
    final stems = queryStems(_search.text);
    _hits = index == null
        ? const []
        : searchSettings(index, {for (final e in titles.entries) e.key: e.value.$2}, _search.text);
    final bold = TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary);
    final shown = _hits.take(100).toList();
    return Stack(
      children: [
        Positioned.fill(
          child: index == null
              ? const SizedBox.shrink()
              : ListView(
                  padding: widget.panel
                      ? const EdgeInsets.fromLTRB(8, 8, 8, 24)
                      : const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Text(
                        _hits.isEmpty ? l.settingsSearchNone : l.settingsSearchCount(_hits.length),
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                    for (final hit in shown)
                      ListTile(
                        key: ValueKey('hit/${hit.section.name}/${hit.index}'),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        leading: Icon(titles[hit.section]!.$1),
                        title: Text.rich(TextSpan(children: highlightSpans(hit.label, stems, bold))),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hit.wholeSection
                                  ? l.settingsSearchSection
                                  : [titles[hit.section]!.$2, ?hit.group].join(' › '),
                              style: theme.textTheme.bodySmall,
                            ),
                            if (hit.snippet case final snippet?)
                              Text.rich(
                                TextSpan(children: highlightSpans(snippetOf(snippet, stems), stems, bold)),
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                          ],
                        ),
                        onTap: () => _go(hit),
                      ),
                  ],
                ),
        ),
        // Every section, built out of sight to gather what can be found.
        Offstage(
          child: TickerMode(
            enabled: false,
            child: SingleChildScrollView(
              child: SizedBox(
                width: 720,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final s in SettingsSection.values) KeyedSubtree(key: _hidden[s], child: _sectionBody(s)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static SettingsPart? _partOf(SettingsSection s) => switch (s) {
    SettingsSection.general => SettingsPart.general,
    SettingsSection.translator => SettingsPart.translator,
    SettingsSection.exchange => SettingsPart.exchange,
    SettingsSection.ocr => SettingsPart.ocr,
    SettingsSection.cleaning => SettingsPart.cleaning,
    SettingsSection.text => SettingsPart.text,
    SettingsSection.upscale => SettingsPart.upscale,
    SettingsSection.export => SettingsPart.export,
    SettingsSection.keys => SettingsPart.keys,
    SettingsSection.models => SettingsPart.models,
    SettingsSection.about => null,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final titles = {
      SettingsSection.general: (Icons.tune, l.settingsGeneral),
      SettingsSection.translator: (Icons.translate, l.settingsTranslator),
      SettingsSection.exchange: (Icons.forum_outlined, l.chatTitle),
      SettingsSection.ocr: (Icons.document_scanner_outlined, l.settingsOcr),
      SettingsSection.cleaning: (Icons.cleaning_services_outlined, l.settingsCleaning),
      SettingsSection.text: (Icons.text_fields, l.settingsText),
      SettingsSection.upscale: (Icons.zoom_out_map, l.settingsUpscale),
      SettingsSection.export: (Icons.save_alt, l.settingsExport),
      SettingsSection.keys: (Icons.keyboard_outlined, l.settingsKeys),
      SettingsSection.models: (Icons.memory, l.settingsModels),
      SettingsSection.about: (Icons.info_outline, l.settingsAbout),
    };
    final locked = ref.watch(settingsProvider.select((s) => s.lockedParts));
    final Widget page = SingleChildScrollView(
      key: ValueKey(_section),
      padding: widget.panel ? const EdgeInsets.fromLTRB(16, 16, 16, 24) : const EdgeInsets.fromLTRB(32, 24, 32, 32),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      titles[_section]!.$2,
                      style: widget.panel ? theme.textTheme.titleLarge : theme.textTheme.headlineSmall,
                    ),
                  ),
                  // Sets and templates leave a locked section alone.
                  if (_partOf(_section) case final part? when part != SettingsPart.models) SectionLockButton(part),
                ],
              ),
              const SizedBox(height: 16),
              KeyedSubtree(
                key: _shown,
                child: KeyedSubtree(key: ValueKey('$_section/$_resets'), child: _sectionBody(_section)),
              ),
              if (_partOf(_section) case final part?)
                _ResetButtons(
                  section: titles[_section]!.$2,
                  part: part,
                  all: _section == SettingsSection.general,
                  onReset: () => setState(() => _resets++),
                ),
            ],
          ),
        ),
      ),
    );
    // The settings found instead of the section while searching; the setting
    // gone to lit for a moment.
    final content = Stack(
      key: _area,
      children: [
        Positioned.fill(child: _searching ? _resultsView(context, titles) : page),
        if (_flash case final flash?)
          Positioned.fromRect(
            rect: flash.inflate(6),
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  border: Border.all(color: theme.colorScheme.primary, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
      ],
    );
    // Ctrl+F: the search (the panel's comes from the window's keys).
    ref.listen(settingsSearchRequestProvider, (_, _) {
      if (widget.panel) _openSearch();
    });
    if (widget.panel) {
      // Narrow: the sections as icons, the names in tooltips.
      return Material(
        color: theme.colorScheme.surface,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
              child: Row(
                children: [
                  const Icon(Icons.settings_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l.settings, style: theme.textTheme.titleMedium)),
                  IconButton(
                    tooltip: l.settingsSearchOpen,
                    isSelected: _panelSearch,
                    onPressed: () {
                      if (_panelSearch) {
                        _search.clear();
                        setState(() {
                          _panelSearch = false;
                          _results = false;
                        });
                      } else {
                        _openSearch();
                      }
                    },
                    icon: const Icon(Icons.search),
                  ),
                  IconButton(
                    tooltip: l.settingsFullWindow,
                    onPressed: () => switchSettingsView(context, ref, toPanel: false, section: _section),
                    icon: const Icon(Icons.open_in_full),
                  ),
                  IconButton(
                    tooltip: l.close,
                    onPressed: () => ref.read(settingsPanelProvider.notifier).close(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (_panelSearch) Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: _searchField(context)),
            const Divider(height: 1),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 52,
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      children: [
                        for (final e in titles.entries)
                          IconButton(
                            tooltip: e.value.$2,
                            isSelected: e.key == _section && !_searching,
                            style: IconButton.styleFrom(
                              backgroundColor: e.key == _section && !_searching
                                  ? theme.colorScheme.secondaryContainer
                                  : null,
                            ),
                            onPressed: () => setState(() {
                              _section = e.key;
                              _results = false;
                            }),
                            icon: Icon(e.value.$1),
                          ),
                      ],
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: content),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l.settings),
        actions: [
          IconButton(
            tooltip: l.settingsAsPanel,
            onPressed: () => switchSettingsView(context, ref, toPanel: true, section: _section),
            icon: const Icon(Icons.vertical_split_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          SizedBox(
            width: 270,
            child: Column(
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 0), child: _searchField(context)),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      for (final e in titles.entries)
                        ListTile(
                          leading: Icon(e.value.$1),
                          title: Text(e.value.$2),
                          trailing: locked.contains(_partOf(e.key)?.name)
                              ? Tooltip(message: l.sectionLocked, child: const Icon(Icons.lock, size: 16))
                              : null,
                          selected: e.key == _section && !_searching,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onTap: () => setState(() {
                            _section = e.key;
                            _results = false;
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: content),
        ],
      ),
    );
  }
}

// Small building blocks.

/// "Reset this section" (and, in General, "Reset all settings"), asking
/// first.
class _ResetButtons extends ConsumerWidget {
  const _ResetButtons({required this.section, required this.part, required this.all, required this.onReset});

  final String section;
  final SettingsPart part;
  final bool all;
  final VoidCallback onReset;

  Future<void> _reset(BuildContext context, WidgetRef ref, {required bool everything}) async {
    final l = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.restart_alt),
        title: Text(l.settingsResetTitle),
        content: Text(everything ? l.settingsResetAllBody : l.settingsResetBody(section)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.reset)),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    final registry = ref.read(servicesProvider).registry;
    // Saved in the background, as every other change here.
    ref.read(settingsProvider.notifier).change((s) => resetSettings(s, registry, part: everything ? null : part));
    ref.read(servicesProvider).appLog.info('settings_reset', {'part': everything ? 'all' : part.name});
    onReset();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.settingsResetDone)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => _reset(context, ref, everything: false),
            icon: const Icon(Icons.restart_alt),
            label: Text(l.settingsReset),
          ),
          if (all)
            OutlinedButton.icon(
              onPressed: () => _reset(context, ref, everything: true),
              icon: const Icon(Icons.settings_backup_restore),
              label: Text(l.settingsResetAll),
            ),
        ],
      ),
    );
  }
}

void _change(WidgetRef ref, void Function(AppSettings s) change) => ref.read(settingsProvider.notifier).change(change);

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[Text(title!, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 8)],
        ...children,
      ],
    ),
  );
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.help,
    this.info,
  });

  final String label;
  final String? help;
  final String? info;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 12), child: withInfo(_field(), info));

  Widget _field() => DropdownButtonFormField<T>(
    initialValue: options.containsKey(value) ? value : null,
    isExpanded: true,
    decoration: InputDecoration(labelText: label, helperText: help, helperMaxLines: 3),
    items: [
      for (final e in options.entries)
        DropdownMenuItem(
          value: e.key,
          child: Text(e.value, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (v) {
      if (v != null) onChanged(v);
    },
  );
}

Future<bool> _confirmAutoBugReportOff(BuildContext context) async {
  final l = context.l10n;
  final off = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.autoBugReportOffTitle),
      content: Text(l.autoBugReportOffText),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l.autoBugReportTurnOff)),
        FilledButton(onPressed: () => Navigator.pop(context, false), child: Text(l.autoBugReportKeepOn)),
      ],
    ),
  );
  return off ?? false;
}

/// "Now: Medium, needs ≈ 3.9 GB of 4.8 GB the networks may take here."
String _levelAutoHelp(AppLocalizations l, PluginRegistry registry, AppSettings s) {
  final budget = deviceMemoryBudgetMb();
  final level = s.activeReadLevel;
  final name = switch (level) {
    ReadLevel.simple => l.readLevelSimple,
    ReadLevel.medium => l.readLevelMedium,
    ReadLevel.high => l.readLevelHigh,
    ReadLevel.ultra => l.readLevelUltra,
  };
  final need = formatMb(levelMemoryMb(registry, s, level));
  return budget == null ? l.levelAutoHelpUnknown(name, need) : l.levelAutoHelp(name, need, formatMb(budget));
}

Widget _switch(String title, bool value, ValueChanged<bool> onChanged, {String? help, String? info}) => SwitchListTile(
  contentPadding: EdgeInsets.zero,
  title: titleWithInfo(title, info),
  subtitle: help == null ? null : Text(help),
  value: value,
  onChanged: onChanged,
);

Widget _number(String key, String label, num value, ValueChanged<num> onChanged, {String? info}) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: withInfo(
    DebouncedTextField(
      key: ValueKey(key),
      value: '$value',
      label: label,
      numeric: true,
      onChanged: (v) {
        final n = num.tryParse(v.replaceAll(',', '.'));
        if (n != null) onChanged(n);
      },
    ),
    info,
  ),
);

/// Plugin picker with privacy badges and descriptions.
class _PluginPicker extends ConsumerWidget {
  const _PluginPicker({required this.label, required this.kind, required this.value, required this.onChanged});

  final String label;
  final PluginKind kind;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    final settings = ref.watch(settingsProvider);
    final plugins = services.registry.available(
      kind,
      platform: PlatformId.fromOperatingSystem(Platform.operatingSystem),
    );
    PluginInfo? selected;
    for (final p in plugins) {
      if (p.id == value) selected = p;
    }
    final endpoint = selected?.endpointFor(PluginConfig.resolve(selected.settings, settings.pluginValues(selected.id)));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: selected?.id,
            isExpanded: true,
            decoration: InputDecoration(labelText: label),
            items: [
              for (final p in plugins)
                DropdownMenuItem(
                  value: p.id,
                  child: Row(
                    children: [
                      Expanded(child: Text(pluginName(context, p), overflow: TextOverflow.ellipsis)),
                      // Where this plugin's own settings send data: a
                      // server on this computer is not the internet.
                      PrivacyBadge(
                        p.endpointFor(PluginConfig.resolve(p.settings, settings.pluginValues(p.id)))?.privacy ??
                            Privacy.local,
                      ),
                    ],
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
          if (selected != null) ...[
            const SizedBox(height: 6),
            Text(pluginDescription(context, selected), style: Theme.of(context).textTheme.bodySmall),
            if (endpoint != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.warning_amber, size: 16, color: Theme.of(context).colorScheme.tertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      endpoint.host.isEmpty
                          ? context.l10n.sendsDataNoAddress
                          : context.l10n.sendsDataWarning(endpoint.host),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// Sections.

class _GeneralSection extends ConsumerWidget {
  const _GeneralSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final services = ref.watch(servicesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          children: [
            _Dropdown(
              label: l.uiLanguage,
              value: s.uiLanguage == 'en' ? 'en' : 'ru',
              options: const {'ru': 'Русский', 'en': 'English'},
              onChanged: (v) => _change(ref, (s) => s.uiLanguage = v),
            ),
            _Dropdown(
              label: l.theme,
              value: s.theme,
              options: {'system': l.themeSystem, 'light': l.themeLight, 'dark': l.themeDark},
              onChanged: (v) => _change(ref, (s) => s.theme = v),
            ),
            _Dropdown(
              label: l.settingsView,
              value: s.settingsView,
              options: {'full': l.settingsViewFull, 'panel': l.settingsViewPanel, 'last': l.settingsViewLast},
              help: l.settingsViewHelp,
              onChanged: (v) => _change(ref, (s) => s.settingsView = v),
            ),
            const GpuSwitch(),
          ],
        ),
        const SettingsSetsGroup(),
        if (Platform.isWindows) SettingsGroup(title: l.appIcon, children: const [AppIconChoice()]),
        SettingsGroup(
          title: l.settingsProjects,
          children: [
            _switch(
              l.projectAutosave,
              s.projectAutosave,
              (v) => _change(ref, (s) => s.projectAutosave = v),
              help: l.projectAutosaveHelp,
            ),
          ],
        ),
        SettingsGroup(
          title: l.testMode,
          children: [
            _switch(
              l.testMode,
              s.testMode,
              (v) => _change(ref, (s) => s.testMode = v),
              help: l.testModeHelp,
              info: l.testModeInfo,
            ),
            _switch(l.autoBugReport, s.autoBugReport, (v) async {
              // An important safety net: switching it off asks first.
              if (!v && !await _confirmAutoBugReportOff(context)) return;
              _change(ref, (s) => s.autoBugReport = v);
            }, help: l.autoBugReportHelp),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => showInExplorer(services.paths.logs.path),
                  icon: const Icon(Icons.folder_outlined),
                  label: Text(l.openLogs),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final zip = await services.buildBugReport();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l.bugReportDone(zip.path)),
                          action: SnackBarAction(label: l.showInFolder, onPressed: () => showInExplorer(zip.path)),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.bug_report_outlined),
                  label: Text(l.bugReport),
                ),
              ],
            ),
            const SizedBox(height: 4),
            titleWithInfo(l.bugReportHelp, l.bugReportInfo, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(child: Text(l.reportsPrivacyNote, style: Theme.of(context).textTheme.bodySmall)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _TranslatorSection extends ConsumerWidget {
  const _TranslatorSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final services = ref.watch(servicesProvider);
    final info = services.registry.contains(s.translator) ? services.registry.info(s.translator) : null;
    final storageId = s.pluginStorageId(s.translator);
    final template = s.requestTemplateFor(storageId);
    final config = info == null ? null : PluginConfig.resolve(info.settings, s.pluginValues(info.id));
    final hasCustomChat = config != null && httpRequestSpec(config, HttpOperation.chat) != null;
    final keyStatus = info?.keyStatus?.call(config!);
    final apiKeyField = info?.field('api_key');
    final keyScope = (
      storageId,
      apiKeyField is SecretSetting ? s.pluginSettingSecretKey(s.translator, apiKeyField) : null,
      ref.watch(credentialRevisionProvider),
      config?.values['api_url'],
      keyStatus?.host,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          children: [
            _PluginPicker(
              label: l.translator,
              kind: PluginKind.translator,
              value: s.translator,
              onChanged: (v) => _change(ref, (s) => s.translator = v),
            ),
            if (info?.id == 'openai_compatible') OwnServerProfiles(info!),
            if (info?.id == 'openai_compatible' || info?.id == 'openrouter') RequestTemplates(storageId: storageId),
            if (info != null)
              PluginSettingsForm(
                info,
                key: ValueKey(storageId),
                hiddenFields: {
                  RequestTemplate.keyStatusPathKey,
                  RequestTemplate.keyStatusFieldsKey,
                  RequestTemplate.httpSettingKey,
                  llmPromptSetting.key,
                  llmStreamSetting.key,
                  ...?template?.overrides.keys,
                },
              ),
            if (info?.field(llmStreamSetting.key) != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l.translatorStream),
                subtitle: Text(hasCustomChat ? l.translatorStreamTemplateHelp : l.translatorStreamHelp),
                value: config!.value<bool>(llmStreamSetting.key),
                onChanged: hasCustomChat
                    ? null
                    : (value) => _change(ref, (s) {
                        s.plugins[storageId] = {...?s.plugins[storageId], llmStreamSetting.key: value};
                      }),
              ),
            if (info != null && const {'openai_compatible', 'openrouter'}.contains(info.id))
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => showTranslatorTestChat(
                    context,
                    info,
                    info.endpoint?.call(config!).host ?? '',
                    config!.value<String>('model'),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(l.translatorTestChat),
                ),
              ),
            if (info?.id == 'opus_mt' && config!.value<String>('level') == 'auto')
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l.offlineAutoNow(optionLabel(context, info!, info.field('level')!, resolveOfflineLevel('auto'), '')),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            if (info?.id == 'opus_mt')
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => showOfflineTranslateCheck(context),
                  icon: const Icon(Icons.translate),
                  label: Text(l.offlineCheck),
                ),
              ),
            if (info?.field(llmPromptSetting.key) != null) ModelPromptButton(pluginId: info!.id, storageId: storageId),
            if (info != null && info.privacy.sendsData && info.field('model') != null)
              PriceHint(info.id, '${s.pluginValues(info.id)['model'] ?? ''}'),
            if (info != null && keyStatus != null)
              KeyStatusPanel(
                info,
                preview: keyStatus,
                scope: keyScope,
                key: ValueKey((
                  keyScope,
                  config?.values[RequestTemplate.keyStatusPathKey],
                  config?.values[RequestTemplate.keyStatusFieldsKey],
                  template?.http[HttpOperation.keyStatus]?.request,
                  template?.http[HttpOperation.keyStatus]?.response,
                )),
              ),
          ],
        ),
        SettingsGroup(
          children: [
            withInfo(
              DebouncedTextField(
                key: const ValueKey('extra_context'),
                value: s.extraContext,
                label: l.extraContext,
                help: l.extraContextHelp,
                multiline: true,
                onChanged: (v) => _change(ref, (s) => s.extraContext = v),
              ),
              l.extraContextInfo,
            ),
            const SizedBox(height: 8),
            _switch(
              l.sendPageImage,
              s.sendPageImage,
              (v) => _change(ref, (s) => s.sendPageImage = v),
              help: l.sendPageImageHelp,
              info: l.sendPageImageInfo,
            ),
            const SizedBox(height: 8),
            _Dropdown(
              // A choice remembered in the question shows here.
              key: ValueKey('empty_frames.${s.emptyFrames.name}'),
              label: l.emptyFrames,
              value: s.emptyFrames,
              options: {
                EmptyFrames.ask: l.emptyFramesAsk,
                EmptyFrames.read: l.emptyFramesAlwaysRead,
                EmptyFrames.skip: l.emptyFramesAlwaysSkip,
              },
              help: l.emptyFramesHelp,
              onChanged: (v) => _change(ref, (s) => s.emptyFrames = v),
            ),
          ],
        ),
        SettingsGroup(
          title: l.dictTitle,
          children: [
            _switch(
              l.dictShowEnglish,
              s.dictShowEnglish,
              (v) => _change(ref, (s) => s.dictShowEnglish = v),
              help: l.dictShowEnglishHelp,
              info: l.dictInfo,
            ),
          ],
        ),
        SettingsGroup(
          title: l.usageTitle,
          children: [
            const UsagePanel(),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => showTranslatorHistory(context),
                icon: const Icon(Icons.history),
                label: Text(l.historyOpen),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: l.approvals,
          children: [
            if (s.approvedNetworkPlugins.isEmpty) Text(l.approvalsNone, style: Theme.of(context).textTheme.bodySmall),
            for (final key in s.approvedNetworkPlugins.toList()..sort())
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_done_outlined),
                title: Text(key.split('@').last),
                subtitle: Text(key.split('@').first),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InfoHint(l.revokeNetworkInfo),
                    TextButton(
                      onPressed: () => _change(ref, (s) => s.approvedNetworkPlugins.remove(key)),
                      child: Text(l.revoke),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (info?.id == 'openai_compatible')
          SettingsGroup(
            children: [
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                title: Text(l.ownServerSetupGuideTitle),
                children: [
                  SelectableText(l.ownServerSetupGuide),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: l.ownServerSetupGuide));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.ownServerGuideCopied)));
                      }
                    },
                    icon: const Icon(Icons.copy_outlined),
                    label: Text(l.ownServerCopyGuide),
                  ),
                  TextButton.icon(
                    onPressed: () => showHelp(context, HelpTopic.ownServer),
                    icon: const Icon(Icons.description_outlined),
                    label: Text(l.ownServerAiGuide),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}

class _OcrSection extends ConsumerWidget {
  const _OcrSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final services = ref.watch(servicesProvider);
    Widget pluginWithForm(String label, PluginKind kind, String value, void Function(AppSettings s, String v) apply) {
      final info = services.registry.contains(value) ? services.registry.info(value) : null;
      final ownOcr = info?.id == 'openai_compatible_ocr';
      final profile = s.ownServerOcrProfile;
      final connection = services.registry.contains('openai_compatible')
          ? services.registry.info('openai_compatible')
          : null;
      return SettingsGroup(
        children: [
          _PluginPicker(label: label, kind: kind, value: value, onChanged: (v) => _change(ref, (s) => apply(s, v))),
          if (ownOcr && connection != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OwnServerProfiles(connection, forOcr: true),
                  const SizedBox(height: 4),
                  Text(l.ownServerOcrConnectionHelp, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          if (ownOcr &&
              connection != null &&
              profile != null &&
              (profile.isEmpty || s.ownServerNames.containsKey(profile)))
            _SharedOcrConnection(connection, AppSettings.ownServerStorageId(profile)),
          if (info != null && info.settings.isNotEmpty)
            PluginSettingsForm(
              info,
              key: ValueKey((info.id, ownOcr ? profile : null)),
              hiddenFields: {
                RequestTemplate.httpSettingKey,
                llmPromptSetting.key,
                if (ownOcr && profile != null) ...{'api_url', 'api_key', 'chat_path', 'models_path'},
              },
            ),
          if (info?.field(llmPromptSetting.key) != null)
            ModelPromptButton(pluginId: info!.id, storageId: info.id, reader: true),
          if (info != null && info.privacy.sendsData && info.field('model') != null)
            PriceHint(info.id, '${s.pluginValues(info.id)['model'] ?? ''}'),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          title: l.contentKind,
          children: [
            const Align(alignment: Alignment.centerLeft, child: ContentKindSwitch()),
            const SizedBox(height: 4),
            Text(l.contentKindInfo, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        pluginWithForm(l.ocr, PluginKind.ocr, s.ocr, (s, v) => s.ocr = v),
        if (s.contentKind == ContentKind.screens)
          pluginWithForm(l.detectorScreens, PluginKind.detector, s.screenDetector, (s, v) => s.screenDetector = v)
        else
          pluginWithForm(l.detector, PluginKind.detector, s.detector, (s, v) => s.detector = v),
        SettingsGroup(
          children: [
            if (leveledOcrIds.contains(s.ocr))
              _Dropdown<ReadLevel>(
                label: s.contentKind == ContentKind.screens ? l.readLevelScreens : l.readLevel,
                value: s.activeReadLevel,
                options: {
                  ReadLevel.simple: l.readLevelSimple,
                  ReadLevel.medium: l.readLevelMedium,
                  for (final level in const [ReadLevel.high, ReadLevel.ultra])
                    if (s.activeReadLevel == level || services.registry.contains(vlmReaderId))
                      level: level == ReadLevel.high ? l.readLevelHigh : l.readLevelUltra,
                },
                onChanged: (v) => _change(ref, (s) {
                  s.levelAuto = false;
                  s.contentKind == ContentKind.screens ? s.screenReadLevel = v : s.readLevel = v;
                }),
                info: l.readLevelInfo,
              ),
            if (leveledOcrIds.contains(s.ocr))
              _switch(
                l.levelAuto,
                s.levelAuto,
                (v) async {
                  await ref.read(settingsProvider.notifier).change((s) => s.levelAuto = v);
                  if (v) {
                    await applyAutoLevel(
                      ref.read(settingsProvider),
                      ref.read(settingsProvider.notifier).change,
                      services.registry,
                    );
                  }
                },
                help: _levelAutoHelp(l, services.registry, s),
                info: l.levelAutoInfo,
              ),
            withInfo(
              _PluginPicker(
                label: s.contentKind == ContentKind.screens ? l.textPrepScreens : l.textPrep,
                kind: PluginKind.textPrep,
                value: s.activeTextPrep,
                onChanged: (v) =>
                    _change(ref, (s) => s.contentKind == ContentKind.screens ? s.screenTextPrep = v : s.textPrep = v),
              ),
              l.textPrepInfo,
            ),
            if (!const {textPrepOffId, plainX15Id, plainX2Id}.contains(s.activeTextPrep))
              _Dropdown<int>(
                label: l.textPrepSeconds,
                value: s.textPrepSeconds,
                options: {
                  30: l.secondsShort('30'),
                  60: l.textPrepSecondsDefault,
                  120: l.minutesShort('2'),
                  300: l.minutesShort('5'),
                  600: l.minutesShort('10'),
                  0: l.noTimeLimit,
                },
                onChanged: (v) => _change(ref, (s) => s.textPrepSeconds = v),
                info: l.textPrepSecondsInfo,
              ),
            _switch(
              l.fixCyrillic,
              s.fixCyrillicLookalikes,
              (v) => _change(ref, (s) => s.fixCyrillicLookalikes = v),
              help: l.fixCyrillicHelp,
            ),
            _switch(
              l.splitGluedWords,
              s.splitGluedWords,
              (v) => _change(ref, (s) => s.splitGluedWords = v),
              info: l.splitGluedWordsInfo,
            ),
            if (s.contentKind == ContentKind.comics)
              _switch(l.checkLines, s.checkLines, (v) => _change(ref, (s) => s.checkLines = v), info: l.checkLinesInfo),
          ],
        ),
      ],
    );
  }
}

class _SharedOcrConnection extends ConsumerWidget {
  const _SharedOcrConnection(this.info, this.storageId);

  final PluginInfo info;
  final String storageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final template = s.requestTemplateFor(storageId);
    final visible = {
      'api_url',
      'api_key',
      if (template?.chatPath.isNotEmpty != true && template?.http[HttpOperation.chat] == null) 'chat_path',
      if (template?.modelsPath.isNotEmpty != true && template?.http[HttpOperation.models] == null) 'models_path',
    };
    return ExpansionTile(
      key: ValueKey(storageId),
      tilePadding: EdgeInsets.zero,
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      title: Text(l.ownServerOcrSharedSettings),
      subtitle: Text(l.ownServerOcrSharedSettingsHelp),
      children: [
        RequestTemplates(storageId: storageId, forOcr: true),
        PluginSettingsForm(
          info,
          ownServerStorageId: storageId,
          hiddenFields: {
            for (final field in info.settings)
              if (!visible.contains(field.key)) field.key,
          },
        ),
      ],
    );
  }
}

class _CleaningSection extends ConsumerWidget {
  const _CleaningSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final inpaint = s.inpaint;
    InpaintConfig withInpaint({HdStrategy? strategy, int? resizeLimit, int? cropMargin, int? cropTriggerSize}) =>
        InpaintConfig(
          strategy: strategy ?? inpaint.strategy,
          resizeLimit: resizeLimit ?? inpaint.resizeLimit,
          cropMargin: cropMargin ?? inpaint.cropMargin,
          cropTriggerSize: cropTriggerSize ?? inpaint.cropTriggerSize,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          title: l.inpainter,
          children: [
            _Dropdown<CleanLevel?>(
              label: l.cleanLevel,
              value: CleanLevel.of(s),
              options: {
                CleanLevel.simple: l.cleanLevelSimple,
                CleanLevel.medium: l.cleanLevelMedium,
                CleanLevel.high: l.cleanLevelHigh,
                if (CleanLevel.of(s) == null) null: l.cleanLevelCustom,
              },
              onChanged: (v) {
                if (v != null) _change(ref, v.applyTo);
              },
              info: l.cleanLevelInfo,
            ),
            if (s.textMask.isNotEmpty)
              _switch(
                l.colourLetters,
                s.colourLetters,
                (v) => _change(ref, (s) => s.colourLetters = v),
                info: l.colourLettersInfo,
              ),
          ],
        ),
        SettingsGroup(
          title: l.hdStrategy,
          children: [
            _Dropdown(
              label: l.hdStrategyField,
              info: l.hdStrategyInfo,
              value: inpaint.strategy,
              options: {HdStrategy.resize: l.hdResize, HdStrategy.crop: l.hdCrop, HdStrategy.original: l.hdOriginal},
              onChanged: (v) => _change(ref, (s) => s.inpaint = withInpaint(strategy: v)),
            ),
            if (inpaint.strategy == HdStrategy.resize)
              _number(
                'resize_limit',
                l.resizeLimit,
                inpaint.resizeLimit,
                (v) => _change(ref, (s) => s.inpaint = withInpaint(resizeLimit: v.toInt().clamp(256, 8192))),
                info: l.resizeLimitInfo,
              ),
            if (inpaint.strategy == HdStrategy.crop) ...[
              _number(
                'crop_margin',
                l.cropMargin,
                inpaint.cropMargin,
                (v) => _change(ref, (s) => s.inpaint = withInpaint(cropMargin: v.toInt().clamp(0, 4096))),
                info: l.cropMarginInfo,
              ),
              _number(
                'crop_trigger',
                l.cropTrigger,
                inpaint.cropTriggerSize,
                (v) => _change(ref, (s) => s.inpaint = withInpaint(cropTriggerSize: v.toInt().clamp(64, 8192))),
                info: l.cropTriggerInfo,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _TextSection extends ConsumerWidget {
  const _TextSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final r = ref.watch(settingsProvider.select((s) => s.render));
    void set(RenderSettings Function(RenderSettings r) f) => _change(ref, (s) => s.render = f(s.render));
    final added = ref.watch(addedFontsProvider);
    final choices = [...availableFonts().skip(1), ...added];
    final font = r.fontFamily == defaultFontFamily ? '' : r.fontFamily;
    // A family typed by hand in older versions stays in the list.
    if (font.isNotEmpty && !choices.contains(font)) choices.add(font);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          children: [
            _Dropdown(
              label: l.font,
              value: font,
              options: {'': l.fontDefault, for (final f in choices) f: fontLabel(f)},
              onChanged: (v) => set((r) => r.copyWith(fontFamily: v)),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.font_download_outlined),
                    label: Text(l.fontAdd),
                    onPressed: () async {
                      final files = await openFiles(
                        acceptedTypeGroups: [const XTypeGroup(label: 'Fonts', extensions: fontExtensions)],
                      );
                      if (files.isEmpty) return;
                      final fonts = await ref.read(addedFontsProvider.notifier).add([for (final f in files) f.path]);
                      if (context.mounted && fonts.isNotEmpty) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(l.fontsAdded('${fonts.length}'))));
                      }
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: Text(l.fontSuggest),
                    onPressed: () => showFontSuggestions(context, ref),
                  ),
                  for (final f in added)
                    InputChip(
                      label: Text(fontLabel(f)),
                      onDeleted: () => ref.read(addedFontsProvider.notifier).remove(f),
                      deleteButtonTooltipMessage: l.fontRemove,
                    ),
                ],
              ),
            ),
            Text(l.fontAddHelp, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _number(
                    'min_font',
                    l.minFontSize,
                    r.minFontSize,
                    (v) => set((r) => r.copyWith(minFontSize: v.toInt().clamp(4, r.maxFontSize))),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _number(
                    'max_font',
                    l.maxFontSize,
                    r.maxFontSize,
                    (v) => set((r) => r.copyWith(maxFontSize: v.toInt().clamp(r.minFontSize, 200))),
                    info: l.fontSizeInfo,
                  ),
                ),
              ],
            ),
            _number(
              'line_spacing',
              l.lineSpacing,
              r.lineSpacing,
              (v) => set((r) => r.copyWith(lineSpacing: v.toDouble().clamp(0.5, 3.0))),
              info: l.lineSpacingInfo,
            ),
            _ColorRow(
              label: l.textColor,
              value: r.color,
              onChanged: (c) => set((r) => r.copyWith(color: c)),
            ),
            _Dropdown(
              label: l.alignment,
              value: r.alignment,
              options: {
                TextAlignment.left: l.alignLeft,
                TextAlignment.center: l.alignCenter,
                TextAlignment.right: l.alignRight,
              },
              onChanged: (v) => set((r) => r.copyWith(alignment: v)),
            ),
            _switch(l.placeInBlock, r.placeInBlock, (v) => set((r) => r.copyWith(placeInBlock: v))),
            _Dropdown(
              label: l.textCase,
              value: r.textCase,
              options: {
                TextCase.source: l.textCaseSource,
                TextCase.upper: l.textCaseUpper,
                TextCase.normal: l.textCaseNormal,
              },
              onChanged: (v) => set((r) => r.copyWith(textCase: v)),
              info: l.textCaseInfo,
            ),
            _switch(
              l.matchSource,
              r.matchSource,
              (v) => set((r) => r.copyWith(matchSource: v)),
              info: l.matchSourceInfo,
            ),
            _switch(l.hyphenate, r.hyphenate, (v) => set((r) => r.copyWith(hyphenate: v)), info: l.hyphenateInfo),
            _switch(l.shapeFit, r.shapeFit, (v) => set((r) => r.copyWith(shapeFit: v)), info: l.shapeFitInfo),
            _switch(l.bold, r.bold, (v) => set((r) => r.copyWith(bold: v))),
            _switch(l.italic, r.italic, (v) => set((r) => r.copyWith(italic: v))),
            _switch(l.underline, r.underline, (v) => set((r) => r.copyWith(underline: v))),
          ],
        ),
        SettingsGroup(
          title: l.outline,
          children: [
            _switch(l.outline, r.outline, (v) => set((r) => r.copyWith(outline: v))),
            if (r.outline) ...[
              _ColorRow(
                label: l.outlineColor,
                value: r.outlineColor,
                onChanged: (c) => set((r) => r.copyWith(outlineColor: c)),
              ),
              _number(
                'outline_width',
                l.outlineWidth,
                r.outlineWidth,
                (v) => set((r) => r.copyWith(outlineWidth: v.toDouble().clamp(0.0, 10.0))),
                info: l.outlineWidthInfo,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Colour presets for text and outline.
class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.label, required this.value, required this.onChanged});

  static const presets = [
    0xFF000000, 0xFFFFFFFF, 0xFF424242, 0xFF9E9E9E, 0xFFD32F2F, 0xFFF57C00, //
    0xFFFBC02D, 0xFF388E3C, 0xFF1976D2, 0xFF7B1FA2,
  ];

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(width: 160, child: Text(label)),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in presets)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onChanged(c),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: c == value ? scheme.primary : scheme.outlineVariant,
                          width: c == value ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpscaleSection extends ConsumerWidget {
  const _UpscaleSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final u = ref.watch(settingsProvider.select((s) => s.upscale));
    void set(UpscaleSettings Function(UpscaleSettings u) f) => _change(ref, (s) => s.upscale = f(s.upscale));
    return SettingsGroup(
      children: [
        Text(l.upscaleHelp, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        _Dropdown(
          label: l.upscaleMode,
          value: u.mode,
          options: {
            UpscaleMode.auto: l.upscaleAuto,
            UpscaleMode.off: l.upscaleOff,
            UpscaleMode.x2: '×2',
            UpscaleMode.x3: '×3',
            UpscaleMode.x4: '×4',
            UpscaleMode.width: l.upscaleWidth,
          },
          onChanged: (v) => set((u) => u.copyWith(mode: v)),
        ),
        if (u.mode == UpscaleMode.width)
          _number(
            'upscale_width',
            l.upscaleWidthValue,
            u.targetWidth,
            (v) => set((u) => u.copyWith(targetWidth: v.toInt().clamp(256, 8192))),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            initialValue: 'fast',
            decoration: InputDecoration(labelText: l.upscaleMethod),
            items: [
              DropdownMenuItem(value: 'fast', child: Text(l.upscaleFast)),
              DropdownMenuItem(value: 'good', enabled: false, child: Text(l.upscaleGood)),
              DropdownMenuItem(value: 'best', enabled: false, child: Text(l.upscaleBest)),
            ],
            onChanged: (_) {},
          ),
        ),
      ],
    );
  }
}

class _ExportSection extends ConsumerWidget {
  const _ExportSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final e = ref.watch(settingsProvider.select((s) => s.export));
    void set(ExportSettings Function(ExportSettings e) f) => _change(ref, (s) => s.export = f(s.export));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          children: [
            _Dropdown(
              label: l.imageFormat,
              info: l.imageFormatInfo,
              value: e.imageFormat,
              options: {'source': l.formatSource, 'png': 'PNG', 'jpg': 'JPG', 'webp': 'WEBP', 'psd': l.formatPsd},
              onChanged: (v) => set((e) => e.copyWith(imageFormat: v)),
            ),
          ],
        ),
        SettingsGroup(
          title: l.autoExport,
          children: [
            Text(l.autoExportHelp, style: Theme.of(context).textTheme.bodySmall),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.exportRawText),
              value: e.rawText,
              onChanged: (v) => set((e) => e.copyWith(rawText: v)),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.exportTranslatedText),
              value: e.translatedText,
              onChanged: (v) => set((e) => e.copyWith(translatedText: v)),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.exportCleaned),
              value: e.cleanedImage,
              onChanged: (v) => set((e) => e.copyWith(cleanedImage: v)),
            ),
          ],
        ),
      ],
    );
  }
}

/// The exchange with a chat AI by hand.
/// A style of translation the user wrote: its name, what to ask, on or off.
class _OwnStyle extends StatelessWidget {
  const _OwnStyle({
    super.key,
    required this.style,
    required this.active,
    required this.onChanged,
    required this.onActive,
    required this.onDelete,
  });

  final PromptStyle style;
  final bool active;
  final ValueChanged<PromptStyle> onChanged;
  final ValueChanged<bool> onActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Switch(value: active, onChanged: onActive),
          const SizedBox(width: 8),
          SizedBox(
            width: 180,
            child: DebouncedTextField(
              value: style.name,
              label: l.chatOwnStyleName,
              onChanged: (v) => onChanged(PromptStyle(style.id, style.text, name: v)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DebouncedTextField(
              value: style.text,
              label: l.chatOwnStyleText,
              hint: 'Keep it short and punchy.',
              onChanged: (v) => onChanged(PromptStyle(style.id, v, name: style.name)),
            ),
          ),
          IconButton(tooltip: l.chatOwnStyleDelete, onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
        ],
      ),
    );
  }
}

class _ExchangeSection extends ConsumerStatefulWidget {
  const _ExchangeSection();

  @override
  ConsumerState<_ExchangeSection> createState() => _ExchangeSectionState();
}

class _ExchangeSectionState extends ConsumerState<_ExchangeSection> {
  /// Changes when an instruction goes back to the built-in one.
  var _promptResets = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final e = ref.watch(settingsProvider.select((s) => s.exchange));
    void set(ExchangeSettings Function(ExchangeSettings e) f) => _change(ref, (s) => s.exchange = f(s.exchange));
    // The chosen styles with [id] turned on or off.
    List<String> turned(String id, bool on) => [
      for (final a in e.activeStyles)
        if (a != id) a,
      if (on) id,
    ];
    final kinds = {
      ExchangePrompt.both: l.chatModeBoth,
      ExchangePrompt.bothApart: l.chatPromptBothApart,
      ExchangePrompt.recognize: l.chatModeRecognize,
      ExchangePrompt.translate: l.chatModeTranslate,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          children: [
            Text(l.chatSettingsHelp, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => showHelp(context, HelpTopic.exchange),
                icon: const Icon(Icons.help_outline),
                label: Text(l.chatHelpSettings),
              ),
            ),
            const SizedBox(height: 8),
            _switch(l.chatTogether, e.together, (v) => set((e) => e.copyWith(together: v)), help: l.chatTogetherHelp),
            _switch(l.chatApart, e.apart, (v) => set((e) => e.copyWith(apart: v)), help: l.chatApartHelp),
          ],
        ),
        SettingsGroup(
          title: l.chatPicturesTitle,
          children: [
            _Dropdown(
              label: l.chatImages,
              value: e.images,
              options: {
                ExchangeImages.sheets: l.chatImagesSheets,
                ExchangeImages.crops: l.chatImagesCrops,
                ExchangeImages.both: l.chatImagesBoth,
              },
              info: l.chatImagesInfo,
              onChanged: (v) => set((e) => e.copyWith(images: v)),
            ),
            _Dropdown(
              label: l.chatSheets,
              value: e.grouping,
              options: {SheetGrouping.size: l.chatGroupingSize, SheetGrouping.count: l.chatGroupingCount},
              info: l.chatGroupingInfo,
              onChanged: (v) => set((e) => e.copyWith(grouping: v)),
            ),
            if (e.grouping == SheetGrouping.count)
              _number(
                'exchange.per_sheet',
                l.chatPerSheet,
                e.perSheet,
                (v) => set((e) => e.copyWith(perSheet: v.toInt().clamp(1, 200))),
              ),
            _number(
              'exchange.sheet_max_px',
              l.chatSheetSizePx,
              e.sheetMaxPx,
              (v) => set(
                (e) =>
                    e.copyWith(sheetMaxPx: v.toInt().clamp(ExchangeSettings.minSheetPx, ExchangeSettings.maxSheetPx)),
              ),
              info: l.chatSheetSizeInfo,
            ),
            _switch(l.chatSheetPerPage, e.sheetPerPage, (v) => set((e) => e.copyWith(sheetPerPage: v))),
            _Dropdown(
              label: l.chatContextImage,
              value: e.contextImage,
              options: {
                ContextImage.off: l.chatContextOff,
                ContextImage.separate: l.chatContextSeparate,
                ContextImage.onSheet: l.chatContextOnSheet,
              },
              info: l.chatContextInfo,
              onChanged: (v) => set((e) => e.copyWith(contextImage: v)),
            ),
            if (e.images.hasCrops)
              _number(
                'exchange.crops_per_folder',
                l.chatCropsPerFolder,
                e.cropsPerFolder,
                (v) => set((e) => e.copyWith(cropsPerFolder: v.toInt().clamp(1, 1000))),
              ),
          ],
        ),
        SettingsGroup(
          title: l.chatAnswerTitle,
          children: [
            _Dropdown(
              label: l.chatTextFiles,
              value: e.textFiles,
              options: {
                ExchangeTextFiles.all: l.chatTextFilesAll,
                ExchangeTextFiles.pages: l.chatTextFilesPages,
                ExchangeTextFiles.both: l.chatTextFilesBoth,
              },
              info: l.chatTextFilesInfo,
              onChanged: (v) => set((e) => e.copyWith(textFiles: v)),
            ),
            DebouncedTextField(
              key: const ValueKey('exchange.placeholder'),
              value: e.placeholder,
              label: l.chatPlaceholder,
              help: l.chatPlaceholderHelp,
              onChanged: (v) => set((e) => e.copyWith(placeholder: v)),
            ),
            _switch(
              l.chatSplitFiles,
              e.splitFiles,
              (v) => set((e) => e.copyWith(splitFiles: v)),
              help: l.chatSplitFilesHelp,
            ),
            _switch(
              l.chatSharedTexts,
              e.sharedTexts,
              (v) => set((e) => e.copyWith(sharedTexts: v)),
              help: l.chatSharedTextsHelp,
            ),
            _switch(
              l.chatAnswerFromClipboard,
              e.answerFromClipboard,
              (v) => set((e) => e.copyWith(answerFromClipboard: v)),
              help: l.chatAnswerFromClipboardHelp,
            ),
            _switch(l.chatCheckFit, e.checkFit, (v) => set((e) => e.copyWith(checkFit: v)), help: l.chatCheckFitHelp),
            DebouncedTextField(
              key: const ValueKey('exchange.separator'),
              value: e.separator,
              label: l.chatSeparator,
              help: l.chatSeparatorHelp,
              onChanged: (v) =>
                  set((e) => e.copyWith(separator: v.trim().isEmpty ? defaultExchangeSeparator : v.trim())),
            ),
            const SizedBox(height: 12),
            DebouncedTextField(
              key: const ValueKey('exchange.answer_marks'),
              value: e.answerMarks.join(' '),
              label: l.chatAnswerMarks,
              help: l.chatAnswerMarksHelp,
              onChanged: (v) => set((e) => e.copyWith(answerMarks: parseAnswerMarks(v))),
            ),
            if (!listEquals(e.answerMarks, defaultAnswerMarks))
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => set((e) => e.copyWith(answerMarks: defaultAnswerMarks)),
                  child: Text(l.chatAnswerMarksDefault),
                ),
              ),
          ],
        ),
        SettingsGroup(
          title: l.chatStylesTitle,
          children: [
            Text(l.chatStylesHelp, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            for (final style in builtInPromptStyles)
              _switch(
                promptStyleName(l, style),
                e.activeStyles.contains(style.id),
                (v) => set((e) => e.copyWith(activeStyles: turned(style.id, v))),
                help: style.text,
              ),
            for (final (i, style) in e.ownStyles.indexed)
              _OwnStyle(
                key: ValueKey(style.id),
                style: style,
                active: e.activeStyles.contains(style.id),
                onChanged: (s) => set((e) => e.copyWith(ownStyles: [...e.ownStyles]..[i] = s)),
                onActive: (v) => set((e) => e.copyWith(activeStyles: turned(style.id, v))),
                onDelete: () => set(
                  (e) => e.copyWith(ownStyles: [...e.ownStyles]..removeAt(i), activeStyles: turned(style.id, false)),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => set((e) {
                  final taken = {for (final s in e.ownStyles) s.id};
                  var n = 1;
                  while (taken.contains('own_$n')) {
                    n++;
                  }
                  return e.copyWith(ownStyles: [...e.ownStyles, PromptStyle('own_$n', '')]);
                }),
                icon: const Icon(Icons.add),
                label: Text(l.chatOwnStyleAdd),
              ),
            ),
          ],
        ),
        SettingsGroup(
          title: l.chatPromptsTitle,
          children: [
            Text(
              l.chatPromptsHelp('{source}, {target}, {labels}, {lines}, {context}, {pictures}, {kind}, {separator}'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final m in kinds.entries) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PromptPresetPicker(
                    settings: e,
                    kind: m.key,
                    onPick: (text) {
                      set((e) => e.withPrompt(m.key, text));
                      setState(() => _promptResets++);
                    },
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final name = await askPresetName(context, initial: e.activePreset(m.key)?.name ?? '');
                      if (name == null) return;
                      final text = e.promptFor(m.key).isEmpty ? defaultExchangePrompts[m.key]! : e.promptFor(m.key);
                      set((e) => e.withPreset(m.key, PromptPreset(name, text)));
                    },
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: Text(l.chatPresetSave),
                  ),
                  if (e.activePreset(m.key) case final active?)
                    TextButton.icon(
                      onPressed: () => set((e) => e.withoutPreset(m.key, active.name)),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l.chatPresetDelete),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              DebouncedTextField(
                key: ValueKey('exchange.prompt.${m.key.name}.$_promptResets'),
                value: e.promptFor(m.key).isEmpty ? defaultExchangePrompts[m.key]! : e.promptFor(m.key),
                label: m.value,
                multiline: true,
                onChanged: (v) =>
                    set((e) => e.withPrompt(m.key, v.trim() == defaultExchangePrompts[m.key]!.trim() ? '' : v)),
              ),
              if (e.promptFor(m.key).isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      set((e) => e.withPrompt(m.key, ''));
                      setState(() => _promptResets++);
                    },
                    child: Text(l.chatPromptDefault),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ],
    );
  }
}

class _AboutSection extends ConsumerWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final services = ref.watch(servicesProvider);
    final theme = Theme.of(context);
    final sha = AppInfo.gitSha.isEmpty ? '' : ' (${AppInfo.gitSha})';
    return SettingsGroup(
      children: [
        Text(AppInfo.name, style: theme.textTheme.titleLarge),
        Text(l.version('${AppInfo.version}$sha')),
        Text(l.aboutAuthor(AppInfo.author)),
        SelectableText(AppInfo.repository),
        const SizedBox(height: 12),
        Text(l.aboutIndependent),
        const SizedBox(height: 8),
        Text(l.aboutPrivacy),
        const SizedBox(height: 8),
        Text(l.license),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.dataFolder),
          subtitle: SelectableText(services.paths.root.path),
          trailing: TextButton(onPressed: () => showInExplorer(services.paths.root.path), child: Text(l.open)),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: () =>
                showLicensePage(context: context, applicationName: AppInfo.name, applicationVersion: AppInfo.version),
            child: Text(l.thirdPartyLicenses),
          ),
        ),
      ],
    );
  }
}
