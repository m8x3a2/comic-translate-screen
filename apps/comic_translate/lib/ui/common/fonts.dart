/// Fonts offered for the translation: the bundled lettering font, common
/// Windows fonts that are installed, fonts the user added (copied into the
/// program's `fonts` folder, original `settings_page.import_font`), and font
/// files picked for one bubble.
library;

import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../render/bundled_fonts.dart';
import '../../render/text_renderer.dart';
import '../../state/app_state.dart';

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

/// Families to choose from: the bundled fonts (the default first), then
/// common Windows fonts that are installed.
List<String> availableFonts() => _installed ??= [
  for (final f in bundledFonts) f.family,
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

const fontExtensions = ['ttf', 'otf', 'ttc'];

/// The fonts the user added, as file paths.
final addedFontsProvider = NotifierProvider<AddedFonts, List<String>>(AddedFonts.new);

class AddedFonts extends Notifier<List<String>> {
  Directory get _dir => ref.read(servicesProvider).paths.fonts;

  @override
  List<String> build() {
    final dir = _dir;
    if (!dir.existsSync()) return const [];
    return [
      for (final f in dir.listSync().whereType<File>())
        if (isFontFile(f.path)) f.path,
    ]..sort((a, b) => p.basename(a).toLowerCase().compareTo(p.basename(b).toLowerCase()));
  }

  /// Copies [files] into the fonts folder; returns the added fonts.
  Future<List<String>> add(List<String> files) async {
    final dir = _dir..createSync(recursive: true);
    final added = <String>[];
    for (final file in files.where(isFontFile)) {
      final target = p.join(dir.path, p.basename(file));
      if (!p.equals(file, target)) await File(file).copy(target);
      added.add(target);
    }
    ref.read(servicesProvider).appLog.info('fonts_added', {'count': added.length});
    state = build();
    return added;
  }

  void remove(String path) {
    final f = File(path);
    if (f.existsSync()) f.deleteSync();
    state = build();
  }
}
