/// Settings (original `app/ui/settings/*`, without the account and
/// credits pages). Every change is saved at once.
library;

import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_info.dart';
import '../../state/app_state.dart';
import '../../state/settings_reset.dart';
import '../../render/text_renderer.dart' show defaultFontFamily;
import '../common/content_kind_switch.dart';
import '../common/fonts.dart';
import '../common/info_hint.dart';
import '../common/labels.dart';
import '../common/plugin_form.dart';
import '../common/plugin_strings.dart';
import '../shell_full/main_screen.dart' show showInExplorer;
import 'gpu_section.dart';
import 'keys_section.dart';
import 'models_section.dart';
import 'usage_section.dart';

enum SettingsSection { general, translator, exchange, tools, text, upscale, export, keys, models, about }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.initial = SettingsSection.general});

  final SettingsSection initial;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late var _section = widget.initial;

  /// Changes after a reset, so every field shows the default again.
  var _resets = 0;

  static SettingsPart? _partOf(SettingsSection s) => switch (s) {
    SettingsSection.general => SettingsPart.general,
    SettingsSection.translator => SettingsPart.translator,
    SettingsSection.exchange => SettingsPart.exchange,
    SettingsSection.tools => SettingsPart.tools,
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
    final titles = {
      SettingsSection.general: (Icons.tune, l.settingsGeneral),
      SettingsSection.translator: (Icons.translate, l.settingsTranslator),
      SettingsSection.exchange: (Icons.forum_outlined, l.chatTitle),
      SettingsSection.tools: (Icons.document_scanner_outlined, l.settingsTools),
      SettingsSection.text: (Icons.text_fields, l.settingsText),
      SettingsSection.upscale: (Icons.zoom_out_map, l.settingsUpscale),
      SettingsSection.export: (Icons.save_alt, l.settingsExport),
      SettingsSection.keys: (Icons.keyboard_outlined, l.settingsKeys),
      SettingsSection.models: (Icons.memory, l.settingsModels),
      SettingsSection.about: (Icons.info_outline, l.settingsAbout),
    };
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: Row(
        children: [
          SizedBox(
            width: 250,
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                for (final e in titles.entries)
                  ListTile(
                    leading: Icon(e.value.$1),
                    title: Text(e.value.$2),
                    selected: e.key == _section,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onTap: () => setState(() => _section = e.key),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
              child: Align(
                alignment: Alignment.topLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(titles[_section]!.$2, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      KeyedSubtree(
                        key: ValueKey('$_section/$_resets'),
                        child: switch (_section) {
                          SettingsSection.general => const _GeneralSection(),
                          SettingsSection.translator => const _TranslatorSection(),
                          SettingsSection.exchange => const _ExchangeSection(),
                          SettingsSection.tools => const _ToolsSection(),
                          SettingsSection.text => const _TextSection(),
                          SettingsSection.upscale => const _UpscaleSection(),
                          SettingsSection.export => const _ExportSection(),
                          SettingsSection.keys => const KeysSection(),
                          SettingsSection.models => const ModelsSection(),
                          SettingsSection.about => const _AboutSection(),
                        },
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
            ),
          ),
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
                      PrivacyBadge(p.privacy),
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
                      context.l10n.sendsDataWarning(endpoint.host),
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
            const GpuSwitch(),
          ],
        ),
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
    final keyStatus = info?.keyStatus?.call(PluginConfig.resolve(info.settings, s.pluginValues(info.id)));
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
            if (info != null) PluginSettingsForm(info, key: ValueKey(info.id)),
            if (info != null && keyStatus != null)
              KeyStatusPanel(info, host: keyStatus.host, key: ValueKey('key_status.${info.id}.${keyStatus.host}')),
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
          ],
        ),
        SettingsGroup(title: l.usageTitle, children: const [UsagePanel()]),
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
                trailing: TextButton(
                  onPressed: () => _change(ref, (s) => s.approvedNetworkPlugins.remove(key)),
                  child: Text(l.revoke),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ToolsSection extends ConsumerWidget {
  const _ToolsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.watch(settingsProvider);
    final services = ref.watch(servicesProvider);
    Widget pluginWithForm(String label, PluginKind kind, String value, void Function(AppSettings s, String v) apply) {
      final info = services.registry.contains(value) ? services.registry.info(value) : null;
      return SettingsGroup(
        children: [
          _PluginPicker(label: label, kind: kind, value: value, onChanged: (v) => _change(ref, (s) => apply(s, v))),
          if (info != null && info.settings.isNotEmpty) PluginSettingsForm(info, key: ValueKey(info.id)),
        ],
      );
    }

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
          title: l.contentKind,
          children: [
            const Align(alignment: Alignment.centerLeft, child: ContentKindSwitch()),
            const SizedBox(height: 4),
            Text(l.contentKindInfo, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        if (s.contentKind == ContentKind.screens)
          pluginWithForm(l.detectorScreens, PluginKind.detector, s.screenDetector, (s, v) => s.screenDetector = v)
        else
          pluginWithForm(l.detector, PluginKind.detector, s.detector, (s, v) => s.detector = v),
        pluginWithForm(l.ocr, PluginKind.ocr, s.ocr, (s, v) => s.ocr = v),
        SettingsGroup(
          children: [
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
        pluginWithForm(l.inpainter, PluginKind.inpainter, s.inpainter, (s, v) => s.inpainter = v),
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
            _switch(l.upperCase, r.upperCase, (v) => set((r) => r.copyWith(upperCase: v))),
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
            DebouncedTextField(
              key: const ValueKey('exchange.separator'),
              value: e.separator,
              label: l.chatSeparator,
              help: l.chatSeparatorHelp,
              onChanged: (v) =>
                  set((e) => e.copyWith(separator: v.trim().isEmpty ? defaultExchangeSeparator : v.trim())),
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
