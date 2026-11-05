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
  help: 'How long to wait for the answer to one request.',
  defaultValue: 180,
  min: 10,
  max: 900,
  advanced: true,
);

const _readingMaxTokens = IntSetting(
  key: 'max_tokens',
  label: 'Maximum answer length (tokens)',
  help: 'Enough for the text of a few pages.',
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

const _readingTogether = BoolSetting(
  key: 'together',
  label: 'Read and translate in one request',
  help:
      'The model that reads translates too: one request instead of two, and it sees the pictures while it '
      'translates. Off: it only reads, the translator chosen translates.',
  defaultValue: false,
);

const _readingPagePictures = BoolSetting(
  key: 'page_pictures',
  label: 'Send the whole page too',
  help: 'With "one request": a picture of each whole page shows what happens and who speaks (costs more).',
  defaultValue: false,
);

const _readingMaxBlocks = IntSetting(
  key: 'max_blocks',
  label: 'Bubbles in one request',
  help: 'Pages go together until there are this many bubbles; a page with more is sent in parts.',
  defaultValue: 40,
  min: 1,
  max: 200,
  advanced: true,
);

const _readingMaxPictures = IntSetting(
  key: 'max_pictures',
  label: 'Pictures in one request',
  help: 'Sheets of bubbles (and whole pages) in one request; more go in another request.',
  defaultValue: 10,
  min: 1,
  max: 50,
  advanced: true,
);

/// The settings of reading by a model that tell how the pages go.
const _readingPlan = [_readingTogether, _readingPagePictures, _readingResend, _readingMaxBlocks, _readingMaxPictures];

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
    ..._readingPlan,
    _readingMaxTokens,
    _readingTimeout,
  ],
  endpoint: openRouterEndpoint,
  keyStatus: openRouterKeyStatus,
  modelCatalog: openRouterModelCatalog,
  keyUrl: 'https://openrouter.ai/settings/keys',
  readsWholePage: true,
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
    ..._readingPlan,
    _readingMaxTokens,
    _readingTimeout,
  ],
  endpoint: openAiCompatibleEndpoint,
  keyStatus: openAiCompatibleKeyStatus,
  modelCatalog: openAiCompatibleModelCatalog,
  readsWholePage: true,
);

final openRouterOcrFactory = PluginFactory<OcrEngine>(
  openRouterOcrInfo,
  (config, env) async => ModelOcr.of(config, openRouterOcrInfo, apiUrl: openRouterApiUrl),
);

final openAiCompatibleOcrFactory = PluginFactory<OcrEngine>(
  openAiCompatibleOcrInfo,
  (config, env) async => ModelOcr.of(config, openAiCompatibleOcrInfo, apiUrl: openAiCompatibleUrl(config)),
);

