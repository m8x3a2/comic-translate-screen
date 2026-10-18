/// Offline, deterministic translator for tests and demos. It goes through the
/// same `block_N` JSON protocol as the LLM translators.
library;

import 'dart:convert';

import 'package:ct_core/ct_core.dart';

const mockTranslatorInfo = PluginInfo(
  id: 'mock',
  displayName: 'Test translator (offline)',
  description: 'Does not translate: marks each text with the target language. For testing the pipeline offline.',
  kind: PluginKind.translator,
  privacy: Privacy.local,
  settings: [
    ChoiceSetting(
      key: 'style',
      label: 'Output',
      options: {'tag': '[ru] original text', 'upper': 'ORIGINAL TEXT', 'echo': 'original text'},
      defaultValue: 'tag',
    ),
  ],
);

final mockTranslatorFactory = PluginFactory<Translator>(mockTranslatorInfo, (config, env) async {
  return MockTranslator(style: config.value<String>('style'));
});

class MockTranslator implements Translator {
  MockTranslator({this.style = 'tag'});

  final String style;

  @override
  PluginInfo get info => mockTranslatorInfo;

  /// The reply an LLM would give for [request].
  String reply(TranslationRequest request) {
    final code = Languages.byName(request.targetLanguage)?.code ?? request.targetLanguage;
    final source = jsonDecode(blocksToJson(request.blocks)) as Map<String, Object?>;
    final out = {
      for (final e in source.entries)
        e.key: switch (style) {
          'upper' => pyUpper(e.value as String),
          'echo' => e.value,
          _ => '[$code] ${e.value}',
        },
    };
    return 'Here is the translation:\n${const JsonEncoder.withIndent('    ').convert(out)}';
  }

  @override
  Future<void> translate(TranslationRequest request, PluginContext context) async {
    context.cancel.throwIfCancelled();
    final text = reply(request);
    await context.recorder?.writeJsonArtifact('03_translate', 'response.json', {'content': text}, page: context.page);
    for (final w in applyTranslationsJson(request.blocks, text)) {
      context.log.warn('translate_reply_warning', {'warning': w});
    }
  }

  @override
  Future<void> dispose() async {}
}
