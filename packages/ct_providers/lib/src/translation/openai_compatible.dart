/// Any OpenAI-compatible chat completions API (OpenRouter, OpenAI, DeepSeek,
/// LM Studio, Ollama, llama.cpp server, ...). Port of the original's
/// `Custom` translator (`modules/translation/llm/custom.py` over `gpt.py`).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ct_core/ct_core.dart';

import 'http_request_editor.dart';

/// The settings of a language model both translators have, folded under
/// "More settings".
const llmTemperatureSetting = DoubleSetting(
  key: 'temperature',
  label: 'Temperature',
  info:
      'How freely the model picks words. Lower is more exact and repeatable, higher more varied but with '
      'more mistakes. For translation usually 0 to 1.',
  defaultValue: llmDefaultTemperature,
  min: 0,
  max: 2,
  advanced: true,
);
const llmMaxTokensSetting = IntSetting(
  key: 'max_tokens',
  label: 'Maximum answer length (tokens)',
  info:
      'The longest answer the model may give. Raise it if a page translation is cut off. '
      'A token is about 3-4 letters. Left at 5000, a request with several pages asks for up to 16000.',
  defaultValue: llmDefaultMaxTokens,
  min: 64,
  max: 200000,
  advanced: true,
);
const llmTimeoutSetting = IntSetting(
  key: 'timeout',
  label: 'Timeout (seconds)',
  info: 'How long to wait for the server. Slow free models and local servers on a weak computer can take long.',
  defaultValue: 120,
  min: 5,
  max: 3600,
  advanced: true,
);

const llmPromptSetting = TextSetting(key: 'comic_prompt', label: 'Comic prompt', advanced: true);

const llmStreamSetting = BoolSetting(key: 'stream_chat', label: 'Stream response (SSE)', defaultValue: false);

const llmChatPathSetting = TextSetting(
  key: 'chat_path',
  label: 'Chat endpoint path',
  help: 'Appended to the API base URL. Leave blank for chat/completions.',
  advanced: true,
);
const llmModelsPathSetting = TextSetting(
  key: 'models_path',
  label: 'Models endpoint path',
  help: 'Appended to the API base URL. Leave blank for models.',
  advanced: true,
);
const llmRequestOptionsSetting = TextSetting(
  key: 'request_options',
  label: 'Additional request fields (JSON)',
  help: 'A JSON object such as {"top_p": 0.9}. Use null to omit a field. Keep model, messages and stream unchanged.',
  multiline: true,
  advanced: true,
);

/// How many pages go in one request ("Translate all" and the steps on
/// several picked pages); read by the app, not by the translator.
const llmPagesSetting = IntSetting(
  key: 'pages_per_request',
  label: 'Pages in one request',
  help: 'More than 1: neighbouring pages go together, so the model keeps names and the story; fewer requests.',
  info:
      'Only pages with text count, and pages of different chapters (archives, folders) never go together. '
      'Each line carries a label like 02-005 (page 2, bubble 5), so the model sees where a page ends. With '
      '"Send the page image", the pictures of all the pages of a request go along: it costs more, and the model '
      'must take pictures. Left at 5000, "Maximum answer length" is raised to 16000 for several pages; raise it if answers are still cut off.',
  defaultValue: 1,
  min: 1,
  max: 30,
);

const llmResendSetting = BoolSetting(
  key: 'resend_missing',
  label: 'Send the missing ones',
  help: 'When the answer has nothing for some bubbles, ask once more for them alone.',
  info:
      'Models sometimes skip bubbles, especially on long pages. Then the program sends one more short '
      'request with only the skipped bubbles. A bubble still without a translation keeps its original lettering '
      '(it is not cleaned) and is marked "no translation" in the text panel and the report.',
  defaultValue: true,
);

/// Any OpenAI-compatible server the user names ("Own server"): local ones
/// (Ollama, LM Studio, llama.cpp) or services (OpenAI, DeepSeek...).
/// OpenRouter has a translator of its own ([openRouterInfo]).
const openAiCompatibleInfo = PluginInfo(
  id: 'openai_compatible',
  displayName: 'Own server (OpenAI-compatible)',
  description:
      'Translates with a large language model through any OpenAI-compatible server you name: '
      'a local LM Studio / Ollama / llama.cpp server, OpenAI, DeepSeek and others.',
  kind: PluginKind.translator,
  privacy: Privacy.cloud,
  settings: [
    TextSetting(
      key: 'api_url',
      label: 'API URL',
      help: 'Use the base URL documented by your server, e.g. http://localhost:11434/v1 for Ollama.',
      placeholder: 'http://localhost:11434/v1',
      isUrl: true,
    ),
    TextSetting(
      key: 'model',
      label: 'Model',
      help: 'Enter the model ID or leave blank if your server can choose its default.',
      placeholder: 'qwen2.5:7b',
    ),
    SecretSetting(key: 'api_key', label: 'API key', help: 'Not needed for most local servers.', optional: true),
    llmPagesSetting,
    llmResendSetting,
    llmStreamSetting,
    llmTemperatureSetting,
    llmMaxTokensSetting,
    ChoiceSetting(
      key: 'token_limit_param',
      label: 'Length limit parameter',
      help: 'Name of the length limit field the server expects. Use max_tokens for older servers, none to omit it.',
      info:
          'With each request the program tells the server the longest answer it wants ("Maximum answer '
          'length" above). Servers expect it under different names: max_completion_tokens is the new one '
          '(OpenRouter, OpenAI), max_tokens the old one (many local servers and older models), none leaves it '
          'out. Change it only when the server answers with an error about this parameter.',
      options: {'max_completion_tokens': 'max_completion_tokens', 'max_tokens': 'max_tokens', 'none': 'none'},
      defaultValue: 'max_completion_tokens',
      advanced: true,
    ),
    llmTimeoutSetting,
    llmChatPathSetting,
    llmModelsPathSetting,
    llmRequestOptionsSetting,
    TextSetting(key: RequestTemplate.keyStatusPathKey, label: 'Template key status path', advanced: true),
    TextSetting(key: RequestTemplate.keyStatusFieldsKey, label: 'Template key status fields', advanced: true),
    llmPromptSetting,
    httpRequestTemplateSetting,
  ],
  endpoint: openAiCompatibleEndpoint,
  keyStatus: openAiCompatibleKeyStatus,
  modelCatalog: openAiCompatibleModelCatalog,
);

