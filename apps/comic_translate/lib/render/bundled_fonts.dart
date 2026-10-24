/// Lettering fonts that come with the program: free (SIL OFL 1.1), all
/// with Latin and Cyrillic letters. Declared in pubspec.yaml under the same
/// family names; files and licences are in `assets/fonts`.
library;

import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;

class BundledFont {
  const BundledFont(
    this.family,
    this.regular, {
    required this.licence,
    this.bold,
    this.italic,
    this.boldItalic,
    this.variable = false,
  });

  final String family;

  /// File names in `assets/fonts`.
  final String regular;
  final String? bold;
  final String? italic;
  final String? boldItalic;
  final String licence;

  /// The weight is an axis of the font (bold is drawn by setting it).
  final bool variable;

  List<String> get files => [regular, ?bold, ?italic, ?boldItalic];

  /// The file of the face closest to [isBold] and [isItalic].
  String fileFor({required bool isBold, required bool isItalic}) =>
      (isBold && isItalic ? boldItalic : null) ?? (isBold ? bold : null) ?? (isItalic ? italic : null) ?? regular;
}

/// The default font first, then speech, shouts and sound effects,
/// handwriting, captions, pixel text.
const bundledFonts = [
  BundledFont('Pangolin', 'Pangolin-Regular.ttf', licence: 'Pangolin-OFL.txt'),
  BundledFont(
    'Shantell Sans',
    'ShantellSans-Regular.ttf',
    italic: 'ShantellSans-Italic.ttf',
    licence: 'ShantellSans-OFL.txt',
    variable: true,
  ),
  BundledFont(
    'Balsamiq Sans',
    'BalsamiqSans-Regular.ttf',
    bold: 'BalsamiqSans-Bold.ttf',
    italic: 'BalsamiqSans-Italic.ttf',
    boldItalic: 'BalsamiqSans-BoldItalic.ttf',
    licence: 'BalsamiqSans-OFL.txt',
  ),
  BundledFont('Neucha', 'Neucha-Regular.ttf', licence: 'Neucha-OFL.txt'),
  BundledFont('Underdog', 'Underdog-Regular.ttf', licence: 'Underdog-OFL.txt'),
  BundledFont('Marmelad', 'Marmelad-Regular.ttf', licence: 'Marmelad-OFL.txt'),
  BundledFont('Russo One', 'RussoOne-Regular.ttf', licence: 'RussoOne-OFL.txt'),
  BundledFont('Rubik Mono One', 'RubikMonoOne-Regular.ttf', licence: 'RubikMonoOne-OFL.txt'),
  BundledFont('Rubik Wet Paint', 'RubikWetPaint-Regular.ttf', licence: 'RubikWetPaint-OFL.txt'),
  BundledFont('Rubik Bubbles', 'RubikBubbles-Regular.ttf', licence: 'RubikBubbles-OFL.txt'),
  BundledFont('Caveat', 'Caveat-Regular.ttf', licence: 'Caveat-OFL.txt', variable: true),
  BundledFont('Amatic SC', 'AmaticSC-Regular.ttf', bold: 'AmaticSC-Bold.ttf', licence: 'AmaticSC-OFL.txt'),
  BundledFont('Bad Script', 'BadScript-Regular.ttf', licence: 'BadScript-OFL.txt'),
  BundledFont(
    'PT Sans',
    'PTSans-Regular.ttf',
    bold: 'PTSans-Bold.ttf',
    italic: 'PTSans-Italic.ttf',
    boldItalic: 'PTSans-BoldItalic.ttf',
    licence: 'PTSans-OFL.txt',
  ),
  BundledFont(
    'PT Sans Narrow',
    'PTSansNarrow-Regular.ttf',
    bold: 'PTSansNarrow-Bold.ttf',
    licence: 'PTSansNarrow-OFL.txt',
  ),
  BundledFont('Press Start 2P', 'PressStart2P-Regular.ttf', licence: 'PressStart2P-OFL.txt'),
];

/// The bundled font of [family], if it is one.
BundledFont? bundledFont(String family) {
  for (final f in bundledFonts) {
    if (f.family == family) return f;
  }
  return null;
}

/// Where the bundled font files are next to the program (in the project's
/// `assets/fonts` when run from it, as in tests).
String bundledFontDir() {
  final installed = p.join(p.dirname(Platform.resolvedExecutable), 'data', 'flutter_assets', 'assets', 'fonts');
  if (Directory(installed).existsSync()) return installed;
  final project = p.join(Directory.current.path, 'assets', 'fonts');
  return Directory(project).existsSync() ? project : installed;
}

Map<String, (String file, String licence)>? _byPostScript;

/// PostScript name → file and licence of every bundled face (read once from
/// the files; empty when they are not found).
Map<String, (String file, String licence)> bundledFacesByPostScript() => _byPostScript ??= {
  for (final f in bundledFonts)
    for (final file in f.files)
      for (final face in readFontFaces(p.join(bundledFontDir(), file))) face.postScript: (file, f.licence),
};
