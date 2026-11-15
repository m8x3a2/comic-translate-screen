/// Ready-made sets of settings and the user's own templates (step 9 of the
/// plan, the owner's ideas): a set changes only the heavy choices (how text
/// is read and cleaned); a template carries every section. Sections under a
/// lock are left as they are. API keys never go into a template.
library;

import 'dart:convert';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;

import 'settings_reset.dart';

/// The id of the waifu2x CUnet text preparation ("Simple").
const waifu2xCunetId = 'waifu2x_cunet';

/// The ready-made sets.
enum SettingsPreset { weak, recommended, high }

/// [s] with the heavy choices of [preset], but in the sections under a lock.
/// [vlm]: the PaddleOCR-VL reader is there (the "High" reading needs it).
void applyPreset(AppSettings s, SettingsPreset preset, {required bool vlm}) {
  final d = AppSettings();
  if (!s.lockedParts.contains(SettingsPart.ocr.name)) {
    switch (preset) {
      case SettingsPreset.weak:
        s
          ..textPrep = waifu2xCunetId
          ..screenTextPrep = d.screenTextPrep
          ..readLevel = ReadLevel.simple
          ..screenReadLevel = ReadLevel.simple
          ..textPrepSeconds = 30;
      case SettingsPreset.recommended:
        s
          ..textPrep = d.textPrep
          ..screenTextPrep = d.screenTextPrep
          ..readLevel = d.readLevel
          ..screenReadLevel = d.screenReadLevel
          ..textPrepSeconds = d.textPrepSeconds;
      case SettingsPreset.high:
        s
          ..textPrep = d.textPrep
          ..screenTextPrep = d.screenTextPrep
          ..readLevel = vlm ? ReadLevel.high : ReadLevel.medium
          ..screenReadLevel = vlm ? ReadLevel.high : ReadLevel.medium
          ..textPrepSeconds = 180;
    }
  }
  if (!s.lockedParts.contains(SettingsPart.cleaning.name)) {
    (preset == SettingsPreset.weak ? CleanLevel.simple : CleanLevel.high).applyTo(s);
  }
}

/// The sections under a lock that [preset] would have changed.
List<SettingsPart> presetBlockedBy(AppSettings s, SettingsPreset preset, {required bool vlm}) {
  final free = AppSettings.fromJson(s.toJson())..lockedParts.clear();
  applyPreset(free, preset, vlm: vlm);
  final changed = <SettingsPart>[
    if (free.textPrep != s.textPrep ||
        free.screenTextPrep != s.screenTextPrep ||
        free.readLevel != s.readLevel ||
        free.screenReadLevel != s.screenReadLevel ||
        free.textPrepSeconds != s.textPrepSeconds)
      SettingsPart.ocr,
    if (free.inpainter != s.inpainter || free.textMask != s.textMask) SettingsPart.cleaning,
  ];
  return [
    for (final part in changed)
      if (s.lockedParts.contains(part.name)) part,
  ];
}

// Templates.

/// The extension of a template file.
const settingsTemplateExtension = '.ctssettings';

const _format = 'comic-translate-screen settings';

/// A settings template: its name and the settings it carries.
class SettingsTemplate {
  SettingsTemplate(this.name, this.settings, {this.file});

  final String name;
  final AppSettings settings;

  /// Where it is kept (the templates folder), when it is.
  final File? file;

  /// [settings] as a template file: what belongs to this computer or is
  /// private (keys, own servers, recent projects, permissions, the models
  /// folder) is left out.
  static String encode(String name, AppSettings settings) {
    final json = settings.toJson()
      ..remove('own_servers')
      ..remove('own_server_keys')
      ..remove('request_templates')
      ..remove('model_prompt_presets')
      ..remove('approved_network_plugins')
      ..remove('projects')
      ..remove('models');
    final tools = {...?(json['tools'] as Map?)?.cast<String, Object?>()}..remove('gpu_cpu_models');
    final ui = {...?(json['ui'] as Map?)?.cast<String, Object?>()}
      ..remove('text_panel_width')
      ..remove('settings_last_view');
    final plugins = {
      for (final e in ((json['plugins'] as Map?) ?? const {}).entries)
        if (!'${e.key}'.startsWith(AppSettings.ownServerStoragePrefix)) '${e.key}': e.value,
    };
    json
      ..['tools'] = tools
      ..['ui'] = ui
      ..['plugins'] = plugins;
    return const JsonEncoder.withIndent('  ')
        .convert({'format': _format, 'version': 1, 'name': name, 'settings': json});
  }

  /// A template file read back; a [FormatException] when it is not one.
  static SettingsTemplate decode(String text, {File? file}) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      throw const FormatException('not JSON');
    }
    if (json is! Map || json['format'] != _format || json['settings'] is! Map) {
      throw const FormatException('not a settings template');
    }
    final name = (json['name'] is String && (json['name'] as String).trim().isNotEmpty)
        ? (json['name'] as String).trim()
        : (file == null ? 'Template' : p.basenameWithoutExtension(file.path));
    return SettingsTemplate(name, AppSettings.fromJson((json['settings'] as Map).cast<String, Object?>()), file: file);
  }

  /// The sections [s] would take from this template: all of them, or
  /// [unlockedOnly] those not under a lock in [s].
  void applyTo(AppSettings s, PluginRegistry registry, {required bool unlockedOnly}) {
    for (final part in SettingsPart.values) {
      if (unlockedOnly && s.lockedParts.contains(part.name)) continue;
      copySettingsPart(s, settings, registry, part);
    }
    // The locks go with the whole template.
    if (!unlockedOnly) s.lockedParts = {...settings.lockedParts};
  }
}

/// The templates kept in [dir], by name.
Future<List<SettingsTemplate>> listTemplates(Directory dir) async {
  if (!await dir.exists()) return [];
  final found = <SettingsTemplate>[];
  await for (final f in dir.list()) {
    if (f is! File || !f.path.toLowerCase().endsWith(settingsTemplateExtension)) continue;
    try {
      found.add(SettingsTemplate.decode(await f.readAsString(), file: f));
    } on Object {
      // A broken file is not listed.
    }
  }
  found.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return found;
}

/// A file name for a template called [name]: the letters of the name, safe
/// on every system.
String templateFileName(String name) {
  final safe = name.trim().replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_').replaceAll(RegExp(r'[. ]+$'), '');
  return '${safe.isEmpty ? 'template' : safe}$settingsTemplateExtension';
}

/// Keeps [settings] as template [name] in [dir] (replacing one of the same
/// name).
Future<File> saveTemplate(Directory dir, String name, AppSettings settings) async {
  await dir.create(recursive: true);
  final file = File(p.join(dir.path, templateFileName(name)));
  await file.writeAsString(SettingsTemplate.encode(name, settings), flush: true);
  return file;
}
