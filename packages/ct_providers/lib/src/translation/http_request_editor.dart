import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ct_core/ct_core.dart';

part 'http_template_transport.dart';

const httpRequestTemplateSetting = TextSetting(
  key: RequestTemplate.httpSettingKey,
  label: 'HTTP request templates',
  advanced: true,
);

const openRouterModelResponsePaths = {
  'vision': 'architecture.input_modalities',
  'description': 'description',
  'context_length': 'context_length',
  'prompt_price': 'pricing.prompt',
  'completion_price': 'pricing.completion',
  'created': 'created',
};

/// Catalog prices are displayed in dollars per million tokens.
double? modelPricePerMillion(Object? value) {
  final price = value is num ? value.toDouble() : double.tryParse('$value');
  return price == null || !price.isFinite || price < 0 ? null : price * 1000000;
}

HttpRequestSpec? httpRequestSpec(PluginConfig config, HttpOperation operation) {
  final stored = config.values[RequestTemplate.httpSettingKey];
  if (stored is! String || stored.isEmpty) return null;
  try {
    return HttpRequestSpec.readAll(jsonDecode(stored))[operation];
  } on FormatException {
    return null;
  }
}

/// One explicitly configured request and its response mapping.
class EditableHttpRequest {
  EditableHttpRequest._(this.operation, this.method, this.path, this.headers, this.body, this.hasBody, this.rules);

  final HttpOperation operation;
  final String method;
  final Uri path;
  final Map<String, String> headers;
  final Object? body;
  final bool hasBody;
  final Map<String, Object?> rules;

  bool get streams => rules['format'] == 'sse';
  bool get _multipart => headers.keys.any(
    (key) => key.toLowerCase() == 'content-type' && headers[key]!.toLowerCase() == 'multipart/form-data',
  );
  bool get acceptsFiles => _multipart && body is Map && (body as Map).values.contains(_files);

  static const _files = '{{files}}';
  static const keyPlaceholder = '{{api_key}}';
  static const _methods = {'GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'};
  static const _transportHeaders = {'host', 'content-length', 'transfer-encoding', 'connection', 'upgrade', 'trailer'};
  static final _headerName = RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$");
  static final _placeholder = RegExp(r'\{\{([a-z_]+)\}\}');
  static const _chatVariables = {
    'model',
    'messages',
    'temperature',
    'max_completion_tokens',
    'max_tokens',
    'token_limit',
    'payload',
    'prompt',
    'stream',
  };

