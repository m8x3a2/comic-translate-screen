// "By hand through a chat AI": listed with the other engines, sends nothing
// and keeps what the exchange put into the blocks.

import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:test/test.dart';

void main() {
  final registry = builtInRegistry();
  final env = PluginEnvironment(models: ModelManager(Directory.systemTemp), log: EventLog([]), useGpu: false);

  test('offered for reading and for translating, local, without models', () {
    expect(registry.available(PluginKind.ocr).map((i) => i.id), contains(chatOcrId));
    expect(registry.available(PluginKind.translator).map((i) => i.id), contains(chatTranslatorId));
    for (final id in [chatOcrId, chatTranslatorId]) {
      final info = registry.info(id);
      expect(info.privacy, Privacy.local);
      expect(info.endpointFor(PluginConfig()), isNull);
      expect(info.requiredModels('English'), isEmpty);
    }
    expect(readsThroughChat(AppSettings(ocr: chatOcrId)), isTrue);
    expect(translatesThroughChat(AppSettings()), isFalse);
  });

  test('the text and the translation stay as the exchange left them', () async {
    final blocks = [TextBlock(xyxy: const BBox(0, 0, 10, 10), text: 'Hi', translation: 'Привет')];
    final context = PluginContext(log: EventLog([]));
    final ocr = await registry.instance<OcrEngine>(chatOcrId, PluginConfig(), env);
    await ocr.recognize(RgbImage.filled(10, 10, 0, 0, 0), blocks, sourceLanguage: 'English', context: context);
    final tr = await registry.instance<Translator>(chatTranslatorId, PluginConfig(), env);
    await tr.translate(
      TranslationRequest(blocks: blocks, sourceLanguage: 'English', targetLanguage: 'Russian'),
      context,
    );
    expect((blocks.single.text, blocks.single.translation), ('Hi', 'Привет'));
  });
}