final openAiCompatibleFactory = PluginFactory<Translator>(openAiCompatibleInfo, (config, env) async {
  return OpenAiCompatibleTranslator(
    apiUrl: openAiCompatibleUrl(config),
    model: config.value<String>('model'),
    apiKey: config.secret('api_key') ?? '',
    temperature: config.value<double>('temperature'),
    maxTokens: config.value<int>('max_tokens'),
    tokenLimitParam: config.value<String>('token_limit_param'),
    resendMissing: config.value<bool>('resend_missing'),
    timeout: Duration(seconds: config.value<int>('timeout')),
    chatPath: config.value<String>('chat_path'),
    requestOptions: config.value<String>('request_options'),
    comicPrompt: config.value<String>(llmPromptSetting.key),
    streamChat: config.value<bool>(llmStreamSetting.key),
    httpChat: httpRequestSpec(config, HttpOperation.chat),
  );
});

/// The API URL of [config] without the slashes at the end.
String openAiCompatibleUrl(PluginConfig config) =>
    config.value<String>('api_url').trim().replaceAll(RegExp(r'/+$'), '');

/// Append a relative path while keeping the configured scheme, host and port.
Uri? openAiCompatibleUri(String apiUrl, String path, String defaultPath) {
  final base = Uri.tryParse(apiUrl.trim());
  if (base == null ||
      !const {'http', 'https'}.contains(base.scheme) ||
      base.host.isEmpty ||
      base.userInfo.isNotEmpty ||
      base.hasQuery ||
      base.hasFragment) {
    return null;
  }
  final route = Uri.tryParse(path.trim().isEmpty ? defaultPath : path.trim());
  if (route == null || route.hasScheme || route.hasAuthority || route.hasQuery || route.hasFragment) return null;
  final segments = route.pathSegments.where((segment) => segment.isNotEmpty).toList();
  if (segments.isEmpty || segments.any((segment) => segment == '..' || segment == '.')) return null;
  final prefix = base.pathSegments.toList();
  while (prefix.isNotEmpty && prefix.last.isEmpty) {
    prefix.removeLast();
  }
  return base.replace(pathSegments: [...prefix, ...segments]);
}

/// Where a configuration sends data: on this computer for `localhost`, the
/// local network for private addresses and `.local` names, otherwise the
/// internet.
PluginEndpoint openAiCompatibleEndpoint(PluginConfig config) {
  final host = Uri.tryParse(openAiCompatibleUrl(config))?.host.toLowerCase() ?? '';
  return PluginEndpoint(privacyOfHost(host), host);
}

