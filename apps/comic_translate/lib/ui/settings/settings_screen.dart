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
import '../../render/text_renderer.dart' show defaultFontFamily;
import '../common/fonts.dart';
import '../common/labels.dart';
import '../common/plugin_form.dart';
import '../common/plugin_strings.dart';
import '../shell_full/main_screen.dart' show showInExplorer;
import 'models_section.dart';
import 'usage_section.dart';

enum SettingsSection { general, translator, tools, text, upscale, export, models, about }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.initial = SettingsSection.general});

  final SettingsSection initial;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late var _section = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final titles = {
      SettingsSection.general: (Icons.tune, l.settingsGeneral),
      SettingsSection.translator: (Icons.translate, l.settingsTranslator),
      SettingsSection.tools: (Icons.document_scanner_outlined, l.settingsTools),
      SettingsSection.text: (Icons.text_fields, l.settingsText),
      SettingsSection.upscale: (Icons.zoom_out_map, l.settingsUpscale),
      SettingsSection.export: (Icons.save_alt, l.settingsExport),
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
                      switch (_section) {
                        SettingsSection.general => const _GeneralSection(),
                        SettingsSection.translator => const _TranslatorSection(),
                        SettingsSection.tools => const _ToolsSection(),
                        SettingsSection.text => const _TextSection(),
                        SettingsSection.upscale => const _UpscaleSection(),
                        SettingsSection.export => const _ExportSection(),
                        SettingsSection.models => const ModelsSection(),
                        SettingsSection.about => const _AboutSection(),
                      },
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
  });

  final String label;
  final String? help;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<T>(
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
    ),
  );
}

Widget _switch(String title, bool value, ValueChanged<bool> onChanged, {String? help}) => SwitchListTile(
  contentPadding: EdgeInsets.zero,
  title: Text(title),
  subtitle: help == null ? null : Text(help),
  value: value,
  onChanged: onChanged,
);

Widget _number(String key, String label, num value, ValueChanged<num> onChanged) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: DebouncedTextField(
    key: ValueKey(key),
    value: '$value',
    label: label,
    numeric: true,
    onChanged: (v) {
      final n = num.tryParse(v.replaceAll(',', '.'));
      if (n != null) onChanged(n);
    },
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
            _switch(l.useGpu, s.useGpu, (v) => _change(ref, (s) => s.useGpu = v), help: l.useGpuHelp),
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
            _switch(l.testMode, s.testMode, (v) => _change(ref, (s) => s.testMode = v), help: l.testModeHelp),
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
                    await services.appLog.flush();
                    final zip = await BugReportBuilder(
                      paths: services.paths,
                      redactor: services.redactor,
                    ).build(environment: services.environment());
                    services.appLog.info('bug_report', {'file': zip.path, 'with_images': false});
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
            Text(l.bugReportHelp, style: Theme.of(context).textTheme.bodySmall),
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
            DebouncedTextField(
              key: const ValueKey('extra_context'),
              value: s.extraContext,
              label: l.extraContext,
              help: l.extraContextHelp,
              multiline: true,
              onChanged: (v) => _change(ref, (s) => s.extraContext = v),
            ),
            const SizedBox(height: 8),
            _switch(
              l.sendPageImage,
              s.sendPageImage,
              (v) => _change(ref, (s) => s.sendPageImage = v),
              help: l.sendPageImageHelp,
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
        pluginWithForm(l.detector, PluginKind.detector, s.detector, (s, v) => s.detector = v),
        pluginWithForm(l.ocr, PluginKind.ocr, s.ocr, (s, v) => s.ocr = v),
        SettingsGroup(
          children: [
            _switch(l.upscaleSmallText, s.upscaleSmallText, (v) => _change(ref, (s) => s.upscaleSmallText = v)),
            _switch(
              l.fixCyrillic,
              s.fixCyrillicLookalikes,
              (v) => _change(ref, (s) => s.fixCyrillicLookalikes = v),
              help: l.fixCyrillicHelp,
            ),
          ],
        ),
        pluginWithForm(l.inpainter, PluginKind.inpainter, s.inpainter, (s, v) => s.inpainter = v),
        SettingsGroup(
          title: l.hdStrategy,
          children: [
            _Dropdown(
              label: l.hdStrategy,
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
              ),
            if (inpaint.strategy == HdStrategy.crop) ...[
              _number(
                'crop_margin',
                l.cropMargin,
                inpaint.cropMargin,
                (v) => _change(ref, (s) => s.inpaint = withInpaint(cropMargin: v.toInt().clamp(0, 4096))),
              ),
              _number(
                'crop_trigger',
                l.cropTrigger,
                inpaint.cropTriggerSize,
                (v) => _change(ref, (s) => s.inpaint = withInpaint(cropTriggerSize: v.toInt().clamp(64, 8192))),
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
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.fontsAdded('${fonts.length}'))));
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
                  ),
                ),
              ],
            ),
            _number(
              'line_spacing',
              l.lineSpacing,
              r.lineSpacing,
              (v) => set((r) => r.copyWith(lineSpacing: v.toDouble().clamp(0.5, 3.0))),
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
              value: e.imageFormat,
              options: {'source': l.formatSource, 'png': 'PNG', 'jpg': 'JPG', 'webp': 'WEBP'},
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
