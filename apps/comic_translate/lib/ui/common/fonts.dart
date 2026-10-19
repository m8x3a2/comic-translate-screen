/// Fonts offered for the translation: the bundled lettering font, common
/// Windows fonts that are installed, and font files the user picks.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../../render/text_renderer.dart';

/// Family → font file in the Windows font folder.
const _windowsFonts = {
  'Comic Sans MS': 'comic.ttf',
  'Segoe Print': 'segoepr.ttf',
  'Segoe UI': 'segoeui.ttf',
  'Arial': 'arial.ttf',
  'Arial Black': 'ariblk.ttf',
  'Calibri': 'calibri.ttf',
  'Candara': 'candara.ttf',
  'Georgia': 'georgia.ttf',
  'Impact': 'impact.ttf',
  'Tahoma': 'tahoma.ttf',
  'Times New Roman': 'times.ttf',
  'Trebuchet MS': 'trebuc.ttf',
  'Verdana': 'verdana.ttf',
  'Courier New': 'cour.ttf',
  'Yu Gothic': 'YuGothR.ttc',
  'Microsoft YaHei': 'msyh.ttc',
  'Malgun Gothic': 'malgun.ttf',
};

List<String>? _installed;

/// Families to choose from, the bundled font first.
List<String> availableFonts() => _installed ??= [
  defaultFontFamily,
  if (Platform.isWindows)
    for (final e in _windowsFonts.entries)
      if (File(p.join(Platform.environment['WINDIR'] ?? r'C:\Windows', 'Fonts', e.value)).existsSync()) e.key,
];

/// A short name for a font setting (a file shows its name).
String fontLabel(String setting) {
  if (setting.isEmpty) return defaultFontFamily;
  final lower = setting.toLowerCase();
  if (lower.endsWith('.ttf') || lower.endsWith('.otf') || lower.endsWith('.ttc')) {
    return p.basenameWithoutExtension(setting);
  }
  return setting;
}