  factory EditableHttpRequest.parse(
    HttpOperation operation,
    HttpRequestSpec spec, {
    bool openRouterModelDefaults = false,
  }) {
    if (HttpRequestSpec.fromJson(spec.toJson()) == null) {
      throw const FormatException('Use {{api_key}} for credentials');
    }
    final lines = spec.request.trim().replaceAll('\r\n', '\n').split('\n');
    final first = lines.first.trim().split(RegExp(r'\s+'));
    final method = first.first.toUpperCase();
    if (first.length != 2 || !_methods.contains(method)) {
      throw const FormatException('Expected an HTTP method and a relative path, e.g. POST chat/completions');
    }
    final path = Uri.tryParse(first[1]);
    if (path == null ||
        path.hasScheme ||
        path.hasAuthority ||
        path.hasFragment ||
        path.path.isEmpty ||
        first[1].contains('{{') ||
        path.pathSegments.any((segment) => segment == '..' || segment == '.') ||
        path.queryParameters.keys.any((key) => key.toLowerCase() == 'key' || RequestTemplate.isCredentialField(key))) {
      throw const FormatException('Use a relative path on the profile server and keep credentials in headers');
    }

    final headers = <String, String>{};
    final lowerNames = <String>{};
    var index = 1;
    for (; index < lines.length && lines[index].trim().isNotEmpty; index++) {
      final line = lines[index];
      final colon = line.indexOf(':');
      if (colon < 1) throw const FormatException('Use Name: value for headers and a blank line before JSON');
      final name = line.substring(0, colon).trim();
      final lower = name.toLowerCase();
      final value = line.substring(colon + 1).trim();
      if (!_headerName.hasMatch(name) || _transportHeaders.contains(lower) || !lowerNames.add(lower)) {
        throw const FormatException('Invalid, repeated or reserved HTTP header');
      }
      if ((RequestTemplate.isCredentialField(lower) && !value.contains(keyPlaceholder)) ||
          value.replaceAll(keyPlaceholder, '').contains('{{') ||
          value.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
        throw const FormatException('Use {{api_key}} in authentication headers');
      }
      headers[name] = value;
    }
    final contentType = headers.entries.where((e) => e.key.toLowerCase() == 'content-type').firstOrNull?.value;
    final multipart = contentType?.toLowerCase() == 'multipart/form-data';
    if (!multipart && (contentType?.toLowerCase().startsWith('multipart/form-data;') ?? false)) {
      throw const FormatException('Use Content-Type: multipart/form-data without a boundary');
    }
    final source = lines.skip(index + 1).join('\n').trim();
    Object? body;
    if (source.isNotEmpty) {
      body = jsonDecode(
        source.replaceAllMapped(_placeholder, (match) {
          final variable = match[1]!;
          if (multipart && variable == 'files') return jsonEncode(match[0]);
          if (operation != HttpOperation.chat || !_chatVariables.contains(variable)) {
            throw const FormatException('Unknown JSON variable');
          }
          return jsonEncode(match[0]);
        }),
      );
      if (RequestTemplate.containsCredentials(body)) throw const FormatException('Keep credentials in headers');
    }

    if (multipart) {
      if (body is! Map<String, Object?> || body.isEmpty || body.keys.any((key) => !_formName.hasMatch(key))) {
        throw const FormatException('Multipart body must be a nonempty JSON object with valid form field names');
      }
      bool containsFiles(Object? value) => switch (value) {
        Map() => value.values.any(containsFiles),
        List() => value.any(containsFiles),
        _ => value == _files,
      };
      if (body.values.any((value) => value != _files && containsFiles(value))) {
        throw const FormatException('Use {{files}} as a whole top-level multipart field');
      }
    }

    final configuredRules = jsonDecode(spec.response);
    if (configuredRules is! Map<String, Object?>) throw const FormatException('Response rules must be a JSON object');
    final rules = {
      if (operation == HttpOperation.models && openRouterModelDefaults) ...openRouterModelResponsePaths,
      ...configuredRules,
    };
    final format = rules['format'];
    if (format != null && format != 'json' && (format != 'sse' || operation != HttpOperation.chat)) {
      throw const FormatException('Response format must be json or sse (chat only)');
    }
    for (final key in ['done_event', 'done_data']) {
      final value = rules[key];
      if (value != null && (format != 'sse' || value is! String || value.trim().isEmpty)) {
        throw FormatException('Expected a nonempty SSE marker for $key');
      }
    }
    final statuses = rules['statuses'];
    if (statuses != null &&
        (statuses is! List || statuses.isEmpty || statuses.any((item) => item is! int || item < 100 || item > 599))) {
      throw const FormatException('Statuses must be a list of HTTP status codes');
    }
    for (final field in ['error', 'usage', 'finish', 'name', ...openRouterModelResponsePaths.keys]) {
      if (rules[field] != null && rules[field] is! String) throw FormatException('Expected a path for $field');
    }
    void requiredPath(String field) {
      if (rules[field] is! String || (rules[field] as String).trim().isEmpty) {
        throw FormatException('Missing response path: $field');
      }
    }

    switch (operation) {
      case HttpOperation.chat:
        requiredPath('text');
      case HttpOperation.models:
        requiredPath('items');
        requiredPath('id');
      case HttpOperation.keyStatus:
        final fields = RequestTemplate.parseKeyStatusFields(jsonEncode(rules['fields']));
        if (fields == null || fields.isEmpty) {
          throw const FormatException('Map display names to response paths in fields');
        }
        rules['fields'] = fields;
    }
    return EditableHttpRequest._(operation, method, path, headers, body, source.isNotEmpty, rules);
  }