Privacy privacyOfHost(String host) {
  if (host.isEmpty) return Privacy.cloud;
  if (host == 'localhost' || host.endsWith('.localhost') || host == '::1' || host == '[::1]') return Privacy.local;
  final ip = InternetAddress.tryParse(host.replaceAll(RegExp(r'^\[|\]$'), ''));
  if (ip != null) {
    if (ip.isLoopback) return Privacy.local;
    final b = ip.rawAddress;
    if (ip.type == InternetAddressType.IPv4) {
      final private =
          b[0] == 10 ||
          (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
          (b[0] == 192 && b[1] == 168) ||
          (b[0] == 169 && b[1] == 254);
      return private ? Privacy.lan : Privacy.cloud;
    }
    final private = (b[0] & 0xfe) == 0xfc || (b[0] == 0xfe && (b[1] & 0xc0) == 0x80);
    return private ? Privacy.lan : Privacy.cloud;
  }
  if (host.endsWith('.local') || host.endsWith('.lan') || host.endsWith('.home.arpa') || !host.contains('.')) {
    return Privacy.lan;
  }
  return Privacy.cloud;
}

class OpenAiCompatibleTranslator implements Translator {
  OpenAiCompatibleTranslator({
    required this.apiUrl,
    required this.model,
    this.apiKey = '',
    this.temperature = llmDefaultTemperature,
    this.maxTokens = llmDefaultMaxTokens,
    this.tokenLimitParam = 'max_completion_tokens',
    this.timeout = const Duration(seconds: 120),
    this.retryDelays = const [Duration(seconds: 2), Duration(seconds: 6)],
    this.info = openAiCompatibleInfo,
    this.resendMissing = true,
    this.chatPath = '',
    this.requestOptions = '',
    this.comicPrompt = '',
    this.streamChat = false,
    this._httpChat,
    HttpClient Function()? httpClientFactory,
  }) : _httpClientFactory = httpClientFactory ?? _defaultClient;

  final String apiUrl;
  final String model;
  final String apiKey;
  final String chatPath;
  final String requestOptions;
  final String comicPrompt;
  final bool streamChat;
  final HttpRequestSpec? _httpChat;
  late final EditableHttpRequest? _customChat = _httpChat == null
      ? null
      : _parseHttpRequest(HttpOperation.chat, _httpChat);

  /// Bubbles the answer had nothing for are asked once more on their own.
  final bool resendMissing;
  final double temperature;
  final int maxTokens;
  final String tokenLimitParam;
  final Duration timeout;

  /// Pauses before sending again after a temporary failure.
  final List<Duration> retryDelays;
  final HttpClient Function() _httpClientFactory;

  static HttpClient _defaultClient() => HttpClient()..findProxy = HttpClient.findProxyFromEnvironment;

  /// "Own server", or OpenRouter when made by its factory.
  @override
  final PluginInfo info;

  /// The longest answer to ask for [request]: [llmBatchMaxTokens] for several
  /// pages while [maxTokens] is left at its default, else [maxTokens].
  int answerLength(TranslationRequest request) {
    if (maxTokens != llmDefaultMaxTokens) return maxTokens;
    final pages = {for (var i = 0; i < request.blocks.length; i++) request.keyOf(i).split('-').first};
    return pages.length > 1 && request.keys != null ? llmBatchMaxTokens : maxTokens;
  }

  /// Request body (`GPTTranslation._perform_translation`); [length] instead
  /// of [answerLength].
  Map<String, Object?> buildPayload(TranslationRequest request, {int? length}) {
    final standardPrompt = llmSystemPrompt(request.sourceLanguage, request.targetLanguage);
    final system = comicPrompt.trim().isEmpty ? standardPrompt : '$standardPrompt\n\n$comicPrompt';
    final user = llmUserPrompt(request.extraContext, blocksToJson(request.blocks, keys: request.keys));
    final images = [?request.pageImage, ...request.pageImages];
    return {
      if (model.trim().isNotEmpty) 'model': model.trim(),
      'messages': [
        {
          'role': 'system',
          'content': [
            {'type': 'text', 'text': system},
          ],
        },
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': user},
            for (final image in images)
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,${base64Encode(ImageCodec.encodeJpeg(image, quality: 75))}',
                },
              },
          ],
        },
      ],
      'temperature': temperature,
      if (tokenLimitParam != 'none') tokenLimitParam: length ?? answerLength(request),
    };
  }

  Uri chatUri() {
    if (_customChat case final custom?) {
      try {
        return custom.url(apiUrl);
      } on FormatException catch (error) {
        throw TranslationException(error.message, kind: TranslationErrorKind.config);
      }
    }
    final uri = openAiCompatibleUri(apiUrl, chatPath, 'chat/completions');
    if (uri == null) {
      throw TranslationException(
        'set a valid HTTP(S) API base URL and a relative chat endpoint path',
        kind: TranslationErrorKind.config,
      );
    }
    if (info.id == 'openrouter' && model.trim().isEmpty) {
      throw TranslationException(
        'set the model name of the OpenAI-compatible translator',
        kind: TranslationErrorKind.config,
      );
    }
    return uri;
  }

  /// Sends a conversation without adding the comic translation prompt.
  Future<String> testChat(
    List<Map<String, Object?>> messages,
    CancelToken cancel,
    EventLog log, {
    void Function(String)? onRequest,
    void Function(int status, String body)? onResponse,
    void Function(String)? onText,
    List<HttpTemplateFile>? files,
  }) async {
    try {
      final uri = chatUri();
      final payload = _withRequestOptions({
        if (model.trim().isNotEmpty) 'model': model.trim(),
        'messages': messages,
        'temperature': temperature,
        if (tokenLimitParam != 'none') tokenLimitParam: maxTokens,
      });
      final prepared =
          _customChat?.prepare(apiUrl, apiKey, payload, files: files) ??
          (streamChat ? PreparedHttpRequest.openAiChatStream(uri, apiKey, payload) : null);
      onRequest?.call(prepared?.preview ?? 'POST $uri\n${_diagnosticJson(payload)}');
      final partial = StringBuffer();
      final (reply, _, _) = await _postWithRetries(
        uri,
        payload,
        cancel,
        log,
        prepared: prepared,
        onResponse: onResponse,
        onText: onText == null
            ? null
            : (chunk) {
                partial.write(chunk);
                onText(_withoutApiKey(partial.toString()));
              },
      );
      return _withoutApiKey(reply);
    } on TranslationException catch (e) {
      throw TranslationException(
        _withoutApiKey(e.message),
        kind: e.kind,
        statusCode: e.statusCode,
        reply: e.reply == null ? null : _withoutApiKey(e.reply!),
      );
    }
  }

  bool get acceptsTemplateFiles => _customChat?.acceptsFiles ?? false;

  String _withoutApiKey(String text) => apiKey.isEmpty ? text : text.replaceAll(apiKey, '[redacted]');

  String _diagnosticJson(Object? value) {
    Object? clean(Object? value) => switch (value) {
      Map() => {
        for (final entry in value.entries)
          '${entry.key}':
              RegExp(
                r'(authorization|api[_-]?key|password|secret|access[_-]?token|cookie)',
                caseSensitive: false,
              ).hasMatch('${entry.key}')
              ? '[redacted]'
              : clean(entry.value),
      },
      List() => [for (final item in value) clean(item)],
      String() => _diagnosticText(value),
      _ => value,
    };
    return _limitDiagnostic(_withoutApiKey(const JsonEncoder.withIndent('  ').convert(clean(value))));
  }

  String _diagnosticText(String text) => _withoutApiKey(
    text,
  ).replaceAll(RegExp(r'data:image/[^\s;,]+;base64,[A-Za-z0-9+/=_-]+', caseSensitive: false), '[image data omitted]');

  static String _limitDiagnostic(String text) => text.length <= 24000 ? text : '${text.substring(0, 24000)}\n…';

  Map<String, Object?> _withRequestOptions(Map<String, Object?> payload) {
    if (_customChat != null || requestOptions.trim().isEmpty) return payload;
    final Map<String, Object?> extra;
    try {
      extra = RequestTemplate.parseRequestOptions(requestOptions);
    } on FormatException catch (error) {
      throw TranslationException(
        'invalid additional request fields: ${error.message}',
        kind: TranslationErrorKind.config,
      );
    }
    final result = {...payload, ...extra};
    for (final key in extra.keys) {
      if (extra[key] == null) result.remove(key);
    }
    return result;
  }

  @override
  Future<void> translate(TranslationRequest request, PluginContext context) async {
    final uri = chatUri();
    final reply = await _ask(request, context, uri);
    // Bubbles the answer had nothing for: asked once more, on their own. A
    // failed second request keeps what the first one gave.
    final missing = [
      for (final b in request.blocks)
        if (b.untranslated) b,
    ];
    if (resendMissing && missing.isNotEmpty) {
      context.log.child(stage: 'translate').info('translate_resend', {
        'blocks': missing.length,
        'of': request.blocks.length,
      });
      try {
        await _ask(request.only(missing), context, uri, again: true);
      } on TranslationException catch (e) {
        context.log.child(stage: 'translate').warn('translate_resend_failed', {'error': e.message});
      }
    }
    // The original only warns; a page with no translation at all would look
    // done but keep its text, so it is reported instead.
    if (request.blocks.isNotEmpty && request.blocks.every((b) => b.untranslated)) {
      throw NoTranslationsException('the model reply has no translations: ${_clip(reply)}');
    }
  }

  /// One request for [request]'s blocks: the answer goes into them (blocks it
  /// left out are marked untranslated), and into the history. [again]: the
  /// second request for the ones the first answer left out. Returns the
  /// answer.
  Future<String> _ask(TranslationRequest request, PluginContext context, Uri uri, {bool again = false}) async {
    var payload = buildPayload(request);
    final log = context.log.child(stage: 'translate');
    log.info('translate_request', {
      'host': uri.host,
      'model': model,
      'blocks': request.blocks.length,
      'image': request.pageImage != null || request.pageImages.isNotEmpty,
      if (request.pageImages.isNotEmpty) 'images': request.pageImages.length,
      if (again) 'again': true,
    });
    final artifact = again ? 'request_again' : 'request';
    await context.recorder?.writeJsonArtifact(
      '03_translate',
      '$artifact.redacted.json',
      _forArtifact(payload, uri),
      page: context.page,
    );

    final sw = Stopwatch()..start();
    // What the history keeps of this request, whatever comes of it.
    var reply = '';
    var warnings = const <String>[];
    ServiceUsage? used;
    Future<void> keep([String error = '']) => context.reportHistory(
      HistoryEntry(
        time: DateTime.now(),
        plugin: info.id,
        host: uri.host,
        model: model,
        page: context.page ?? '',
        again: again,
        ms: sw.elapsedMilliseconds,
        sent: sentText(payload),
        image: request.pageImage != null || request.pageImages.isNotEmpty,
        reply: reply,
        blocks: request.blocks.length,
        warnings: warnings,
        error: error,
        inputTokens: used?.inputTokens ?? 0,
        outputTokens: used?.outputTokens ?? 0,
        cost: used?.cost,
      ),
    );
    try {
      Map<String, Object?>? usage;
      String? finish;
      try {
        (reply, usage, finish) = await postChat(uri, payload, context.cancel, log);
      } on TranslationException catch (e) {
        // Some servers cap the answer lower (DeepSeek: 8192) and refuse the
        // raised length of a pack: asked once more with the setting's own.
        if (_customChat != null || payload[tokenLimitParam] != llmBatchMaxTokens || !_refusesLength(e)) rethrow;
        log.warn('translate_length_refused', {'tokens': llmBatchMaxTokens, 'error': e.message});
        payload = buildPayload(request, length: maxTokens);
        (reply, usage, finish) = await postChat(uri, payload, context.cancel, log);
      }
      used = usageOf(usage, payload, reply, host: uri.host);
      log.info('translate_response', {
        'ms': sw.elapsedMilliseconds,
        'chars': reply.length,
        'input_tokens': used.inputTokens,
        'output_tokens': used.outputTokens,
        if (used.cost != null) 'cost': used.cost,
        if (used.estimated) 'tokens_estimated': true,
      });
      await context.reportUsage(used);
      await context.recorder?.writeJsonArtifact('03_translate', again ? 'response_again.json' : 'response.json', {
        'content': reply,
      }, page: context.page);

      try {
        warnings = applyTranslationsJson(request.blocks, reply, keys: request.keys);
      } on FormatException catch (e) {
        throw TranslationException(
          'the model reply has broken JSON (${e.message}): ${_clip(reply)}',
          kind: finish == 'length' ? TranslationErrorKind.cutOff : TranslationErrorKind.badReply,
        );
      }
      // Cut off before the closing brace: no JSON at all. Not asked again
      // (the same request would stop at the same place); a pack is split.
      if (finish == 'length' && warnings.contains(noJsonWarning)) {
        throw TranslationException(
          'the answer stopped at the length limit (finish_reason: length): ${_clip(reply)}',
          kind: TranslationErrorKind.cutOff,
        );
      }
      for (final w in warnings) {
        log.warn('translate_reply_warning', {'warning': w});
      }
      await keep();
      return reply;
    } on TranslationException catch (e) {
      // What the server sent, even when it could not be read.
      if (e.reply case final raw? when reply.isEmpty) reply = raw;
      await keep(e.message);
      rethrow;
    }
  }

  /// A refusal of the requested answer length: a 400/422 about tokens.
  static bool _refusesLength(TranslationException e) =>
      (e.statusCode == 400 || e.statusCode == 422) && e.message.toLowerCase().contains('token');

  /// The messages of [payload] as text, for the history: each with its role,
  /// a picture as a note (the picture itself is not kept).
  static String sentText(Map<String, Object?> payload) => [
    for (final m in (payload['messages'] as List? ?? const []).whereType<Map>())
      '[${m['role']}]\n${switch (m['content']) {
        final String text => text,
        final List parts => [for (final part in parts.whereType<Map>()) part['type'] == 'text' ? '${part['text']}' : '<${part['type']}>'].join('\n'),
        _ => '',
      }}',
  ].join('\n\n');

  /// One chat request of [payload] to [uri], sent again after temporary
  /// failures: the answer's text, its `usage` and why it ended. For other
  /// plugins of the same service (reading by the model).
  Future<(String, Map<String, Object?>?, String?)> postChat(
    Uri uri,
    Map<String, Object?> payload,
    CancelToken cancel,
    EventLog log,
  ) => _postWithRetries(uri, _withRequestOptions(payload), cancel, log);

  /// Sends again after temporary failures (rate limit, server error, lost
  /// connection), waiting [retryDelays] (or the server's Retry-After, up to
  /// 30 s) in between. Not in the original, which fails the page at once.
  Future<(String, Map<String, Object?>?, String?)> _postWithRetries(
    Uri uri,
    Map<String, Object?> payload,
    CancelToken cancel,
    EventLog log, {
    void Function(int status, String body)? onResponse,
    void Function(String)? onText,
    PreparedHttpRequest? prepared,
  }) async {
    if (_customChat case final custom?) {
      final request = prepared ?? custom.prepare(apiUrl, apiKey, payload);
      final reply = await request.send(
        timeout: timeout,
        cancel: cancel,
        clientFactory: _httpClientFactory,
        onText: onText,
      );
      if (onResponse != null) onResponse(reply.status, _diagnosticResponse(reply.body));
      return custom.decode(reply, apiKey) as (String, Map<String, Object?>?, String?);
    }
    final streaming = streamChat ? prepared ?? PreparedHttpRequest.openAiChatStream(uri, apiKey, payload) : null;
    var receivedText = false;
    for (var attempt = 0; ; attempt++) {
      try {
        if (streaming == null) return await _post(uri, payload, cancel, onResponse);
        final reply = await streaming.send(
          timeout: timeout,
          cancel: cancel,
          clientFactory: _httpClientFactory,
          onText: (chunk) {
            receivedText = true;
            onText?.call(chunk);
          },
        );
        onResponse?.call(reply.status, _diagnosticResponse(reply.body));
        return streaming.decodeOpenAiChatStream(reply);
      } on TranslationException catch (e) {
        if (receivedText || !e.kind.isTemporary || attempt >= retryDelays.length) rethrow;
        final wait = e is _RetryAfter && e.retryAfter != null
            ? (e.retryAfter! > const Duration(seconds: 30) ? const Duration(seconds: 30) : e.retryAfter!)
            : retryDelays[attempt];
        log.warn('translate_retry', {'attempt': attempt + 1, 'kind': e.kind.name, 'wait_ms': wait.inMilliseconds});
        await Future.any([Future<void>.delayed(wait), _cancelled(cancel)]);
        cancel.throwIfCancelled();
      }
    }
  }

  static Future<void> _cancelled(CancelToken cancel) {
    final done = Completer<void>();
    cancel.onCancel(() {
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }

  Future<(String, Map<String, Object?>?, String?)> _post(
    Uri uri,
    Map<String, Object?> payload,
    CancelToken cancel,
    void Function(int status, String body)? onResponse,
  ) async {
    final client = _httpClientFactory()..connectionTimeout = timeout;
    if (!identical(cancel, CancelToken.none)) cancel.onCancel(() => client.close(force: true));
    try {
      final req = await client.postUrl(uri).timeout(timeout);
      req.headers.contentType = ContentType.json;
      if (apiKey.isNotEmpty) req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      final bytes = utf8.encode(jsonEncode(payload));
      req.contentLength = bytes.length; // some servers reject chunked request bodies
      req.add(bytes);
      final res = await req.close().timeout(timeout);
      final body = await res.transform(utf8.decoder).join().timeout(timeout);
      if (onResponse != null) onResponse(res.statusCode, _diagnosticResponse(body));
      return _parseResponse(uri, res, body);
    } on TimeoutException {
      cancel.throwIfCancelled();
      throw TranslationException(
        '${uri.host} did not answer within ${timeout.inSeconds} s',
        kind: TranslationErrorKind.timeout,
      );
    } on SocketException catch (e) {
      cancel.throwIfCancelled();
      throw TranslationException(
        'cannot connect to ${uri.host}: ${e.osError?.message ?? e.message}',
        kind: TranslationErrorKind.network,
      );
    } on HttpException catch (e) {
      cancel.throwIfCancelled();
      throw TranslationException('connection to ${uri.host} failed: ${e.message}', kind: TranslationErrorKind.network);
    } on TlsException catch (e) {
      // An antivirus or a proxy in between, a wrong clock.
      cancel.throwIfCancelled();
      throw TranslationException(
        'the secure connection to ${uri.host} broke off: ${e.message}',
        kind: TranslationErrorKind.network,
      );
    } finally {
      client.close(force: true);
    }
  }

  String _diagnosticResponse(String body) {
    try {
      return _diagnosticJson(jsonDecode(body));
    } on FormatException {
      // Non-JSON replies are often proxy error pages.
      return _limitDiagnostic(_diagnosticText(body));
    }
  }

  (String, Map<String, Object?>?, String?) _parseResponse(Uri uri, HttpClientResponse res, String body) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final detail = _errorDetail(_withoutApiKey(body));
      final seconds = int.tryParse(res.headers.value('retry-after') ?? '');
      throw _RetryAfter(
        '${uri.host} answered HTTP ${res.statusCode}$detail',
        kind: TranslationErrorKind.forStatus(res.statusCode, detail),
        statusCode: res.statusCode,
        retryAfter: seconds == null ? null : Duration(seconds: seconds),
      );
    }
    return _content(body);
  }

  /// What a request used: the `usage` of the reply (tokens, and the cost on
  /// OpenRouter), or about 4 characters per token when the server sent none
  /// (some local servers).
  ServiceUsage usageOf(
    Map<String, Object?>? usage,
    Map<String, Object?> payload,
    String reply, {
    required String host,
  }) {
    int? count(String key) => (usage?[key] as num?)?.toInt();
    final input = count('prompt_tokens'), output = count('completion_tokens');
    final cost = (usage?['cost'] as num?)?.toDouble();
    if (input != null && output != null) {
      return ServiceUsage(
        plugin: info.id,
        host: host,
        model: model,
        inputTokens: input,
        outputTokens: output,
        cost: cost,
      );
    }
    var chars = 0;
    for (final message in payload['messages'] as List) {
      for (final part in (message as Map)['content'] as List) {
        if (part is Map && part['text'] is String) chars += (part['text'] as String).length;
      }
    }
    return ServiceUsage(
      plugin: info.id,
      host: host,
      model: model,
      inputTokens: (chars / 4).ceil(),
      outputTokens: (reply.length / 4).ceil(),
      cost: cost,
      estimated: true,
    );
  }

  /// `response["choices"][0]["message"]["content"]` (text parts joined when
  /// a server returns structured content), the reply's `usage` and why it
  /// ended (`length`: at the length limit). OpenRouter sends blank lines
  /// while the model works; an error of the provider may come inside the
  /// choice. Errors carry the whole [body] for the history.
  static (String, Map<String, Object?>?, String?) _content(String body) {
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      throw TranslationException(
        'the server reply is not JSON: ${_clip(body.trim())}',
        kind: TranslationErrorKind.badReply,
        reply: body.trim(),
      );
    }
    final choices = json is Map ? json['choices'] : null;
    final choice = choices is List && choices.isNotEmpty && choices.first is Map ? choices.first as Map : null;
    final message = choice?['message'];
    final content = message is Map ? message['content'] : null;
    final finish = choice?['finish_reason'] as String?;
    final usage = json is Map && json['usage'] is Map ? (json['usage'] as Map).cast<String, Object?>() : null;
    final text = switch (content) {
      final String text => text,
      final List parts => [
        for (final part in parts)
          if (part is Map && part['text'] is String) part['text'] as String,
      ].join(),
      _ => null,
    };
    if (text != null && text.trim().isNotEmpty) return (text, usage, finish);
    final error = choice?['error'] ?? (json is Map ? json['error'] : null);
    if (error is Map) {
      final code = (error['code'] as num?)?.toInt() ?? 0;
      final detail = '${error['message'] ?? ''}';
      throw TranslationException(
        'the provider failed: $detail',
        kind: TranslationErrorKind.forStatus(code, detail),
        statusCode: code == 0 ? null : code,
        reply: body.trim(),
      );
    }
    if (finish == 'length') {
      throw TranslationException(
        'the answer stopped at the length limit before any text (finish_reason: length)',
        kind: TranslationErrorKind.cutOff,
        reply: body.trim(),
      );
    }
    if (text != null) return (text, usage, finish);
    throw TranslationException(
      'unexpected reply format: ${_clip(body.trim())}',
      kind: TranslationErrorKind.badReply,
      reply: body.trim(),
    );
  }

  static String _errorDetail(String body) {
    try {
      final json = jsonDecode(body);
      final error = json is Map ? json['error'] : null;
      final message = error is Map ? error['message'] : error;
      if (message is String && message.isNotEmpty) return ': $message';
    } on FormatException {
      // not JSON
    }
    return body.trim().isEmpty ? '' : ': ${_clip(body)}';
  }

  static String _clip(String s) => s.length <= 300 ? s : '${s.substring(0, 300)}…';

  /// The payload for test-mode artifacts: images replaced by their size.
  static Map<String, Object?> _forArtifact(Map<String, Object?> payload, Uri uri) {
    Object? strip(Object? v) {
      if (v is Map) {
        return {
          for (final e in v.entries)
            e.key: e.key == 'url' && e.value is String && (e.value as String).startsWith('data:')
                ? '<image, ${(e.value as String).length} base64 chars>'
                : strip(e.value),
        };
      }
      if (v is List) return [for (final x in v) strip(x)];
      return v;
    }

    return {'endpoint': uri.toString(), 'payload': strip(payload)};
  }

  @override
  Future<void> dispose() async {}
}

