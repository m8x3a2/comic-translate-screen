/// "Ready-made sets and templates" in Settings → General (step 9): three
/// ready-made sets, the user's own templates (saved here, to a file and
/// back), and the locks of the sections they leave alone.
library;

import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/app_state.dart';
import '../../state/settings_reset.dart';
import '../../state/settings_templates.dart';
import '../common/labels.dart';
import '../common/plugin_strings.dart';
import 'settings_screen.dart';

/// The name of section [part] as in the settings window.
String partTitle(BuildContext context, SettingsPart part) {
  final l = context.l10n;
  return switch (part) {
    SettingsPart.general => l.settingsGeneral,
    SettingsPart.translator => l.settingsTranslator,
    SettingsPart.exchange => l.chatTitle,
    SettingsPart.ocr => l.settingsOcr,
    SettingsPart.cleaning => l.settingsCleaning,
    SettingsPart.text => l.settingsText,
    SettingsPart.upscale => l.settingsUpscale,
    SettingsPart.export => l.settingsExport,
    SettingsPart.keys => l.settingsKeys,
    SettingsPart.models => l.settingsModels,
  };
}

String presetName(BuildContext context, SettingsPreset preset) => switch (preset) {
  SettingsPreset.weak => context.l10n.presetWeak,
  SettingsPreset.recommended => context.l10n.presetRecommended,
  SettingsPreset.high => context.l10n.presetHigh,
};

/// The lock of section [part], beside its title.
class SectionLockButton extends ConsumerWidget {
  const SectionLockButton(this.part, {super.key});

  final SettingsPart part;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final locked = ref.watch(settingsProvider.select((s) => s.lockedParts.contains(part.name)));
    return IconButton(
      key: ValueKey('lock/${part.name}'),
      tooltip: locked ? l.sectionUnlock : l.sectionLock,
      isSelected: locked,
      selectedIcon: const Icon(Icons.lock),
      icon: const Icon(Icons.lock_open_outlined),
      onPressed: () => ref.read(settingsProvider.notifier).change((s) {
        if (!s.lockedParts.remove(part.name)) s.lockedParts.add(part.name);
      }),
    );
  }
}

class SettingsSetsGroup extends ConsumerStatefulWidget {
  const SettingsSetsGroup({super.key});

  @override
  ConsumerState<SettingsSetsGroup> createState() => _SettingsSetsGroupState();
}

class _SettingsSetsGroupState extends ConsumerState<SettingsSetsGroup> {
  List<SettingsTemplate>? _templates;

