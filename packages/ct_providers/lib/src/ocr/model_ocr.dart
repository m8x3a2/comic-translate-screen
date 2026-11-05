/// Reading by a language model that sees pictures, through OpenRouter or an
/// own OpenAI-compatible server: the exchange with a chat without hands
/// (see `model_reading.dart` in ct_core). The key is the one of the
/// translator of the same service. New in this project.
library;

import 'dart:convert';

import 'package:ct_core/ct_core.dart';

import '../translation/openai_compatible.dart';
import '../translation/openrouter.dart';

const _modelHelp = 'A model that sees pictures (the list marks them), e.g. google/gemini-2.5-flash.';
const _keyHelp = 'The same key as the translator of this service: entered once, it serves both.';

const _readingTimeout = IntSetting(
  key: 'timeout',
  label: 'Timeout (s)',
  help: 'How long to wait for the answer to one page.',
  defaultValue: 180,
  min: 10,
  max: 900,
  advanced: true,
);

const _readingMaxTokens = IntSetting(
  key: 'max_tokens',
  label: 'Maximum answer length (tokens)',
  help: 'Enough for the text of a page.',
  defaultValue: 4096,
  min: 256,
  max: 32768,
  advanced: true,
);

const _readingResend = BoolSetting(
  key: 'resend_missing',
  label: 'Ask again for the missing ones',
  help: 'When the answer has nothing for some bubbles, ask once more for them alone.',
  defaultValue: true,
);

const openRouterOcrInfo = PluginInfo(
  id: 'openrouter_ocr',
  displayName: 'Model by key: OpenRouter',
  description:
      'A language model that sees pictures reads the bubbles, through OpenRouter (openrouter.ai): '
      'the pictures of the bubbles of each page are sent there. The key is the one of the OpenRouter translator.',
  kind: PluginKind.ocr,
  privacy: Privacy.cloud,
  settings: [
    TextSetting(key: 'model', label: 'Model', help: _modelHelp, placeholder: 'google/gemini-2.5-flash'),
    SecretSetting(key: 'api_key', label: 'API key', help: _keyHelp, sharedWith: 'openrouter'),
    _readingResend,
    _readingMaxTokens,
    _readingTimeout,
  ],
  endpoint: openRouterEndpoint,
  keyStatus: openRouterKeyStatus,
  modelCatalog: openRouterModelCatalog,
  keyUrl: 'https://openrouter.ai/settings/keys',
);

const openAiCompatibleOcrInfo = PluginInfo(
  id: 'openai_compatible_ocr',
  displayName: 'Model by key: own server',
  description:
      'A language model that sees pictures reads the bubbles, through any OpenAI-compatible server you '
      'name (a local LM Studio / Ollama server, OpenAI and others). The key is the one of the "Own server" '
      'translator.',
  kind: PluginKind.ocr,
  privacy: Privacy.cloud,
  settings: [
    TextSetting(
      key: 'api_url',
      label: 'API URL',
      help: 'Base URL ending in /v1, e.g. http://localhost:1234/v1 (LM Studio).',
      placeholder: 'http://localhost:1234/v1',
      isUrl: true,
    ),
    TextSetting(key: 'model', label: 'Model', help: _modelHelp, placeholder: 'qwen2.5-vl-7b-instruct'),
    SecretSetting(
      key: 'api_key',
      label: 'API key',
      help: 'Not needed for most local servers. $_keyHelp',
      optional: true,
      sharedWith: 'openai_compatible',
    ),
    _readingResend,
    _readingMaxTokens,
    _readingTimeout,
  ],
  endpoint: openAiCompatibleEndpoint,
  keyStatus: openAiCompatibleKeyStatus,
  modelCatalog: openAiCompatibleModelCatalog,
);

final openRouterOcrFactory = PluginFactory<OcrEngine>(
  openRouterOcrInfo,
  (config, env) async => ModelOcr.of(config, openRouterOcrInfo, apiUrl: openRouterApiUrl),
);

final openAiCompatibleOcrFactory = PluginFactory<OcrEngine>(
  openAiCompatibleOcrInfo,
  (config, env) async => ModelOcr.of(config, openAiCompatibleOcrInfo, apiUrl: openAiCompatibleUrl(config)),
);

/// Reads the blocks of a page with one request (and one more for those the
/// answer left out).
class ModelOcr implements PageOcr {
  ModelOcr(this.info, this.client, {this.resendMissing = true});

