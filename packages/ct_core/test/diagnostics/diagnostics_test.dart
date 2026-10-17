import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const secret = 'sk-test-SECRET-0123456789abcdef';
const plainSecret = 'plain-secret-without-known-format';

void main() {
  late Directory tmp;
  late AppPaths paths;
  late Redactor redactor;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('ct_core_test_');
    paths = AppPaths(tmp.path);
    redactor = Redactor(secrets: [plainSecret], homeDir: r'C:\Users\alice');
  });

  tearDown(() => tmp.delete(recursive: true));

  test('EventLog writes valid, redacted JSONL with context', () async {
    final mem = MemorySink(redactor);
    final log = EventLog([mem]).child(runId: 'r1', page: 'p1');
    log.info('hello', {'key_used': secret, 'note': 'value $plainSecret'});
    await log.timed('detect', (l) async => l.debug('inside'));

    final events = mem.events;
    expect(events.map((e) => e.event), ['hello', 'stage_start', 'inside', 'stage_end']);
    expect(events.first.runId, 'r1');
    expect(events.first.page, 'p1');
    expect(events.last.stage, 'detect');
    expect(events.last.durMs, isNotNull);
    for (final line in mem.lines) {
      expect(line, isNot(contains(secret)));
      expect(line, isNot(contains(plainSecret)));
      jsonDecode(line); // every line is valid JSON
    }
  });

  test('EventLog.timed logs stage_error and rethrows', () async {
    final mem = MemorySink(redactor);
    final log = EventLog([mem]);
    await expectLater(log.timed('ocr', (_) async => throw StateError('boom')), throwsStateError);
    expect(mem.events.last.event, 'stage_error');
    expect(mem.events.last.data['error'], contains('boom'));
  });

  test('min level filters events', () {
    final mem = MemorySink(redactor);
    EventLog([mem], minLevel: LogLevel.warn)
      ..info('skip')
      ..warn('keep');
    expect(mem.events.map((e) => e.event), ['keep']);
  });

  test('RunRecorder lays out artifacts, timings and env; all redacted', () async {
    final run = await RunRecorder.start(
      runsDir: paths.runs,
      redactor: redactor,
      environment: {'app': 'x', 'api_key': secret, 'path': r'C:\Users\alice\data'},
      label: 'page 01.png',
    );
    await run.writeArtifact('01_detect', 'overlay.png', [1, 2, 3], page: 'page 01.png');
    await run.writeJsonArtifact('03_translate', 'request.json',
        {'headers': {'Authorization': 'Bearer $secret'}, 'body': 'text $plainSecret'},
        page: 'page 01.png');
    run.recordTiming('01_detect', const Duration(milliseconds: 42), page: 'page 01.png');
    run.log.info('note', {'k': plainSecret});
    await run.finish(success: true);

    final dir = run.dir;
    expect(File(p.join(dir.path, 'pages', 'page_01.png', '01_detect', 'overlay.png')).existsSync(), isTrue);
    final timings = jsonDecode(File(p.join(dir.path, 'timings.json')).readAsStringSync()) as Map;
    expect((timings['stages'] as List).single['dur_ms'], 42);
    expect(jsonDecode(File(p.join(dir.path, 'result.json')).readAsStringSync())['success'], isTrue);

    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      if (p.extension(f.path) == '.png') continue;
      final text = f.readAsStringSync();
      expect(text, isNot(contains(secret)), reason: f.path);
      expect(text, isNot(contains(plainSecret)), reason: f.path);
      expect(text.toLowerCase(), isNot(contains(r'users\alice')), reason: f.path);
    }
  });

  test('RunRecorder without artifacts writes only logs', () async {
    final run = await RunRecorder.start(
        runsDir: paths.runs, redactor: redactor, environment: {}, saveArtifacts: false);
    expect(await run.writeArtifact('s', 'a.png', [1]), isNull);
    await run.finish(success: false);
    expect(Directory(p.join(run.dir.path, 'pages')).existsSync(), isFalse);
  });

  test('bug report contains logs and run, never secrets; images only on request', () async {
    await paths.settingsFile.parent.create(recursive: true);
    await paths.settingsFile.writeAsString(jsonEncode({
      'translator': {'id': 'openai_compatible', 'api_key': secret, 'url': 'http://localhost:1234'},
    }));
    final appLog = JsonlFileSink(paths.appLog, redactor);
    EventLog([appLog]).info('started', {'secret_in_text': plainSecret});
    await appLog.close();

    final run = await RunRecorder.start(runsDir: paths.runs, redactor: redactor, environment: {});
    await run.writeArtifact('05_inpaint', 'after.png', [9, 9, 9], page: 'p');
    await run.writeJsonArtifact('02_ocr', 'blocks.json', {'text': 'hi'}, page: 'p');
    await run.finish(success: true);

    final builder = BugReportBuilder(paths: paths, redactor: redactor);
    final zipNoImages = await builder.build(environment: {'token': secret}, userNote: 'note $plainSecret');
    final archive = ZipDecoder().decodeBytes(zipNoImages.readAsBytesSync());
    final names = archive.files.map((f) => f.name).toSet();
    expect(names, containsAll(['env.json', 'settings.json', 'logs/app.jsonl', 'manifest.json', 'note.txt']));
    expect(names, contains('run/pages/p/02_ocr/blocks.json'));
    expect(names, isNot(contains('run/pages/p/05_inpaint/after.png')));
    for (final f in archive.files) {
      final text = utf8.decode(f.content as List<int>, allowMalformed: true);
      expect(text, isNot(contains(secret)), reason: f.name);
      expect(text, isNot(contains(plainSecret)), reason: f.name);
    }

    final zipWithImages = await builder.build(
        environment: {}, includeImages: true, output: File(p.join(tmp.path, 'with.zip')));
    final names2 = ZipDecoder().decodeBytes(zipWithImages.readAsBytesSync()).files.map((f) => f.name);
    expect(names2, contains('run/pages/p/05_inpaint/after.png'));
  });

  test('AppPaths resolution order', () {
    expect(AppPaths.resolve(override: tmp.path).root.path, p.normalize(tmp.path));
    final fromEnv = AppPaths.resolve(environment: {'CTS_DATA_DIR': tmp.path});
    expect(fromEnv.root.path, p.normalize(tmp.path));
    if (Platform.isWindows) {
      final def = AppPaths.resolve(environment: {'LOCALAPPDATA': r'C:\L'});
      expect(def.root.path, r'C:\L\ComicTranslateScreen');
    }
  });
}