/// An HTTP error that may carry the server's Retry-After.
class _RetryAfter extends TranslationException {
  _RetryAfter(super.message, {super.kind, super.statusCode, this.retryAfter});

  final Duration? retryAfter;
}

KeyStatusQuery? openAiCompatibleKeyStatus(PluginConfig config, {String? baseUrl}) {
  final base = baseUrl ?? openAiCompatibleUrl(config);
  final key = config.secret('api_key') ?? '';
  if (httpRequestSpec(config, HttpOperation.keyStatus) case final spec?) {
    return KeyStatusQuery(
      host: Uri.tryParse(base)?.host ?? '',
      hasKey: key.isNotEmpty,
      custom: true,
      run: () => _runHttpOperation<KeyStatus>(HttpOperation.keyStatus, spec, base, key),
    );
  }
  final path = config.values[RequestTemplate.keyStatusPathKey] as String? ?? '';
  if (path.isEmpty) return isOpenRouterUrl(base) ? openRouterKeyQuery(base, key) : null;
  final uri = openAiCompatibleUri(base, path, path);
  if (uri == null) return null;
  return KeyStatusQuery(
    host: uri.host,
    hasKey: key.isNotEmpty,
    custom: true,
    run: () => _fetchTemplateKeyStatus(uri, key, config.value<String>(RequestTemplate.keyStatusFieldsKey)),
  );
}