  factory ModelOcr.of(PluginConfig config, PluginInfo info, {required String apiUrl}) => ModelOcr(
    info,
    OpenAiCompatibleTranslator(
      apiUrl: apiUrl,
      model: config.value<String>('model'),
      apiKey: config.secret('api_key') ?? '',
      temperature: 0,
      maxTokens: config.value<int>('max_tokens'),
      timeout: Duration(seconds: config.value<int>('timeout')),
      info: info,
    ),
    resendMissing: config.value<bool>('resend_missing'),
  );

  @override
  final PluginInfo info;

  /// Sends the requests (the translator of the same service, its model and
  /// key).
  final OpenAiCompatibleTranslator client;
  final bool resendMissing;

  @override
  Future<void> recognize(
    RgbImage image,
    List<TextBlock> blocks, {
    required String sourceLanguage,
    required PluginContext context,
  }) async {
    if (blocks.isEmpty) return;
    final base = client.apiUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse('$base/chat/completions');
    if (base.isEmpty || uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw TranslationException('set the API URL of the model that reads', kind: TranslationErrorKind.config);
    }
    if (client.model.trim().isEmpty) {
      throw TranslationException(
        'choose the model that reads (Settings, Recognition)',
        kind: TranslationErrorKind.config,
      );
    }
    var missing = await _ask(image, blocks, null, sourceLanguage, context, uri);
    if (resendMissing && missing.isNotEmpty && missing.length < blocks.length) {
      context.log.child(stage: 'ocr').info('model_ocr_resend', {'blocks': missing.length, 'of': blocks.length});
      try {
        missing = await _ask(image, blocks, missing, sourceLanguage, context, uri);
      } on TranslationException catch (e) {
        context.log.child(stage: 'ocr').warn('model_ocr_resend_failed', {'error': e.message});
      }
    }
    if (missing.length == blocks.length) {
      throw TranslationException(
        'the model answered with no text for the bubbles',
        kind: TranslationErrorKind.badReply,
      );
    }
  }

  /// One request for the blocks [only] (all when null); returns those the
  /// answer had nothing for.
  Future<List<int>> _ask(
    RgbImage image,
    List<TextBlock> blocks,
    List<int>? only,
    String sourceLanguage,
    PluginContext context,
    Uri uri,
  ) async {
    final request = readingRequest(
      image,
      blocks,
      sourceLanguage: sourceLanguage == Languages.auto ? 'original' : sourceLanguage,
      only: only,
    );
    final payload = {
      'model': client.model,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': request.prompt},
            for (final sheet in request.sheets)
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/png;base64,${base64Encode(ImageCodec.encodePng(sheet))}'},
              },
          ],
        },
      ],
      'temperature': 0,
      'max_tokens': client.maxTokens,
    };
    final log = context.log.child(stage: 'ocr');
    log.info('model_ocr_request', {
      'host': uri.host,
      'model': client.model,
      'blocks': request.items.length,
      'sheets': request.sheets.length,
      if (only != null) 'again': true,
    });
    final sw = Stopwatch()..start();
    var reply = '';
    ServiceUsage? used;
    Future<void> keep([String error = '']) => context.reportHistory(
      HistoryEntry(
        time: DateTime.now(),
        plugin: info.id,
        host: uri.host,
        model: client.model,
        page: context.page ?? '',
        again: only != null,
        ms: sw.elapsedMilliseconds,
        sent: OpenAiCompatibleTranslator.sentText(payload),
        image: true,
        reply: reply,
        blocks: request.items.length,
        error: error,
        inputTokens: used?.inputTokens ?? 0,
        outputTokens: used?.outputTokens ?? 0,
        cost: used?.cost,
      ),
    );
    try {
      final Map<String, Object?>? usage;
      (reply, usage, _) = await client.postChat(uri, payload, context.cancel, log);
      used = client.usageOf(usage, payload, reply, host: uri.host);
      await context.reportUsage(used);
      final missing = applyReadingAnswer(blocks, request, reply);
      log.info('model_ocr_response', {
        'ms': sw.elapsedMilliseconds,
        'read': request.items.length - missing.length,
        'missing': missing.length,
        if (used.cost != null) 'cost': used.cost,
      });
      await keep();
      return missing;
    } on TranslationException catch (e) {
      if (e.reply case final raw? when reply.isEmpty) reply = raw;
      await keep(e.message);
      rethrow;
    }
  }

  @override
  Future<void> dispose() => client.dispose();
}