  Uri url(String baseUrl) {
    final base = Uri.tryParse(baseUrl.trim());
    if (base == null ||
        !const {'http', 'https'}.contains(base.scheme) ||
        base.host.isEmpty ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw const FormatException('Enter an HTTP(S) base URL in the profile');
    }
    final prefix = base.path.endsWith('/') ? base.path.substring(0, base.path.length - 1) : base.path;
    final suffix = path.path.startsWith('/') ? path.path : '/${path.path}';
    return base.replace(path: '$prefix$suffix', query: path.hasQuery ? path.query : null);
  }

  PreparedHttpRequest prepare(
    String baseUrl,
    String apiKey,
    Map<String, Object?> payload, {
    List<HttpTemplateFile>? files,
  }) {
    final messages = payload['messages'];
    final effective = {...payload, if (acceptsFiles) 'messages': _withoutImages(messages), if (streams) 'stream': true};
    final limit = payload['max_completion_tokens'] ?? payload['max_tokens'];
    final variables = {
      ...effective,
      'token_limit': ?limit,
      'prompt': ?_lastPrompt(messages),
      'payload': effective,
      if (acceptsFiles) 'files': files ?? _messageFiles(messages),
    };
    String? variable(Object? value) {
      final match = value is String ? _placeholder.firstMatch(value) : null;
      return match != null && match[0] == value ? match[1] : null;
    }

    bool missing(Object? value) {
      final key = variable(value);
      return key != null && !variables.containsKey(key);
    }

    Object? render(Object? value) {
      final key = variable(value);
      if (key != null) return variables[key];
      return switch (value) {
        Map() => {
          for (final e in value.entries)
            if (!missing(e.value)) e.key: render(e.value),
        },
        List() => [for (final item in value) render(item)],
        _ => value,
      };
    }

    final renderedHeaders = {
      for (final e in headers.entries)
        if (!e.value.contains(keyPlaceholder) || apiKey.isNotEmpty) e.key: e.value.replaceAll(keyPlaceholder, apiKey),
    };
    final form = _multipart ? _MultipartForm(render(body) as Map) : null;
    if (form != null) {
      renderedHeaders.removeWhere((key, _) => key.toLowerCase() == 'content-type');
      renderedHeaders['Content-Type'] = 'multipart/form-data; boundary=${form.boundary}';
    }
    if (streams && !renderedHeaders.keys.any((key) => key.toLowerCase() == 'accept')) {
      renderedHeaders['Accept'] = 'text/event-stream';
    }
    if (hasBody && !renderedHeaders.keys.any((key) => key.toLowerCase() == 'content-type')) {
      renderedHeaders['Content-Type'] = 'application/json';
    }
    return PreparedHttpRequest._(
      method,
      url(baseUrl),
      renderedHeaders,
      hasBody && form == null ? jsonEncode(render(body)) : null,
      apiKey,
      form: form,
      streamRequest: streams ? this : null,
    );
  }

  bool accepts(int status) => (rules['statuses'] as List?)?.contains(status) ?? (status >= 200 && status < 300);