Future<KeyStatus> _fetchTemplateKeyStatus(Uri uri, String key, String fieldsJson) async {
  final fields = RequestTemplate.parseKeyStatusFields(fieldsJson);
  if (fields == null || fields.isEmpty) {
    throw TranslationException('configure fields for the key status response', kind: TranslationErrorKind.config);
  }
  final json = await _openAiCompatibleGet(uri, apiKey: key, timeout: const Duration(seconds: 20), unwrapData: false);
  final redactor = Redactor(secrets: [key]);
  String safe(String text) {
    final masked = redactor.redact(key.isEmpty ? text : text.replaceAll(key, Redactor.mask));
    return masked.length > 240 ? '${masked.substring(0, 240)}…' : masked;
  }

  final values = <String, String>{};
  for (final entry in fields.entries) {
    Object? value = json;
    for (final part in entry.value.split('.')) {
      value = value is Map ? value[part] : null;
    }
    if (value is String) {
      values[safe(entry.key)] = safe(value);
    } else if (value is num || value is bool) {
      values[safe(entry.key)] = '$value';
    }
  }
  if (values.isEmpty) {
    throw TranslationException('no matching fields in the key status response', kind: TranslationErrorKind.badReply);
  }
  return KeyStatus(fields: Map.unmodifiable(values));
}

