import 'dart:convert';

enum HttpOperation { chat, models, keyStatus }

class HttpRequestSpec {
  const HttpRequestSpec(this.request, this.response);

  final String request;
  final String response;

  Map<String, String> toJson() => {'request': request, 'response': response};

  static HttpRequestSpec? fromJson(Object? value) {
    if (value is! Map || value['request'] is! String || value['response'] is! String) return null;
    final request = value['request'] as String;
    final response = value['response'] as String;
    if (RequestTemplate.containsCredentials([request.replaceAll('{{api_key}}', '!'), response])) return null;
    return HttpRequestSpec(request, response);
  }

  static Map<HttpOperation, HttpRequestSpec> readAll(Object? value) => {
    if (value is Map)
      for (final operation in HttpOperation.values)
        operation: ?fromJson(value[operation.name]),
  };
}

/// Settings shared by connections. The server address and credentials belong
/// to the connection and are never copied into a template.
class RequestTemplate {
  RequestTemplate({
    required this.name,
    this.chatPath = '',
    this.modelsPath = '',
    this.requestOptions = '',
    this.keyStatusPath = '',
    Map<String, String> keyStatusFields = const {},
    Map<HttpOperation, HttpRequestSpec> http = const {},
  }) : keyStatusFields = Map.unmodifiable(keyStatusFields),
       http = Map.unmodifiable(http);

  static const selectionKey = 'request_template';
  static const keyStatusPathKey = 'template_key_status_path';
  static const keyStatusFieldsKey = 'template_key_status_fields';
  static const httpSettingKey = 'template_http_requests';

  final String name;
  final String chatPath;
  final String modelsPath;
  final String requestOptions;
  final String keyStatusPath;
  final Map<String, String> keyStatusFields;
  final Map<HttpOperation, HttpRequestSpec> http;

  Map<String, Object?> get httpJson => {for (final entry in http.entries) entry.key.name: entry.value.toJson()};

  Map<String, Object?> get overrides => {
    if (chatPath.isNotEmpty) 'chat_path': chatPath,
    if (modelsPath.isNotEmpty) 'models_path': modelsPath,
    if (requestOptions.isNotEmpty) 'request_options': requestOptions,
  };

  Map<String, Object?> toJson() => {
    'name': name,
    ...overrides,
    if (keyStatusPath.isNotEmpty) 'key_status_path': keyStatusPath,
    if (keyStatusFields.isNotEmpty) 'key_status_fields': keyStatusFields,
    if (http.isNotEmpty) 'http': httpJson,
  };

  static RequestTemplate? fromJson(Object? value) {
    if (value is! Map || value['name'] is! String) return null;
    String read(String key) => value[key] is String ? (value[key] as String).trim() : '';
    final name = read('name');
    if (name.isEmpty) return null;
    final fields = value['key_status_fields'];
    final template = RequestTemplate(
      name: name,
      chatPath: read('chat_path'),
      modelsPath: read('models_path'),
      requestOptions: read('request_options'),
      keyStatusPath: read('key_status_path'),
      keyStatusFields: {
        if (fields is Map)
          for (final entry in fields.entries)
            if (entry.key is String && entry.value is String) entry.key as String: entry.value as String,
      },
      http: HttpRequestSpec.readAll(value['http']),
    );
    try {
      if (containsCredentials([
        template.name,
        template.chatPath,
        template.modelsPath,
        template.keyStatusPath,
        if (template.requestOptions.isNotEmpty) parseRequestOptions(template.requestOptions),
      ])) {
        return null;
      }
    } on FormatException {
      return null;
    }
    return template;
  }

  static Map<String, Object?> parseRequestOptions(String source) {
    final value = jsonDecode(source);
    if (value is! Map<String, Object?>) throw const FormatException('Expected a JSON object');
    if (value.keys.any(const {'model', 'messages', 'stream'}.contains)) {
      throw const FormatException('model, messages and stream are reserved');
    }
    return value;
  }

  static final _credentialField = RegExp(
    r'^(?:authorization|(?:x[-_]?)?(?:api[-_]?(?:key|token)|auth[-_]?(?:key|token))|(?:access|refresh)[-_]?token|token|secret|password|credentials?|cookie)$',
    caseSensitive: false,
  );
  static final _credentialValue = RegExp(
    r'(?:\bsk-[\w-]{16,}|\bAIza[\w-]{30,}|\b(?:bearer|basic)\s+[\w./+=~-]{8,})',
    caseSensitive: false,
  );

  static bool isCredentialField(String name) => _credentialField.hasMatch(name.trim());

  /// The keys are labels in the UI. The values are dot-separated JSON paths.
  static Map<String, String>? parseKeyStatusFields(String source) {
    final Object? fields;
    try {
      fields = jsonDecode(source);
    } on FormatException {
      return null;
    }
    if (fields is! Map<String, Object?> || containsCredentials(fields)) return null;
    final result = <String, String>{};
    for (final entry in fields.entries) {
      final label = entry.key.trim();
      final value = entry.value;
      if (label.isEmpty || value is! String) return null;
      final parts = value.trim().split('.');
      if (parts.any((part) => part.trim().isEmpty || isCredentialField(part)) || parts.last.toLowerCase() == 'key') {
        return null;
      }
      result[label] = value.trim();
    }
    return result;
  }

  static bool containsCredentials(Object? value) => switch (value) {
    Map() => value.entries.any((entry) => isCredentialField('${entry.key}') || containsCredentials(entry.value)),
    List() => value.any(containsCredentials),
    String() => _credentialValue.hasMatch(value),
    _ => false,
  };
}
