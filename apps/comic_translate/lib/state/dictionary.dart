/// The offline dictionary (English to Russian) of the open models folder,
/// and the offline translator for words it does not know.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_state.dart';

/// The dictionary, or null while it is not downloaded. Refresh with
/// `ref.invalidate(dictionaryProvider)` after a download.
final dictionaryProvider = FutureProvider<OfflineDictionary?>((ref) async {
  ref.watch(settingsProvider.select((s) => s.modelsDir));
  final models = ref.watch(servicesProvider).models;
  const spec = ModelCatalog.dictEnRu;
  if (await models.status(spec) != ModelStatus.installed) return null;
  final dict = OfflineDictionary.open(models.fileOf(spec, ModelCatalog.dictionaryFile).path);
  ref.onDispose(dict.dispose);
  return dict;
});

/// The word at [start] in [text] (letters, digits, `'` and `-` inside
/// a word), or the selected part when [start] < [end].
String dictionaryQueryAt(String text, int start, int end) {
  if (start < 0 || end > text.length) return '';
  if (start < end) return text.substring(start, end).trim();
  bool part(int i) => i >= 0 && i < text.length && RegExp(r"[\p{L}\p{N}'’\-]", unicode: true).hasMatch(text[i]);
  var a = start, b = start;
  while (part(a - 1)) {
    a--;
  }
  while (part(b)) {
    b++;
  }
  return text.substring(a, b).replaceAll(RegExp(r"^['’\-]+|['’\-]+$"), '');
}

/// [text] translated by the offline translator (the big model when it is
/// downloaded, else the usual one), in the background; null when no
/// offline English to Russian model is downloaded.
Future<String?> translateOffline(ModelManager models, String text) async {
  for (final spec in [ModelCatalog.opusMtBigEnRu, ModelCatalog.opusMtEnRu]) {
    if (await models.status(spec) == ModelStatus.installed) {
      return Isolate.run(() => _translate(models.root.path, spec.id, text));
    }
  }
  return null;
}

// Top level: the isolate gets plain data only.
Future<String> _translate(String root, String modelId, String text) async {
  final translator = OpusMtTranslator(ModelManager(Directory(root)), big: modelId == ModelCatalog.opusMtBigEnRu.id);
  try {
    final big = modelId == ModelCatalog.opusMtBigEnRu.id;
    final (spec, _, target) = (big ? opusMtBigModels : opusMtModels)['English']!;
    final engine = await translator.engine(spec, target: target);
    return [for (final s in splitSentences(prepareComicText(text))) engine.translate(s)].join(' ');
  } finally {
    await translator.dispose();
  }
}