/// The API of OpenRouter at [base] (`https://openrouter.ai/api/v1`).
bool isOpenRouterUrl(String base) => Uri.tryParse(base)?.host.toLowerCase() == 'openrouter.ai';

/// Asking OpenRouter at [base] about [key].
KeyStatusQuery openRouterKeyQuery(String base, String key) => KeyStatusQuery(
  host: Uri.parse(base).host,
  hasKey: key.isNotEmpty,
  run: () => fetchOpenRouterKeyStatus(Uri.parse('$base/key'), key),
);

/// `GET /api/v1/key` of OpenRouter: the key's limit, spending and the free
/// model requests of the day.
Future<KeyStatus> fetchOpenRouterKeyStatus(
  Uri uri,
  String apiKey, {
  Duration timeout = const Duration(seconds: 20),
  HttpClient Function()? httpClientFactory,
}) async {
  final data = await _openAiCompatibleGet(uri, apiKey: apiKey, timeout: timeout, httpClientFactory: httpClientFactory);
  if (data is! Map) {
    throw TranslationException(
      'unexpected reply format: ${OpenAiCompatibleTranslator._clip('$data')}',
      kind: TranslationErrorKind.badReply,
    );
  }
  return parseOpenRouterKeyStatus(data.cast<String, Object?>());
}

