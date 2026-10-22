/// The English word list for splitting glued words (`assets/dict`), read
/// from the program's folder (the app and `cts` share it) or, in tests, from
/// the source tree. Loaded once per isolate.
library;

import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;

const _asset = 'assets/dict/en_words.txt';

Future<GluedWords?>? _loaded;

/// The word list, or null when its file is missing.
Future<GluedWords?> loadGluedWords() => _loaded ??= _load();

Future<GluedWords?> _load() async {
  final exeDir = p.dirname(Platform.resolvedExecutable);
  for (final path in [p.join(exeDir, 'data', 'flutter_assets', _asset), p.join(Directory.current.path, _asset)]) {
    final file = File(path);
    if (await file.exists()) return GluedWords.parse(await file.readAsString());
  }
  return null;
}