  Object decode(HttpExchange exchange, String apiKey) {
    if (streams && accepts(exchange.status)) {
      if (exchange._stream case final stream?) return stream.result;
      final stream = _SseChat(this, apiKey);
      for (final line in const LineSplitter().convert(exchange.body)) {
        if (!stream.add(line)) break;
      }
      return stream.result;
    }
    final Object? response;
    try {
      response = jsonDecode(exchange.body);
    } on FormatException {
      if (accepts(exchange.status)) {
        throw TranslationException('the response is not JSON', kind: TranslationErrorKind.badReply);
      }
      throw _httpError(exchange.status, '');
    }
    if (!accepts(exchange.status)) {
      final error = _at(response, rules['error'] as String? ?? 'error.message');
      throw _httpError(exchange.status, redactHttpText(error?.toString() ?? '', apiKey));
    }
    final Object result;
    switch (operation) {
      case HttpOperation.chat:
        final value = _at(response, rules['text']);
        final text = _responseText(value);
        if (text.trim().isEmpty) throw _missing(rules['text']);
        final usage = _at(response, rules['usage']);
        final finish = _at(response, rules['finish']);
        result = (text, usage is Map<String, Object?> ? usage : null, finish is String ? finish : null);
      case HttpOperation.models:
        final rows = _at(response, rules['items']);
        if (rows is! List) throw _missing(rules['items']);
        final models = <CatalogModel>[];
        for (final row in rows) {
          final id = _at(row, rules['id']);
          if (id is! String || id.trim().isEmpty || redactHttpText(id, apiKey) != id) continue;
          String safeText(String field) {
            final value = _at(row, rules[field]);
            return value is String ? redactHttpText(value, apiKey) : '';
          }

          final vision = _at(row, rules['vision']);
          final context = _at(row, rules['context_length']);
          final created = _at(row, rules['created']);
          models.add(
            CatalogModel(
              id: id,
              name: safeText('name'),
              description: safeText('description'),
              vision: vision == true || (vision is List && vision.contains('image')),
              contextLength: context is num && context.isFinite && context > 0 ? context.toInt() : null,
              promptPrice: modelPricePerMillion(_at(row, rules['prompt_price'])),
              completionPrice: modelPricePerMillion(_at(row, rules['completion_price'])),
              created: created is num && created.abs() <= 8640000000000
                  ? DateTime.fromMillisecondsSinceEpoch((created * 1000).toInt(), isUtc: true)
                  : null,
            ),
          );
        }
        if (rows.isNotEmpty && models.isEmpty) throw _missing(rules['id']);
        result = models;
      case HttpOperation.keyStatus:
        final fields = rules['fields'] as Map<String, String>;
        final values = <String, String>{};
        for (final entry in fields.entries) {
          final value = _at(response, entry.value);
          if (value is String) values[entry.key] = redactHttpText(value, apiKey);
          if (value is num || value is bool) values[entry.key] = '$value';
        }
        if (values.isEmpty) throw _missing(fields.values.join(', '));
        result = KeyStatus(fields: values);
    }
    return result;
  }

  static Object? _at(Object? value, Object? path) {
    if (path is! String) return null;
    final parts = path
        .trim()
        .replaceFirst(RegExp(r'^\$\.?'), '')
        .replaceAllMapped(RegExp(r'\[(\d+)\]'), (m) => '.${m[1]}');
    for (final part in parts.split('.').where((part) => part.isNotEmpty)) {
      if (value is List) {
        final index = int.tryParse(part);
        value = index != null && index >= 0 && index < value.length ? value[index] : null;
      } else {
        value = value is Map ? value[part] : null;
      }
    }
    return value;
  }

  static TranslationException _missing(Object? path) =>
      TranslationException('no usable response value at $path', kind: TranslationErrorKind.badReply);

  static TranslationException _httpError(int status, String detail) => TranslationException(
    'HTTP $status${detail.isEmpty ? '' : ' · $detail'}',
    kind: TranslationErrorKind.forStatus(status, detail),
    statusCode: status,
  );
}

class HttpExchange {
  const HttpExchange(this.status, this.body) : _stream = null;
  const HttpExchange._fromStream(this.status, this.body, this._stream);

  final int status;
  final String body;
  final _SseChat? _stream;
}

class PreparedHttpRequest {
  PreparedHttpRequest._(
    this.method,
    this.uri,
    this._headers,
    this._body,
    this._key, {
    this._form,
    this._streamRequest,
  });

  static final _openAiChatStream = EditableHttpRequest.parse(
    HttpOperation.chat,
    const HttpRequestSpec(
      'POST chat/completions',
      '{"format":"sse","text":"choices[0].delta.content","finish":"choices[0].finish_reason","usage":"usage"}',
    ),
  );

  factory PreparedHttpRequest.openAiChatStream(Uri uri, String apiKey, Map<String, Object?> payload) =>
      PreparedHttpRequest._(
        'POST',
        uri,
        {
          'Content-Type': 'application/json',
          'Accept': 'text/event-stream',
          if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
        },
        jsonEncode({...payload, 'stream': true}),
        apiKey,
        streamRequest: _openAiChatStream,
      );