/// Uses the same endpoint and credentials as the configured profile.
ModelCatalogQuery? openAiCompatibleModelCatalog(PluginConfig config, {String? baseUrl}) {
  final base = baseUrl ?? openAiCompatibleUrl(config);
  final key = config.secret('api_key');
  if (httpRequestSpec(config, HttpOperation.models) case final spec?) {
    return ModelCatalogQuery(
      host: Uri.tryParse(base)?.host ?? '',
      settingKey: 'model',
      usesProfileCredentials: true,
      run: () => _runHttpOperation<List<CatalogModel>>(HttpOperation.models, spec, base, key ?? ''),
    );
  }
  final uri = openAiCompatibleUri(base, config.value<String>('models_path'), 'models');
  if (uri == null) return null;
  return ModelCatalogQuery(
    host: uri.host,
    settingKey: 'model',
    usesProfileCredentials: true,
    run: () => fetchOpenAiCompatibleModels(uri, apiKey: key),
  );
}

EditableHttpRequest _parseHttpRequest(
  HttpOperation operation,
  HttpRequestSpec spec, {
  bool openRouterModelDefaults = false,
}) {
  try {
    return EditableHttpRequest.parse(operation, spec, openRouterModelDefaults: openRouterModelDefaults);
  } on FormatException catch (error) {
    throw TranslationException('invalid HTTP template: ${error.message}', kind: TranslationErrorKind.config);
  }
}

Future<T> _runHttpOperation<T>(HttpOperation operation, HttpRequestSpec spec, String base, String key) async {
  final operationRequest = _parseHttpRequest(operation, spec, openRouterModelDefaults: isOpenRouterUrl(base));
  try {
    final request = operationRequest.prepare(base, key, const {});
    final reply = await request.send(timeout: const Duration(seconds: 30));
    return operationRequest.decode(reply, key) as T;
  } on FormatException catch (error) {
    throw TranslationException('invalid HTTP template: ${error.message}', kind: TranslationErrorKind.config);
  }
}

