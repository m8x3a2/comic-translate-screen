/// "By hand through a chat AI": reading and translating done by the user in
/// ChatGPT, Gemini, Claude or any other chat, through the exchange window
/// (pictures with labels out, the chat's answer back in; see
/// `exchange_files.dart` in ct_core).
///
/// The app opens the exchange window itself when a step uses these plugins;
/// inside the pipeline they keep what the blocks already have.
library;

import 'package:ct_core/ct_core.dart';

const chatOcrId = 'chat_ocr';
const chatTranslatorId = 'chat_translator';

const _description =
    'You send pictures or text to a chat AI yourself and paste its answer back. Nothing is sent by the app.';

const chatOcrInfo = PluginInfo(
  id: chatOcrId,
  displayName: 'By hand through a chat AI',
  description: _description,
  kind: PluginKind.ocr,
  privacy: Privacy.local,
);

const chatTranslatorInfo = PluginInfo(
  id: chatTranslatorId,
  displayName: 'By hand through a chat AI',
  description: _description,
  kind: PluginKind.translator,
  privacy: Privacy.local,
);

/// Whether reading or translating with [settings] goes through the chat.
bool readsThroughChat(AppSettings settings) => settings.ocr == chatOcrId;
bool translatesThroughChat(AppSettings settings) => settings.translator == chatTranslatorId;

final chatOcrFactory = PluginFactory<OcrEngine>(chatOcrInfo, (config, env) async => ChatOcr());
final chatTranslatorFactory = PluginFactory<Translator>(chatTranslatorInfo, (config, env) async => ChatTranslator());

/// Keeps the text the exchange put into the blocks.
class ChatOcr implements OcrEngine {
  @override
  PluginInfo get info => chatOcrInfo;

  @override
  Future<void> recognize(
    RgbImage image,
    List<TextBlock> blocks, {
    required String sourceLanguage,
    required PluginContext context,
  }) async {
    context.cancel.throwIfCancelled();
    context.log.info('chat_ocr_kept', {'blocks': blocks.length});
  }

  @override
  Future<void> dispose() async {}
}

/// Keeps the translations the exchange put into the blocks.
class ChatTranslator implements Translator {
  @override
  PluginInfo get info => chatTranslatorInfo;

  @override
  Future<void> translate(TranslationRequest request, PluginContext context) async {
    context.cancel.throwIfCancelled();
    context.log.info('chat_translation_kept', {'blocks': request.blocks.length});
  }

  @override
  Future<void> dispose() async {}
}