/// Reads the blocks of pages in parts of a few dozen bubbles, each with one
/// request (and one more for what its answer left out); translates them in
/// the same requests when asked to.
class ModelOcr implements PageOcr {
  ModelOcr(
    this.info,
    this.client, {
    this.resendMissing = true,
    this.maxBlocks = 40,
    this.maxPictures = 10,
    this.pagePictures = false,
  });

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
    maxBlocks: config.value<int>('max_blocks'),
    maxPictures: config.value<int>('max_pictures'),
    pagePictures: config.value<bool>('page_pictures'),
  );

  @override
  final PluginInfo info;

  /// Sends the requests (the translator of the same service, its model and
  /// key).
  final OpenAiCompatibleTranslator client;
  final bool resendMissing;

  /// Bubbles and pictures in one request at most.
  final int maxBlocks;
  final int maxPictures;

  /// Whole pages go along when translating.
  final bool pagePictures;

  @override
  Future<void> recognize(
    RgbImage image,
    List<TextBlock> blocks, {
    required String sourceLanguage,
    required PluginContext context,
  }) => recognizePages([OcrPage(image, blocks)], sourceLanguage: sourceLanguage, context: context);

  @override
  Future<void> recognizePages(
    List<OcrPage> pages, {
    required String sourceLanguage,
    ReadingTranslation? translation,
    required PluginContext context,
  }) async {
    final parts = readingParts([for (final p in pages) p.blocks.length], maxBlocks);
    if (parts.isEmpty) return;
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
    for (final part in parts) {
      await _readPart(pages, part, sourceLanguage, translation, context, uri);
    }
  }

  /// [part] of [pages] in one request, or in halves when its pictures are
  /// more than [maxPictures].
  Future<void> _readPart(
    List<OcrPage> pages,
    ReadingPart part,
    String sourceLanguage,
    ReadingTranslation? translation,
    PluginContext context,
    Uri uri,
  ) async {
    final log = context.log.child(stage: 'ocr');
    final count = part.fold(0, (n, p) => n + p.blocks.length);
    // The pages of the part; the labels number them from 1.
    final own = [for (final p in part) pages[p.page]];
    ReadingRequest request(ReadingMissing? again) => readingRequest(
      own,
      sourceLanguage: sourceLanguage == Languages.auto ? 'original' : sourceLanguage,
      only: [
        for (final (k, p) in part.indexed)
          again == null
              ? p.blocks
              : [
                  for (final m in again)
                    if (m.page == k) m.block,
                ],
      ],
      translation: translation,
      pagePictures: pagePictures && translation != null,
    );
    final first = request(null);
    if (first.sheets.length > maxPictures && count > 1) {
      final (a, b) = halveReadingPart(part);
      log.info('model_ocr_split', {'blocks': count, 'pictures': first.sheets.length});
      await _readPart(pages, a, sourceLanguage, translation, context, uri);
      await _readPart(pages, b, sourceLanguage, translation, context, uri);
      return;
    }
    var (missing, cut) = await _ask(own, first, context, uri, again: false);
    if (missing.length == count) {
      throw cut
          ? TranslationException(
              'the answer stopped at the length limit (finish_reason: length): raise "Maximum answer length"',
              kind: TranslationErrorKind.cutOff,
            )
          : TranslationException(
              'the model answered with no text for the bubbles',
              kind: TranslationErrorKind.badReply,
            );
    }
    if (resendMissing && missing.isNotEmpty) {
      log.info('model_ocr_resend', {'blocks': missing.length, 'of': count});
      try {
        (missing, _) = await _ask(own, request(missing), context, uri, again: true);
      } on TranslationException catch (e) {
        log.warn('model_ocr_resend_failed', {'error': e.message});
      }
    }
    if (missing.isEmpty) return;
    log.warn(translation == null ? 'model_ocr_unread' : 'model_ocr_left', {'blocks': missing.length, 'of': count});
    for (final m in missing) {
      final block = own[m.page].blocks[m.block];
      if (translation == null || block.text.trim().isEmpty) {
        // Not read: no text rather than the text of an earlier reading, which
        // would look read anew ("Frames without text" offers to read them).
        block.text = '';
        if (translation != null) block.translation = '';
      } else {
        // Read but not translated: as a translator's bubble left out (its
        // lettering stays, "not translated" tells).
        block.untranslated = true;
      }
    }
  }

  /// One [request]; returns what the answer had nothing for, and whether it
  /// stopped at the length limit.
  Future<(ReadingMissing, bool)> _ask(
    List<OcrPage> pages,
    ReadingRequest request,
    PluginContext context,
    Uri uri, {
    required bool again,
  }) async {
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
      'pages': pages.length,
      'sheets': request.sheets.length,
      if (request.translation != null) 'translate': true,
      if (again) 'again': true,
    });
    final sw = Stopwatch()..start();
    var reply = '';
    ServiceUsage? used;
    Future<void> keep([String error = '', List<String> warnings = const []]) => context.reportHistory(
      HistoryEntry(
        time: DateTime.now(),
        plugin: info.id,
        host: uri.host,
        model: client.model,
        page: context.page ?? '',
        again: again,
        ms: sw.elapsedMilliseconds,
        sent: OpenAiCompatibleTranslator.sentText(payload),
        image: true,
        reply: reply,
        blocks: request.items.length,
        warnings: warnings,
        error: error,
        inputTokens: used?.inputTokens ?? 0,
        outputTokens: used?.outputTokens ?? 0,
        cost: used?.cost,
      ),
    );
    try {
      final Map<String, Object?>? usage;
      final String? finish;
      (reply, usage, finish) = await client.postChat(uri, payload, context.cancel, log);
      used = client.usageOf(usage, payload, reply, host: uri.host);
      await context.reportUsage(used);
      final cut = finish == 'length';
      final missing = applyReadingAnswer(pages, request, reply, cut: cut);
      log.info('model_ocr_response', {
        'ms': sw.elapsedMilliseconds,
        'read': request.items.length - missing.length,
        'missing': missing.length,
        if (cut) 'cut': true,
        if (used.cost != null) 'cost': used.cost,
      });
      await keep('', [if (cut) 'the answer stopped at the length limit (finish_reason: length)']);
      return (missing, cut);
    } on TranslationException catch (e) {
      if (e.reply case final raw? when reply.isEmpty) reply = raw;
      await keep(e.message);
      rethrow;
    }
  }

  @override
  Future<void> dispose() => client.dispose();
}