Future<List<CatalogModel>> fetchOpenAiCompatibleModels(
  Uri uri, {
  String? apiKey,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final data = await _openAiCompatibleGet(uri, apiKey: apiKey, timeout: timeout);
  if (data is! List) {
    throw TranslationException('expected a list of models in data', kind: TranslationErrorKind.badReply);
  }
  return [
    for (final entry in data.whereType<Map>())
      if (entry['id'] case final String id when id.trim().isNotEmpty)
        CatalogModel(
          id: id,
          name: entry['name'] is String ? entry['name'] as String : '',
          vision: _modalities(entry, 'input_modalities', 'image'),
        ),
  ];
}

/// The model list of OpenRouter at [base].
ModelCatalogQuery openRouterModelQuery(String base) => ModelCatalogQuery(
  host: Uri.parse(base).host,
  settingKey: 'model',
  run: () => fetchOpenRouterModels(Uri.parse('$base/models')),
);

/// `GET /api/v1/models` of OpenRouter: every model with its prices.
Future<List<CatalogModel>> fetchOpenRouterModels(
  Uri uri, {
  Duration timeout = const Duration(seconds: 30),
  HttpClient Function()? httpClientFactory,
}) async {
  final data = await _openAiCompatibleGet(uri, timeout: timeout, httpClientFactory: httpClientFactory);
  if (data is! List) {
    throw TranslationException(
      'unexpected reply format: ${OpenAiCompatibleTranslator._clip('$data')}',
      kind: TranslationErrorKind.badReply,
    );
  }
  return parseOpenRouterModels(data);
}

/// The `data` of OpenRouter's model list: models that answer with text.
/// Prices come per token as strings; a negative one means "it depends".
List<CatalogModel> parseOpenRouterModels(List<Object?> data) {
  return [
    for (final m in data.whereType<Map>())
      if (m['id'] is String && _modalities(m, 'output_modalities', 'text'))
        CatalogModel(
          id: m['id'] as String,
          name: m['name'] as String? ?? '',
          description: m['description'] as String? ?? '',
          contextLength: (m['context_length'] as num?)?.toInt(),
          promptPrice: modelPricePerMillion((m['pricing'] as Map?)?['prompt']),
          completionPrice: modelPricePerMillion((m['pricing'] as Map?)?['completion']),
          vision: _modalities(m, 'input_modalities', 'image'),
          created: m['created'] is num
              ? DateTime.fromMillisecondsSinceEpoch((m['created'] as num).toInt() * 1000, isUtc: true)
              : null,
        ),
  ];
}

/// Whether the model's [kind] modalities have [what]; older replies only
/// have `modality` like `text+image->text`.
bool _modalities(Map<Object?, Object?> model, String kind, String what) {
  final arch = model['architecture'];
  if (arch is! Map) return what == 'text';
  final list = arch[kind];
  if (list is List) return list.contains(what);
  final modality = arch['modality'];
  if (modality is! String) return what == 'text';
  final parts = modality.split('->');
  final side = kind == 'input_modalities' ? parts.first : parts.last;
  return side.split('+').contains(what);
}

/// A GET of the API: the `data` of its JSON reply. The key goes
/// along only when given.
Future<Object?> _openAiCompatibleGet(
  Uri uri, {
  String? apiKey,
  required Duration timeout,
  HttpClient Function()? httpClientFactory,
  bool unwrapData = true,
}) async {
  final client = (httpClientFactory ?? OpenAiCompatibleTranslator._defaultClient)()..connectionTimeout = timeout;
  try {
    final req = await client.getUrl(uri).timeout(timeout);
    req.followRedirects = false;
    if (apiKey != null && apiKey.isNotEmpty) req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    final res = await req.close().timeout(timeout);
    final body = await res.transform(utf8.decoder).join().timeout(timeout);
    String safeBody() => apiKey == null || apiKey.isEmpty ? body : body.replaceAll(apiKey, '[redacted]');
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final detail = OpenAiCompatibleTranslator._errorDetail(safeBody());
      throw TranslationException(
        '${uri.host} answered HTTP ${res.statusCode}$detail',
        kind: TranslationErrorKind.forStatus(res.statusCode, detail),
        statusCode: res.statusCode,
      );
    }
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      throw TranslationException(
        'the server reply is not JSON: ${OpenAiCompatibleTranslator._clip(safeBody())}',
        kind: TranslationErrorKind.badReply,
      );
    }
    if (!unwrapData) return json;
    if (json is! Map || !json.containsKey('data')) {
      throw TranslationException(
        'unexpected reply format: ${OpenAiCompatibleTranslator._clip(safeBody())}',
        kind: TranslationErrorKind.badReply,
      );
    }
    return json['data'];
  } on TimeoutException {
    throw TranslationException(
      '${uri.host} did not answer within ${timeout.inSeconds} s',
      kind: TranslationErrorKind.timeout,
    );
  } on SocketException catch (e) {
    throw TranslationException(
      'cannot connect to ${uri.host}: ${e.osError?.message ?? e.message}',
      kind: TranslationErrorKind.network,
    );
  } on HttpException catch (e) {
    throw TranslationException('connection to ${uri.host} failed: ${e.message}', kind: TranslationErrorKind.network);
  } on TlsException catch (e) {
    throw TranslationException(
      'the secure connection to ${uri.host} broke off: ${e.message}',
      kind: TranslationErrorKind.network,
    );
  } finally {
    client.close(force: true);
  }
}

/// The `data` of OpenRouter's key reply. A key without its own limit may
/// still be capped by a budget (`effective_budget`).
KeyStatus parseOpenRouterKeyStatus(Map<String, Object?> data) {
  double? number(Object? v) => (v as num?)?.toDouble();
  final budget = data['effective_budget'] is Map ? (data['effective_budget'] as Map).cast<String, Object?>() : null;
  final free = data['free_model_daily_requests'] is Map
      ? (data['free_model_daily_requests'] as Map).cast<String, Object?>()
      : null;
  final reset = data['limit'] != null ? data['limit_reset'] : budget?['reset_interval'];
  return KeyStatus(
    limit: number(data['limit']) ?? number(budget?['limit_usd']),
    remaining: number(data['limit_remaining']) ?? number(budget?['remaining_usd']),
    used: number(data['usage']) ?? 0,
    usedToday: number(data['usage_daily']) ?? 0,
    usedThisMonth: number(data['usage_monthly']) ?? 0,
    limitReset: switch (reset) {
      'daily' => LimitReset.daily,
      'weekly' => LimitReset.weekly,
      'monthly' => LimitReset.monthly,
      _ => null,
    },
    freeRequestsToday: (free?['used'] as num?)?.toInt(),
    freeRequestsLimit: (free?['limit'] as num?)?.toInt(),
    freeRequestsLeft: (free?['remaining'] as num?)?.toInt(),
    label: data['label'] as String? ?? '',
    freeTier: data['is_free_tier'] as bool?,
  );
}
