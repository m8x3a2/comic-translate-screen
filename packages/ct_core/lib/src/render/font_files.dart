/// Names of the faces in font files (TrueType, OpenType, collections): the
/// family a program shows, and the PostScript name Photoshop files refer
/// to fonts by.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

class FontFace {
  const FontFace({
    required this.path,
    required this.family,
    required this.style,
    required this.postScript,
    required this.bold,
    required this.italic,
  });

  final String path;

  /// Typographic family (`Arial`) and style (`Bold Italic`).
  final String family;
  final String style;

  /// `Arial-BoldItalicMT`.
  final String postScript;
  final bool bold;
  final bool italic;

  @override
  String toString() => '$family $style ($postScript)';
}

/// Reads [n] bytes at [at] of [f] (fewer at the end).
Uint8List _read(RandomAccessFile f, int at, int n) {
  f.setPositionSync(at);
  return f.readSync(n);
}

/// The faces in the font file at [path] (empty when it is not one).
List<FontFace> readFontFaces(String path) {
  RandomAccessFile? f;
  try {
    f = File(path).openSync();
    final head = _read(f, 0, 12);
    if (head.length < 12) return const [];
    final v = ByteData.sublistView(head);
    if (latin1.decode(head.sublist(0, 4)) == 'ttcf') {
      final count = v.getUint32(8);
      final offsets = ByteData.sublistView(_read(f, 12, 4 * count.clamp(0, 256)));
      return [for (var i = 0; i < offsets.lengthInBytes ~/ 4; i++) ?_face(f, path, offsets.getUint32(i * 4))];
    }
    return [?_face(f, path, 0)];
  } on Object {
    return const [];
  } finally {
    f?.closeSync();
  }
}

FontFace? _face(RandomAccessFile f, String path, int at) {
  final head = ByteData.sublistView(_read(f, at, 12));
  final tag = head.getUint32(0);
  if (tag != 0x00010000 && tag != 0x4F54544F && tag != 0x74727565) return null; // 1.0, 'OTTO', 'true'
  final count = head.getUint16(4);
  final dir = ByteData.sublistView(_read(f, at + 12, 16 * count));
  (int, int)? table(String name) {
    for (var i = 0; i < count; i++) {
      final t = String.fromCharCodes([for (var k = 0; k < 4; k++) dir.getUint8(i * 16 + k)]);
      if (t == name) return (dir.getUint32(i * 16 + 8), dir.getUint32(i * 16 + 12));
    }
    return null;
  }

  final nameTable = table('name');
  if (nameTable == null) return null;
  final names = _names(_read(f, nameTable.$1, nameTable.$2));
  var bold = false, italic = false;
  if (table('OS/2') case (final off, final len) when len >= 64) {
    final os2 = ByteData.sublistView(_read(f, off, 64));
    final weight = os2.getUint16(4), selection = os2.getUint16(62);
    bold = weight >= 600 || selection & 0x20 != 0;
    italic = selection & 0x201 != 0;
  }
  final family = names[16] ?? names[1];
  final ps = names[6];
  if (family == null || ps == null) return null;
  return FontFace(
    path: path,
    family: family,
    style: names[17] ?? names[2] ?? 'Regular',
    postScript: ps,
    bold: bold,
    italic: italic,
  );
}

/// Name id → text, English (Windows names first).
Map<int, String> _names(Uint8List t) {
  final v = ByteData.sublistView(t);
  if (t.length < 6) return const {};
  final count = v.getUint16(2), strings = v.getUint16(4);
  final out = <int, String>{};
  final rank = <int, int>{};
  for (var i = 0; i < count; i++) {
    final r = 6 + i * 12;
    if (r + 12 > t.length) break;
    final platform = v.getUint16(r), encoding = v.getUint16(r + 2), lang = v.getUint16(r + 4);
    final id = v.getUint16(r + 6), len = v.getUint16(r + 8), off = v.getUint16(r + 10);
    final start = strings + off;
    if (start + len > t.length) continue;
    final bytes = t.sublist(start, start + len);
    final int score;
    final String text;
    if (platform == 3 || platform == 0) {
      score = platform == 3 && lang == 0x409 ? 3 : (platform == 3 ? 1 : 2);
      text = String.fromCharCodes([for (var k = 0; k + 1 < bytes.length; k += 2) bytes[k] << 8 | bytes[k + 1]]);
    } else if (platform == 1 && encoding == 0) {
      score = lang == 0 ? 2 : 0;
      text = latin1.decode(bytes);
    } else {
      continue;
    }
    if (text.isEmpty || (rank[id] ?? -1) >= score) continue;
    rank[id] = score;
    out[id] = text.replaceAll('\x00', '').trim();
  }
  return out;
}

/// Fonts found in [dirs] (not searched below them), by family and by
/// PostScript name.
class FontCatalog {
  FontCatalog._(this.faces);

  /// Scans [dirs]; on Windows with no [dirs], the system and the user's
  /// font folders.
  factory FontCatalog.scan([List<String>? dirs]) {
    final faces = <FontFace>[];
    for (final d in dirs ?? systemFontDirs()) {
      final dir = Directory(d);
      if (!dir.existsSync()) continue;
      for (final e in dir.listSync().whereType<File>()) {
        final ext = p.extension(e.path).toLowerCase();
        if (ext == '.ttf' || ext == '.otf' || ext == '.ttc') faces.addAll(readFontFaces(e.path));
      }
    }
    return FontCatalog._(faces);
  }

  factory FontCatalog.of(List<FontFace> faces) => FontCatalog._(faces);

  final List<FontFace> faces;

  static List<String> systemFontDirs() {
    if (!Platform.isWindows) return const [];
    final env = Platform.environment;
    return [
      p.join(env['WINDIR'] ?? r'C:\Windows', 'Fonts'),
      if (env['LOCALAPPDATA'] case final l?) p.join(l, 'Microsoft', 'Windows', 'Fonts'),
    ];
  }

  /// The face of [family] closest to [bold] / [italic] (case ignored).
  FontFace? face(String family, {bool bold = false, bool italic = false}) {
    final f = family.toLowerCase();
    final same = [
      for (final x in faces)
        if (x.family.toLowerCase() == f) x,
    ];
    if (same.isEmpty) return null;
    int cost(FontFace x) =>
        (x.bold == bold ? 0 : 2) +
        (x.italic == italic ? 0 : 2) +
        (x.style.toLowerCase().contains(RegExp('light|thin|medium|black|semi|condensed|narrow')) ? 1 : 0);
    same.sort((a, b) => cost(a).compareTo(cost(b)));
    return same.first;
  }

  FontFace? byPostScript(String name) {
    for (final x in faces) {
      if (x.postScript == name) return x;
    }
    return null;
  }
}
