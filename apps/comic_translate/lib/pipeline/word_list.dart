/// The English word list (`assets/dict`) for splitting glued words and for
/// the recognition levels, read from the program's folder (the app and `cts`
/// share it) or, in tests, from the source tree. Loaded once per isolate.
library;

import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;

const _asset = 'assets/dict/en_words.txt';

Future<String?>? _text;
Future<GluedWords?>? _glued;
Future<EnglishWords?>? _english;

/// The word list for splitting glued words, or null when its file is
/// missing.
Future<GluedWords?> loadGluedWords() => _glued ??= _readText().then((t) => t == null ? null : GluedWords.parse(t));

/// The common words of the recognition levels, or null when the file is
/// missing.
Future<EnglishWords?> loadEnglishWords() =>
    _english ??= _readText().then((t) => t == null ? null : EnglishWords.parse(t));

Future<String?> _readText() => _text ??= _load();

Future<String?> _load() async {
  final exeDir = p.dirname(Platform.resolvedExecutable);
  for (final path in [p.join(exeDir, 'data', 'flutter_assets', _asset), p.join(Directory.current.path, _asset)]) {
    final file = File(path);
    if (await file.exists()) return file.readAsString();
  }
  return null;
}
