part of 'http_request_editor.dart';

class HttpTemplateFile {
  const HttpTemplateFile(this.name, this.bytes, {this.contentType = 'application/octet-stream'});

  final String name;
  final List<int> bytes;
  final String contentType;
}

final _formName = RegExp(r'^[A-Za-z0-9_.\[\]-]+$');
final _mimeType = RegExp(r'^[A-Za-z0-9.+-]+/[A-Za-z0-9.+-]+$');
final _formRandom = Random.secure();

String _filename(String name) {
  final basename = name.split(RegExp(r'[/\\]')).last;
  final safe = basename.replaceAll(RegExp(r'["\x00-\x1f\x7f]'), '_').trim();
  return safe.isEmpty ? 'file' : safe;
}

class _MultipartForm {
  _MultipartForm(this.fields) : boundary = 'cts-${base64UrlEncode(List.generate(24, (_) => _formRandom.nextInt(256)))}';

  final Map fields;
  final String boundary;

  Iterable<List<int>> get chunks sync* {
    for (final entry in fields.entries) {
      final header = '--$boundary\r\nContent-Disposition: form-data; name="${entry.key}"';
      if (entry.value is List<HttpTemplateFile>) {
        for (final file in entry.value as List<HttpTemplateFile>) {
          final type = _mimeType.hasMatch(file.contentType) ? file.contentType : 'application/octet-stream';
          yield utf8.encode('$header; filename="${_filename(file.name)}"\r\nContent-Type: $type\r\n\r\n');
          yield file.bytes;
          yield const [13, 10];
        }
      } else {
        yield utf8.encode('$header\r\n\r\n${_value(entry.value)}\r\n');
      }
    }
    yield utf8.encode('--$boundary--\r\n');
  }

  static String _value(Object? value) => value is String ? value : jsonEncode(value);

  String get preview => [
    for (final entry in fields.entries)
      if (entry.value case final List<HttpTemplateFile> files)
        for (final file in files) '${entry.key}: [file: ${_filename(file.name)}, ${file.bytes.length} bytes]'
      else
        '${entry.key}: ${_value(entry.value)}',
  ].join('\n');
}

Iterable<Map> _messages(Object? value) => value is List ? value.whereType<Map>() : const [];

Object? _withoutImages(Object? messages) => [
  for (final message in _messages(messages))
    {
      ...message,
      if (message['content'] case final List parts)
        'content': [
          for (final part in parts)
            if (part is! Map || part['type'] != 'image_url') part,
        ],
    },
];

String? _lastPrompt(Object? messages) {
  for (final message in _messages(messages).toList().reversed) {
    if (message['role'] != 'user') continue;
    return switch (message['content']) {
      final String text => text,
      final List parts =>
        parts
            .whereType<Map>()
            .where((part) => part['type'] == 'text')
            .map((part) => part['text'])
            .whereType<String>()
            .join('\n'),
      _ => null,
    };
  }
  return null;
}

final _imageData = RegExp(r'^data:(image/[a-zA-Z0-9.+-]+);base64,([A-Za-z0-9+/=_-]+)$');

List<HttpTemplateFile> _messageFiles(Object? messages) {
  final files = <HttpTemplateFile>[];
  for (final message in _messages(messages)) {
    if (message['content'] is! List) continue;
    for (final part in (message['content'] as List).whereType<Map>()) {
      if (part['type'] != 'image_url' || part['image_url'] is! Map) continue;
      final url = (part['image_url'] as Map)['url'];
      final match = url is String ? _imageData.firstMatch(url) : null;
      if (match == null) throw const FormatException('Multipart images must contain local image data');
      final mime = match[1]!;
      final extension = mime == 'image/jpeg' ? 'jpg' : mime.split('/').last;
      files.add(HttpTemplateFile('image-${files.length + 1}.$extension', base64Decode(match[2]!), contentType: mime));
    }
  }
  return files;
}

String _responseText(Object? value) => switch (value) {
  String() => value,
  List() => value.whereType<Map>().map((item) => item['text']).whereType<String>().join(),
  _ => '',
};

/// SSE framing is independent of HTTP chunk boundaries. Both live and
/// pasted responses pass through this accumulator.
class _SseChat {
  _SseChat(this.request, this.key, {this.onText});

  final EditableHttpRequest request;
  final String key;
  final void Function(String)? onText;
  final _data = <String>[];
  final _text = StringBuffer();
  String _event = '';
  String? _finish;
  Map<String, Object?>? _usage;
  String? _failure;
  bool _first = true;
  bool _completed = false;

  bool add(String line) {
    if (_first) {
      _first = false;
      if (line.startsWith('\uFEFF')) line = line.substring(1);
    }
    if (line.isEmpty) return _dispatch();
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    final value = colon < 0 ? '' : line.substring(colon + 1).replaceFirst(RegExp('^ '), '');
    if (field == 'data') _data.add(value);
    if (field == 'event') _event = value;
    return true;
  }

  bool _dispatch() {
    final event = _event;
    final data = _data.join('\n');
    _event = '';
    _data.clear();
    final rules = request.rules;
    final done = event == rules['done_event'];
    if (data == (rules['done_data'] ?? '[DONE]')) {
      _completed = true;
      return false;
    }
    if (done) _completed = true;
    if (data.isEmpty && event != 'error') return !done;

    Object? value;
    try {
      value = jsonDecode(data);
    } on FormatException {
      if (done) return false;
      _failure = event == 'error' ? redactHttpText(data, key) : 'an SSE event does not contain JSON';
      return false;
    }
    final error = EditableHttpRequest._at(value, rules['error'] ?? 'error.message');
    if (event == 'error' || error != null) {
      _failure = redactHttpText(error?.toString() ?? 'the server returned an SSE error event', key);
      return false;
    }
    if (EditableHttpRequest._at(value, rules['usage']) case final Map<String, Object?> usage) {
      _usage = {...?_usage, ...usage};
    }
    if (EditableHttpRequest._at(value, rules['finish']) case final String finish when finish.isNotEmpty) {
      _finish = finish;
    }
    final text = _responseText(EditableHttpRequest._at(value, rules['text']));
    if (text.isNotEmpty) {
      _text.write(text);
      onText?.call(text);
    }
    return !done;
  }

  (String, Map<String, Object?>?, String?) get result {
    if (_failure case final failure?) {
      throw TranslationException(failure, kind: TranslationErrorKind.badReply, reply: partialText);
    }
    if (_data.isNotEmpty || !_completed) {
      throw TranslationException(
        'the SSE stream ended without a completion signal',
        kind: TranslationErrorKind.interrupted,
        reply: partialText,
      );
    }
    final text = _text.toString();
    if (text.trim().isEmpty) throw EditableHttpRequest._missing(request.rules['text']);
    return (text, _usage, _finish);
  }

  String get partialText => redactHttpText(_text.toString(), key);
}