  (String, Map<String, Object?>?, String?) decodeOpenAiChatStream(HttpExchange exchange) =>
      _openAiChatStream.decode(exchange, _key) as (String, Map<String, Object?>?, String?);

  final String method;
  final Uri uri;
  final Map<String, String> _headers;
  final String? _body;
  final String _key;
  final _MultipartForm? _form;
  final EditableHttpRequest? _streamRequest;

  String get preview => [
    '$method $uri',
    for (final entry in _headers.entries)
      '${entry.key}: ${RequestTemplate.isCredentialField(entry.key) ? '[hidden]' : redactHttpText(entry.value, _key)}',
    if (_body != null) ...['', redactHttpText(_body, _key)],
    if (_form case final form?) ...['', redactHttpText(form.preview, _key)],
  ].join('\n');

  Future<HttpExchange> send({
    required Duration timeout,
    CancelToken? cancel,
    HttpClient Function()? clientFactory,
    void Function(String)? onText,
  }) async {
    cancel?.throwIfCancelled();
    _SseChat? stream;
    final client = (clientFactory?.call() ?? (HttpClient()..findProxy = HttpClient.findProxyFromEnvironment))
      ..connectionTimeout = timeout;
    if (!identical(cancel, CancelToken.none)) cancel?.onCancel(() => client.close(force: true));
    try {
      final req = await client.openUrl(method, uri).timeout(timeout);
      req.followRedirects = false;
      _headers.forEach((name, value) => req.headers.set(name, value));
      if (_form case final form?) {
        final chunks = form.chunks.toList();
        req.contentLength = chunks.fold(0, (length, chunk) => length + chunk.length);
        await req.addStream(Stream.fromIterable(chunks)).timeout(timeout);
      } else if (_body case final body?) {
        final bytes = utf8.encode(body);
        req.contentLength = bytes.length;
        req.add(bytes);
      }
      final response = await req.close().timeout(timeout);
      if (_streamRequest case final streamRequest? when streamRequest.accepts(response.statusCode)) {
        stream = _SseChat(streamRequest, _key, onText: onText);
        final diagnostics = StringBuffer();
        final lines = response
            .timeout(timeout)
            .transform(const Utf8Decoder(allowMalformed: true))
            .transform(const LineSplitter());
        await for (final line in lines) {
          cancel?.throwIfCancelled();
          const limit = 24000;
          if (diagnostics.length < limit) {
            final room = limit - diagnostics.length;
            diagnostics.writeln(line.length > room ? line.substring(0, room) : line);
          }
          if (!stream.add(line)) break;
        }
        cancel?.throwIfCancelled();
        return HttpExchange._fromStream(response.statusCode, diagnostics.toString(), stream);
      }
      final body = await response.transform(const Utf8Decoder(allowMalformed: true)).join().timeout(timeout);
      cancel?.throwIfCancelled();
      return HttpExchange(response.statusCode, body);
    } on TimeoutException {
      cancel?.throwIfCancelled();
      throw TranslationException('request timed out', kind: TranslationErrorKind.timeout, reply: stream?.partialText);
    } on IOException {
      cancel?.throwIfCancelled();
      throw TranslationException(
        'cannot connect to ${uri.host}',
        kind: TranslationErrorKind.network,
        reply: stream?.partialText,
      );
    } finally {
      client.close(force: true);
    }
  }
}

String redactHttpText(String text, String apiKey) {
  final redactor = Redactor(secrets: [apiKey]);
  if (apiKey.isNotEmpty && apiKey.length < Redactor.minSecretLength) {
    text = text.replaceAll(RegExp('(?<![A-Za-z0-9])${RegExp.escape(apiKey)}(?![A-Za-z0-9])'), Redactor.mask);
  }
  return redactor
      .redact(text)
      .replaceAll(
        RegExp(r'data:image/[^\s;,]+;base64,[A-Za-z0-9+/=_-]+', caseSensitive: false),
        '[image data omitted]',
      );
}
