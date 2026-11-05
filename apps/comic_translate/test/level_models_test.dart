// "Download for a level": the models of a level with the user's settings,
// on the real plugins and an empty models folder.

import 'dart:io';

import 'package:comic_translate/state/batch.dart' show levelModels;
import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('cts_level_models_test_'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('each level brings its recognition, small text and cleaning; the settings stay', () async {
    final registry = builtInRegistry();
    final models = ModelManager(dir);
    final settings = AppSettings()..translator = 'mock';
    final before = settings.toJson().toString();
    Future<Set<String>> ids(ReadLevel level) async => {
      for (final m in await levelModels(registry, models, settings, level)) m.id,
    };

    final simple = await ids(ReadLevel.simple);
    final medium = await ids(ReadLevel.medium);
    final high = await ids(ReadLevel.high);
    final ultra = await ids(ReadLevel.ultra);

    // What works at all: both ways of finding text and the reader.
    for (final level in [simple, medium, high, ultra]) {
      expect(level, containsAll([ModelCatalog.rtdetrV2.id, ModelCatalog.ppocrDet.id, ModelCatalog.ppocrRecEn.id]));
    }
    expect(simple, containsAll([ModelCatalog.aot.id, ModelCatalog.waifu2xCunet.id]));
    expect(simple, isNot(contains(ModelCatalog.lamaManga.id)));
    expect(simple, isNot(contains(ModelCatalog.paddleOcrVl.id)));
    expect(medium, containsAll([ModelCatalog.comicTextDetector.id, ModelCatalog.ppocrRecChinese.id]));
    expect(medium, contains(ModelCatalog.waifu2xSwin.id));
    expect(high, containsAll([ModelCatalog.lamaManga.id, ModelCatalog.paddleOcrVl.id, ModelCatalog.fatalityComix.id]));
    expect(ultra, containsAll([ModelCatalog.lamaManga.id, ModelCatalog.paddleOcrVl.id]));
    expect(settings.toJson().toString(), before, reason: 'the user settings are not changed');
  });
}
