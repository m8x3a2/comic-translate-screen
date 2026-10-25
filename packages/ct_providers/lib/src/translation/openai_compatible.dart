/// Any OpenAI-compatible chat completions API (OpenRouter, OpenAI, DeepSeek,
/// LM Studio, Ollama, llama.cpp server, ...). Port of the original's
/// `Custom` translator (`modules/translation/llm/custom.py` over `gpt.py`).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ct_core/ct_core.dart';

const openAiCompatibleInfo = PluginInfo(
  id: 'openai_compatible',
  displayName: 'OpenAI-compatible API',
  description: 'Translates with a large language model through any OpenAI-compatible server: '
      'OpenRouter, OpenAI, DeepSeek, or a local LM Studio / Ollama / llama.cpp server.',
  kind: PluginKind.translator,
  privacy: Privacy.cloud,
  settings: [
    TextSetting(
      key: 'api_url',
      label: 'API URL',
      help: 'Base URL ending in /v1, e.g. https://openrouter.ai/api/v1 or http://localhost:11434/v1 (Ollama).',
      placeholder: 'https://openrouter.ai/api/v1',
      isUrl: true,
    ),
    TextSetting(key: 'model', label: 'Model', placeholder: 'openai/gpt-4.1-mini'),
    SecretSetting(key: 'api_key', label: 'API key', help: 'Not needed for most local servers.', optional: true),
    DoubleSetting(
      key: 'temperature',
      label: 'Temperature',
      info: 'How freely the model picks words. Lower is more exact and repeatable, higher more varied but with '
          'more mistakes. For translation usually 0 to 1.',
      defaultValue: llmDefaultTemperature,
      min: 0,
      max: 2,
    ),
    IntSetting(
      key: 'max_tokens',
      label: 'Maximum answer length (tokens)',
      info: 'The longest answer the model may give. Raise it if a page translation is cut off. '
          'A token is about 3-4 letters.',
      defaultValue: llmDefaultMaxTokens,
      min: 64,
      max: 200000,
    ),
    ChoiceSetting(
      key: 'token_limit_param',
      label: 'Length limit parameter',
      help: 'Name of the length limit field the server expects. Use max_tokens for older servers, none to omit it.',
      options: {'max_completion_tokens': 'max_completion_tokens', 'max_tokens': 'max_tokens', 'none': 'none'},
      defaultValue: 'max_completion_tokens',
    ),
    IntSetting(
      key: 'timeout',
      label: 'Timeout (seconds)',
      info: 'How long to wait for the server. Slow free models and local servers on a weak computer can take long.',
      defaultValue: 120,
      min: 5,
      max: 3600,
    ),
  ],
  endpoint: openAiCompatibleEndpoint,
  keyStatus: openAiCompatibleKeyStatus,
  modelCatalog: openAiCompatibleModelCatalog,
);

final openAiCompatibleFactory = PluginFactory<Translator>(openAiCompatibleInfo, (config, env) async {
  return OpenAiCompatibleTranslator(
    apiUrl: config.value<String>('api_url'),
    model: config.value<String>('model'),
    apiKey: config.secret('api_key') ?? '',
    temperature: config.value<double>('temperature'),
    maxTokens: config.value<int>('max_tokens'),
    tokenLimitParam: config.value<String>('token_limit_param'),
    timeout: Duration(seconds: config.value<int>('timeout')),
  );
});

