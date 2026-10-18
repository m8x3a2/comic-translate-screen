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
    DoubleSetting(key: 'temperature', label: 'Temperature', defaultValue: llmDefaultTemperature, min: 0, max: 2),
    IntSetting(key: 'max_tokens', label: 'Maximum answer length (tokens)', defaultValue: llmDefaultMaxTokens, min: 64, max: 200000),
    ChoiceSetting(
      key: 'token_limit_param',
      label: 'Length limit parameter',
      help: 'Name of the length limit field the server expects. Use max_tokens for older servers, none to omit it.',
      options: {'max_completion_tokens': 'max_completion_tokens', 'max_tokens': 'max_tokens', 'none': 'none'},
      defaultValue: 'max_completion_tokens',
    ),
    IntSetting(key: 'timeout', label: 'Timeout (seconds)', defaultValue: 120, min: 5, max: 3600),
  ],
  endpoint: openAiCompatibleEndpoint,
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

class TranslationException implements Exception {
  TranslationException(this.message);

  final String message;

  @override
  String toString() => 'Translation failed: $message';
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
    HttpClient Function()? httpClientFactory,
  }) : _httpClientFactory = httpClientFactory ?? _defaultClient;

  final String apiUrl;
  final String model;
  final String apiKey;
  final double temperature;
  final int maxTokens;
  final String tokenLimitParam;
  final Duration timeout;
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
      throw TranslationException('set the API URL of the OpenAI-compatible translator (e.g. https://openrouter.ai/api/v1)');
    }
    if (model.trim().isEmpty) throw TranslationException('set the model name of the OpenAI-compatible translator');

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
    final reply = await _post(uri, payload, context.cancel);
    log.info('translate_response', {'ms': sw.elapsedMilliseconds, 'chars': reply.length});
    await context.recorder?.writeJsonArtifact('03_translate', 'response.json', {'content': reply}, page: context.page);

    for (final w in applyTranslationsJson(request.blocks, reply)) {
      log.warn('translate_reply_warning', {'warning': w});
    }
  }

  Future<String> _post(Uri uri, Map<String, Object?> payload, CancelToken cancel) async {
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
        throw TranslationException('${uri.host} answered HTTP ${res.statusCode}${_errorDetail(body)}');
      }
      return _content(body);
    } on TimeoutException {
      cancel.throwIfCancelled();
      throw TranslationException('${uri.host} did not answer within ${timeout.inSeconds} s');
    } on SocketException catch (e) {
      cancel.throwIfCancelled();
      throw TranslationException('cannot connect to ${uri.host}: ${e.osError?.message ?? e.message}');
    } on HttpException catch (e) {
      cancel.throwIfCancelled();
      throw TranslationException('connection to ${uri.host} failed: ${e.message}');
    } finally {
      client.close(force: true);
    }
  }

  /// `response["choices"][0]["message"]["content"]` (text parts joined when
  /// a server returns structured content).
  static String _content(String body) {
    final Object? json;
    try {
      json = jsonDecode(body);
    } on FormatException {
      throw TranslationException('the server reply is not JSON: ${_clip(body)}');
    }
    final choices = json is Map ? json['choices'] : null;
    final message = choices is List && choices.isNotEmpty && choices.first is Map ? (choices.first as Map)['message'] : null;
    final content = message is Map ? message['content'] : null;
    if (content is String) return content;
    if (content is List) {
      return [for (final part in content) if (part is Map && part['text'] is String) part['text'] as String].join();
    }
    throw TranslationException('unexpected reply format: ${_clip(body)}');
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
