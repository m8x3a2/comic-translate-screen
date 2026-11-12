import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:flutter_test/flutter_test.dart';

const chatSpec = HttpRequestSpec(
  'POST upload\nContent-Type: multipart/form-data\nAuthorization: Bearer {{api_key}}\n\n'
      '{"prompt": {{prompt}}, "upload[]": {{files}}, "stream": {{stream}}}',
  '{"format":"sse","text":"delta","finish":"stop","usage":"usage","done_event":"end"}',
);

void main() {
  test('pasted SSE decodes multiline data and rejects interrupted or error events', () {
    final operation = EditableHttpRequest.parse(HttpOperation.chat, chatSpec);
    final response = operation.decode(
      const HttpExchange(
        200,
        '\uFEFF: heartbeat\r\n\r\ndata: {"delta":\r\ndata: "first"}\r\n\r\n'
        'data: {"delta":" second","usage":{"input":2}}\n\n'
        'event: end\ndata: {"stop":"length","usage":{"output":4}}\n\n',
      ),
      '',
    ) as (String, Map<String, Object?>?, String?);
    expect(response.$1, 'first second');
    expect(response.$2, {'input': 2, 'output': 4});
    expect(response.$3, 'length');
    expect(
      () => operation.decode(
        const HttpExchange(
          200,
          'data: {"delta":"partial"}\n\n'
          'data: {"delta":"truncated"}',
        ),
        '',
      ),
      throwsA(isA<TranslationException>()),
    );
    expect(
      () => operation.decode(const HttpExchange(200, 'event: error\ndata: {"error":{"message":"refused"}}\n\n'), ''),
      throwsA(isA<TranslationException>().having((error) => error.message, 'message', contains('refused'))),
    );
  });

  for (final cleanClose in [true, false]) {
    test('SSE retains text when the HTTP connection closes (clean: $cleanClose)', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final sawText = Completer<void>();
      final served = server.first.then((request) async {
        await request.drain<void>();
        final socket = await request.response.detachSocket(writeHeaders: false);
        const data = 'data: {"choices":[{"delta":{"content":"Partial answer"}}]}\r\n\r\n';
        socket.write(
          'HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\n'
          'Transfer-Encoding: chunked\r\nConnection: close\r\n\r\n'
          '${data.length.toRadixString(16)}\r\n$data\r\n',
        );
        await socket.flush();
        await sawText.future.timeout(const Duration(seconds: 3));
        if (cleanClose) {
          socket.write('0\r\n\r\n');
          await socket.flush();
        }
        await socket.close();
      });
      final translator = OpenAiCompatibleTranslator(
        apiUrl: 'http://127.0.0.1:${server.port}',
        model: 'fixture',
        streamChat: true,
        timeout: const Duration(seconds: 4),
      );
      await expectLater(
        translator.testChat(
          [
            {'role': 'user', 'content': 'Hello'},
          ],
          CancelToken(),
          EventLog.silent(),
          onText: (text) {
            expect(text, 'Partial answer');
            sawText.complete();
          },
        ),
        throwsA(
          isA<TranslationException>()
              .having((error) => error.reply, 'partial text', 'Partial answer')
              .having(
                (error) => error.kind,
                'failure',
                cleanClose ? TranslationErrorKind.interrupted : TranslationErrorKind.network,
              ),
        ),
      );
      await served;
    });
  }

  test('multipart sends file bytes and delivers SSE before the server closes', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final first = Completer<void>();
    final finished = Completer<void>();
    final seen = Completer<({String type, String accept, List<int> bytes})>();
    server.listen((request) async {
      final bytes = await request.expand((chunk) => chunk).toList();
      seen.complete((
        type: request.headers.value(HttpHeaders.contentTypeHeader)!,
        accept: request.headers.value(HttpHeaders.acceptHeader)!,
        bytes: bytes,
      ));
      request.response
        ..bufferOutput = false
        ..headers.contentType = ContentType('text', 'event-stream', charset: 'utf-8')
        ..write(': ping\r\ndata: {"delta":"first"}\r\n\r\n');
      await request.response.flush();
      await first.future;
      request.response.write('data: {"delta":" second"}\n\ndata: [DONE]\n\n');
      await request.response.flush();
      await finished.future;
      await request.response.close();
    });

    final operation = EditableHttpRequest.parse(HttpOperation.chat, chatSpec);
    final request = operation.prepare(
      'http://127.0.0.1:${server.port}/v1',
      'qa-fake-secret',
      {
        'messages': [
          {'role': 'user', 'content': 'Explain'},
        ],
      },
      files: [
        const HttpTemplateFile('one.dat', [0, 255, 65]),
        const HttpTemplateFile('two.txt', [66]),
      ],
    );
    expect(request.preview, contains('one.dat, 3 bytes'));
    expect(request.preview, isNot(contains('qa-fake-secret')));
    final chunks = <String>[];
    try {
      final exchange = await request.send(
        timeout: const Duration(seconds: 4),
        onText: (text) {
          chunks.add(text);
          if (!first.isCompleted) first.complete();
        },
      );
      final reply = operation.decode(exchange, '') as (String, Map<String, Object?>?, String?);
      expect(reply.$1, 'first second');
      expect(chunks, ['first', ' second']);
      final actual = await seen.future;
      expect(actual.accept, 'text/event-stream');
      final boundary = ContentType.parse(actual.type).parameters['boundary'];
      final wire = latin1.decode(actual.bytes);
      expect(wire, endsWith('--$boundary--\r\n'));
      expect(wire, contains('name="prompt"\r\n\r\nExplain'));
      expect(wire, contains('name="stream"\r\n\r\ntrue'));
      expect(
        wire,
        contains('name="upload[]"; filename="one.dat"\r\nContent-Type: application/octet-stream\r\n\r\n\u0000ÿA'),
      );
      expect(wire, contains('name="upload[]"; filename="two.txt"'));
    } finally {
      if (!first.isCompleted) first.complete();
      finished.complete();
    }
  });

  test('image messages become local file parts in OCR and do not duplicate base64', () {
    final operation = EditableHttpRequest.parse(
      HttpOperation.chat,
      const HttpRequestSpec(
        'POST ocr\nContent-Type: multipart/form-data\n\n{"messages":{{messages}},"image":{{files}}}',
        '{"text":"result"}',
      ),
    );
    final preview = operation.prepare('http://localhost', '', {
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': 'Read two frames'},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/png;base64,AAEC'},
            },
          ],
        },
      ],
    }).preview;
    expect(preview, contains('image-1.png, 3 bytes'));
    expect(preview, contains('Read two frames'));
    expect(preview, isNot(contains('image_url')));
    expect(preview, isNot(contains('AAEC')));
  });
}