/// Where a configuration sends data: on this computer for `localhost`, the
/// local network for private addresses and `.local` names, otherwise the
/// internet.
PluginEndpoint openAiCompatibleEndpoint(PluginConfig config) {
  final host = Uri.tryParse(config.value<String>('api_url').trim())?.host.toLowerCase() ?? '';
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
      final private = b[0] == 10 ||
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
    HttpClient Function()? httpClientFactory,
  }) : _httpClientFactory = httpClientFactory ?? _defaultClient;

  final String apiUrl;
  final String model;
  final String apiKey;
  final double temperature;
  final int maxTokens;
  final String tokenLimitParam;
  final Duration timeout;

  /// Pauses before sending again after a temporary failure.
  final List<Duration> retryDelays;
  final HttpClient Function() _httpClientFactory;

  static HttpClient _defaultClient() => HttpClient()..findProxy = HttpClient.findProxyFromEnvironment;

  @override
  PluginInfo get info => openAiCompatibleInfo;

  /// Request body (`GPTTranslation._perform_translation`).
  Map<String, Object?> buildPayload(TranslationRequest request) {
    final system = llmSystemPrompt(request.sourceLanguage, request.targetLanguage);
    final user = llmUserPrompt(request.extraContext, blocksToJson(request.blocks));
    final image = request.pageImage;
    return {
      'model': model,
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
            if (image != null)
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,${base64Encode(ImageCodec.encodeJpeg(image, quality: 75))}'},
              },
          ],
        },
      ],
      'temperature': temperature,
      if (tokenLimitParam != 'none') tokenLimitParam: maxTokens,
    };
  }

  @override
  Future<void> translate(TranslationRequest request, PluginContext context) async {
    final base = apiUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.tryParse('$base/chat/completions');
    if (base.isEmpty || uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw TranslationException('set the API URL of the OpenAI-compatible translator (e.g. https://openrouter.ai/api/v1)',
          kind: TranslationErrorKind.config);
    }
    if (model.trim().isEmpty) {
      throw TranslationException('set the model name of the OpenAI-compatible translator', kind: TranslationErrorKind.config);
    }

    final payload = buildPayload(request);
    final log = context.log.child(stage: 'translate');
    log.info('translate_request', {
      'host': uri.host,
      'model': model,
      'blocks': request.blocks.length,
      'image': request.pageImage != null,
    });
    await context.recorder?.writeJsonArtifact('03_translate', 'request.redacted.json', _forArtifact(payload, uri),
        page: context.page);

    final sw = Stopwatch()..start();
    final (reply, usage) = await _postWithRetries(uri, payload, context.cancel, log);
    final used = usageOf(usage, payload, reply, host: uri.host);
    log.info('translate_response', {
      'ms': sw.elapsedMilliseconds,
      'chars': reply.length,
      'input_tokens': used.inputTokens,
      'output_tokens': used.outputTokens,
      if (used.cost != null) 'cost': used.cost,
      if (used.estimated) 'tokens_estimated': true,
    });
    await context.reportUsage(used);
    await context.recorder?.writeJsonArtifact('03_translate', 'response.json', {'content': reply}, page: context.page);

    final List<String> warnings;
    try {
      warnings = applyTranslationsJson(request.blocks, reply);
    } on FormatException catch (e) {
      throw TranslationException('the model reply has broken JSON (${e.message}): ${_clip(reply)}',
          kind: TranslationErrorKind.badReply);
    }
    for (final w in warnings) {
      log.warn('translate_reply_warning', {'warning': w});
    }
    // The original only warns; a page with no translation at all would look
    // done but keep its text removed, so it is reported instead.
    final nothing = warnings.length >= request.blocks.length || warnings.contains(noJsonWarning);
    if (request.blocks.isNotEmpty && nothing) {
      throw TranslationException('the model reply has no translations: ${_clip(reply)}', kind: TranslationErrorKind.badReply);
    }
  }

  /// Sends again after temporary failures (rate limit, server error, lost
  /// connection), waiting [retryDelays] (or the server's Retry-After, up to
  /// 30 s) in between. Not in the original, which fails the page at once.
  Future<(String, Map<String, Object?>?)> _postWithRetries(Uri uri, Map<String, Object?> payload, CancelToken cancel, EventLog log) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await _post(uri, payload, cancel);
      } on TranslationException catch (e) {
        if (!e.kind.isTemporary || attempt >= retryDelays.length) rethrow;
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

  Future<(String, Map<String, Object?>?)> _post(Uri uri, Map<String, Object?> payload, CancelToken cancel) async {
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
      if (res.statusCode < 200 || res.statusCode >= 300) {
        final detail = _errorDetail(body);
        final seconds = int.tryParse(res.headers.value('retry-after') ?? '');
        throw _RetryAfter(
          '${uri.host} answered HTTP ${res.statusCode}$detail',
          kind: TranslationErrorKind.forStatus(res.statusCode, detail),
          statusCode: res.statusCode,
          retryAfter: seconds == null ? null : Duration(seconds: seconds),
        );
      }
      return _content(body);
    } on TimeoutException {
      cancel.throwIfCancelled();
      throw TranslationException('${uri.host} did not answer within ${timeout.inSeconds} s', kind: TranslationErrorKind.timeout);
    } on SocketException catch (e) {
      cancel.throwIfCancelled();
      throw TranslationException('cannot connect to ${uri.host}: ${e.osError?.message ?? e.message}',
          kind: TranslationErrorKind.network);
    } on HttpException catch (e) {
      cancel.throwIfCancelled();
      throw TranslationException('connection to ${uri.host} failed: ${e.message}', kind: TranslationErrorKind.network);
    } finally {
      client.close(force: true);
    }
  }

  /// What a request used: the `usage` of the reply (tokens, and the cost on
  /// OpenRouter), or about 4 characters per token when the server sent none
  /// (some local servers).
  ServiceUsage usageOf(Map<String, Object?>? usage, Map<String, Object?> payload, String reply, {required String host}) {
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
  /// a server returns structured content) and the reply's `usage`.
  static (String, Map<String, Object?>?) _content(String body) {
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      throw TranslationException('the server reply is not JSON: ${_clip(body)}', kind: TranslationErrorKind.badReply);
    }
    final choices = json is Map ? json['choices'] : null;
    final message = choices is List && choices.isNotEmpty && choices.first is Map ? (choices.first as Map)['message'] : null;
    final content = message is Map ? message['content'] : null;
    final usage = json is Map && json['usage'] is Map ? (json['usage'] as Map).cast<String, Object?>() : null;
    if (content is String) return (content, usage);
    if (content is List) {
      final text = [for (final part in content) if (part is Map && part['text'] is String) part['text'] as String].join();
      return (text, usage);
    }
    throw TranslationException('unexpected reply format: ${_clip(body)}', kind: TranslationErrorKind.badReply);
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

/// OpenRouter tells what is left of a key's limit; other servers have no
/// such request.
KeyStatusQuery? openAiCompatibleKeyStatus(PluginConfig config) {
  final base = config.value<String>('api_url').trim().replaceAll(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(base);
  if (uri == null || uri.host.toLowerCase() != 'openrouter.ai') return null;
  final key = config.secret('api_key') ?? '';
  return KeyStatusQuery(
    host: uri.host,
    hasKey: key.isNotEmpty,
    run: () => fetchOpenRouterKeyStatus(Uri.parse('$base/key'), key),
  );
}

/// `GET /api/v1/key` of OpenRouter: the key's limit, spending and the free
/// model requests of the day.
Future<KeyStatus> fetchOpenRouterKeyStatus(
  Uri uri,
  String apiKey, {
  Duration timeout = const Duration(seconds: 20),
  HttpClient Function()? httpClientFactory,
}) async {
  final data = await _openRouterGet(uri, apiKey: apiKey, timeout: timeout, httpClientFactory: httpClientFactory);
  if (data is! Map) {
    throw TranslationException('unexpected reply format: ${OpenAiCompatibleTranslator._clip('$data')}',
        kind: TranslationErrorKind.badReply);
  }
  return parseOpenRouterKeyStatus(data.cast<String, Object?>());
}

/// The models OpenRouter offers can be listed (no key needed); other
/// servers are not asked.
ModelCatalogQuery? openAiCompatibleModelCatalog(PluginConfig config) {
  final base = config.value<String>('api_url').trim().replaceAll(RegExp(r'/+$'), '');
  final uri = Uri.tryParse(base);
  if (uri == null || uri.host.toLowerCase() != 'openrouter.ai') return null;
  return ModelCatalogQuery(
    host: uri.host,
    settingKey: 'model',
    run: () => fetchOpenRouterModels(Uri.parse('$base/models')),
  );
}

/// `GET /api/v1/models` of OpenRouter: every model with its prices.
Future<List<CatalogModel>> fetchOpenRouterModels(
  Uri uri, {
  Duration timeout = const Duration(seconds: 30),
  HttpClient Function()? httpClientFactory,
}) async {
  final data = await _openRouterGet(uri, timeout: timeout, httpClientFactory: httpClientFactory);
  if (data is! List) {
    throw TranslationException('unexpected reply format: ${OpenAiCompatibleTranslator._clip('$data')}',
        kind: TranslationErrorKind.badReply);
  }
  return parseOpenRouterModels(data);
}

/// The `data` of OpenRouter's model list: models that answer with text.
/// Prices come per token as strings; a negative one means "it depends".
List<CatalogModel> parseOpenRouterModels(List<Object?> data) {
  double? perMillion(Object? v) {
    final price = v is num ? v.toDouble() : double.tryParse('$v');
    return price == null || price < 0 ? null : price * 1000000;
  }

  return [
    for (final m in data.whereType<Map>())
      if (m['id'] is String && _modalities(m, 'output_modalities', 'text'))
        CatalogModel(
          id: m['id'] as String,
          name: m['name'] as String? ?? '',
          description: m['description'] as String? ?? '',
          contextLength: (m['context_length'] as num?)?.toInt(),
          promptPrice: perMillion((m['pricing'] as Map?)?['prompt']),
          completionPrice: perMillion((m['pricing'] as Map?)?['completion']),
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

/// A GET of OpenRouter's API: the `data` of its JSON reply. The key goes
/// along only when given.
Future<Object?> _openRouterGet(
  Uri uri, {
  String? apiKey,
  required Duration timeout,
  HttpClient Function()? httpClientFactory,
}) async {
  final client = (httpClientFactory ?? OpenAiCompatibleTranslator._defaultClient)()..connectionTimeout = timeout;
  try {
    final req = await client.getUrl(uri).timeout(timeout);
    if (apiKey != null) req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    final res = await req.close().timeout(timeout);
    final body = await res.transform(utf8.decoder).join().timeout(timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final detail = OpenAiCompatibleTranslator._errorDetail(body);
      throw TranslationException('${uri.host} answered HTTP ${res.statusCode}$detail',
          kind: TranslationErrorKind.forStatus(res.statusCode, detail), statusCode: res.statusCode);
    }
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      throw TranslationException('the server reply is not JSON: ${OpenAiCompatibleTranslator._clip(body)}',
          kind: TranslationErrorKind.badReply);
    }
    if (json is! Map || !json.containsKey('data')) {
      throw TranslationException('unexpected reply format: ${OpenAiCompatibleTranslator._clip(body)}',
          kind: TranslationErrorKind.badReply);
    }
    return json['data'];
  } on TimeoutException {
    throw TranslationException('${uri.host} did not answer within ${timeout.inSeconds} s', kind: TranslationErrorKind.timeout);
  } on SocketException catch (e) {
    throw TranslationException('cannot connect to ${uri.host}: ${e.osError?.message ?? e.message}',
        kind: TranslationErrorKind.network);
  } on HttpException catch (e) {
    throw TranslationException('connection to ${uri.host} failed: ${e.message}', kind: TranslationErrorKind.network);
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