  Directory get _dir => ref.read(servicesProvider).paths.settingsTemplates;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final found = await listTemplates(_dir);
    if (mounted) setState(() => _templates = found);
  }

  void _tell(String text) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));

  bool get _vlm => ref.read(servicesProvider).registry.contains(vlmReaderId);

  // Ready-made sets.

  Future<void> _preset(SettingsPreset preset) async {
    final l = context.l10n;
    final now = ref.read(settingsProvider);
    final next = AppSettings.fromJson(now.toJson());
    applyPreset(next, preset, vlm: _vlm);
    final rows = _changes(now, next);
    final blocked = presetBlockedBy(now, preset, vlm: _vlm);
    final name = presetName(context, preset);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.presetTitle(name)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (rows.isEmpty) Text(l.presetNothing),
                for (final (label, before, after) in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: Theme.of(context).textTheme.labelLarge),
                        Text('$before  →  $after'),
                      ],
                    ),
                  ),
                if (blocked.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.lock, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(l.presetLocked([for (final p in blocked) partTitle(context, p)].join(', '))),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
          if (rows.isNotEmpty) FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.presetApply)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(settingsProvider.notifier).change((s) => applyPreset(s, preset, vlm: _vlm));
    if (mounted) _tell(l.presetApplied(name));
  }

  /// What a set changes: (setting, was, becomes).
  List<(String, String, String)> _changes(AppSettings a, AppSettings b) {
    final l = context.l10n;
    final registry = ref.read(servicesProvider).registry;
    String prep(String id) => registry.contains(id) ? pluginName(context, registry.info(id)) : id;
    String read(ReadLevel r) => switch (r) {
      ReadLevel.simple => l.readLevelSimple,
      ReadLevel.medium => l.readLevelMedium,
      ReadLevel.high => l.readLevelHigh,
      ReadLevel.ultra => l.readLevelUltra,
    };
    String clean(AppSettings s) => switch (CleanLevel.of(s)) {
      CleanLevel.simple => l.cleanLevelSimple,
      CleanLevel.medium => l.cleanLevelMedium,
      CleanLevel.high => l.cleanLevelHigh,
      null => l.cleanLevelCustom,
    };
    return [
      if (a.textPrep != b.textPrep) (l.textPrep, prep(a.textPrep), prep(b.textPrep)),
      if (a.screenTextPrep != b.screenTextPrep) (l.textPrepScreens, prep(a.screenTextPrep), prep(b.screenTextPrep)),
      if (a.readLevel != b.readLevel) (l.readLevel, read(a.readLevel), read(b.readLevel)),
      if (a.screenReadLevel != b.screenReadLevel)
        (l.readLevelScreens, read(a.screenReadLevel), read(b.screenReadLevel)),
      if (a.textPrepSeconds != b.textPrepSeconds)
        (l.textPrepSeconds, l.presetSeconds(a.textPrepSeconds), l.presetSeconds(b.textPrepSeconds)),
      if (clean(a) != clean(b)) (l.cleanLevel, clean(a), clean(b)),
    ];
  }

  // Templates.

  Future<void> _save() async {
    final l = context.l10n;
    final name = await showDialog<String>(context: context, builder: (_) => const _NameDialog());
    if (name == null || !mounted) return;
    final same = _templates?.where(
      (t) => templateFileName(t.name).toLowerCase() == templateFileName(name).toLowerCase(),
    );
    if (same != null && same.isNotEmpty) {
      final replace = await _ask(l.templateReplaceAsk(name), l.templateReplace);
      if (!replace || !mounted) return;
      for (final t in same) {
        await t.file?.delete();
      }
    }
    await saveTemplate(_dir, name, ref.read(settingsProvider));
    await _reload();
    if (mounted) _tell(l.templateSaved(name));
  }

  Future<bool> _ask(String question, String yes) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(question),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(yes)),
          ],
        ),
      ) ??
      false;

  Future<void> _apply(SettingsTemplate t) async {
    final l = context.l10n;
    final locked = [
      for (final part in SettingsPart.values)
        if (ref.read(settingsProvider).lockedParts.contains(part.name)) partTitle(context, part),
    ];
    // null: not applied; true: only the unlocked sections.
    final unlockedOnly = await showDialog<bool?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.templateApplyTitle(t.name)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.templateApplyText),
              if (locked.isNotEmpty) ...[const SizedBox(height: 12), Text(l.templateApplyLocked(locked.join(', ')))],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
          if (locked.isEmpty)
            FilledButton(onPressed: () => Navigator.pop(context, false), child: Text(l.templateApply))
          else ...[
            OutlinedButton(onPressed: () => Navigator.pop(context, false), child: Text(l.templateApplyAll)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.templateApplyUnlocked)),
          ],
        ],
      ),
    );
    if (unlockedOnly == null || !mounted) return;
    final registry = ref.read(servicesProvider).registry;
    await ref.read(settingsProvider.notifier).change((s) => t.applyTo(s, registry, unlockedOnly: unlockedOnly));
    if (mounted) _tell(l.templateApplied(t.name));
  }

  Future<void> _export(SettingsTemplate t) async {
    final l = context.l10n;
    final place = await getSaveLocation(
      suggestedName: templateFileName(t.name),
      acceptedTypeGroups: [
        XTypeGroup(label: l.settingsSets, extensions: [settingsTemplateExtension.substring(1)]),
      ],
    );
    if (place == null) return;
    await File(place.path).writeAsString(SettingsTemplate.encode(t.name, t.settings), flush: true);
    if (mounted) _tell(l.templateExported(place.path));
  }

  Future<void> _load() async {
    final l = context.l10n;
    final file = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(label: l.settingsSets, extensions: [settingsTemplateExtension.substring(1)]),
      ],
    );
    if (file == null || !mounted) return;
    final SettingsTemplate t;
    try {
      t = SettingsTemplate.decode(await file.readAsString());
    } on Object {
      if (mounted) _tell(l.templateBadFile);
      return;
    }
    if (!mounted) return;
    final exists = _templates?.any(
      (x) => templateFileName(x.name).toLowerCase() == templateFileName(t.name).toLowerCase(),
    );
    if (exists ?? false) {
      if (!await _ask(l.templateReplaceAsk(t.name), l.templateReplace) || !mounted) return;
    }
    await saveTemplate(_dir, t.name, t.settings);
    await _reload();
    if (mounted) _tell(l.templateSaved(t.name));
  }

  Future<void> _delete(SettingsTemplate t) async {
    final l = context.l10n;
    if (!await _ask(l.templateDeleteAsk(t.name), l.delete)) return;
    await t.file?.delete();
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final templates = _templates;
    return SettingsGroup(
      title: l.settingsSets,
      children: [
        Text(l.presetsHelp, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in SettingsPreset.values)
              OutlinedButton.icon(
                key: ValueKey('preset/${preset.name}'),
                onPressed: () => _preset(preset),
                icon: Icon(switch (preset) {
                  SettingsPreset.weak => Icons.battery_saver_outlined,
                  SettingsPreset.recommended => Icons.thumb_up_alt_outlined,
                  SettingsPreset.high => Icons.auto_awesome_outlined,
                }),
                label: Text(presetName(context, preset)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l.templatesTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        if (templates != null && templates.isEmpty) Text(l.templatesNone, style: theme.textTheme.bodySmall),
        for (final t in templates ?? const <SettingsTemplate>[])
          ListTile(
            key: ValueKey('template/${t.name}'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bookmark_outline),
            title: Text(t.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(onPressed: () => _apply(t), child: Text(l.templateApply)),
                IconButton(tooltip: l.templateExport, onPressed: () => _export(t), icon: const Icon(Icons.save_alt)),
                IconButton(tooltip: l.delete, onPressed: () => _delete(t), icon: const Icon(Icons.delete_outline)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('template-save'),
              onPressed: _save,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: Text(l.templateSave),
            ),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.file_open_outlined),
              label: Text(l.templateLoad),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(child: Text(l.templatesPrivacy, style: theme.textTheme.bodySmall)),
          ],
        ),
      ],
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _done() {
    if (_name.text.trim().isNotEmpty) Navigator.pop(context, _name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.templateSave),
      content: TextField(
        key: const ValueKey('template-name'),
        controller: _name,
        autofocus: true,
        decoration: InputDecoration(labelText: l.templateName),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _done(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: _name.text.trim().isEmpty ? null : _done, child: const Text('OK')),
      ],
    );
  }
}
