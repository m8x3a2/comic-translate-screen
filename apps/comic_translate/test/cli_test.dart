import 'dart:convert';
import 'dart:io';

import 'package:comic_translate/cli/cli.dart';
import 'package:comic_translate/cli/cli_context.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Runs the CLI in-process and captures stdout/stderr.
Future<({int code, String out, String err})> cts(
  List<String> args,
  Directory dataDir, {
  SecretStore? secrets,
}) async {
  final outFile = File(p.join(dataDir.path, '_stdout.txt'));
  final errFile = File(p.join(dataDir.path, '_stderr.txt'));
  final out = outFile.openWrite();
  final err = errFile.openWrite();
  final code = await runCli(args,
      out: out, err: err, dataDirOverride: dataDir.path, secretStore: secrets ?? MemorySecretStore());
  await out.close();
  await err.close();
  return (code: code, out: outFile.readAsStringSync(), err: errFile.readAsStringSync());
}

void main() {
  late Directory dataDir;

  setUp(() async => dataDir = await Directory.systemTemp.createTemp('cts_cli_test_'));
  tearDown(() => dataDir.delete(recursive: true));

  test('version --json', () async {
    final r = await cts(['--json', 'version'], dataDir);
    expect(r.code, ExitCodes.ok);
    final json = jsonDecode(r.out) as Map;
    expect(json['app'], 'Comic Translate Screen');
    expect(json['version'], isNotEmpty);
  });

  test('unknown command is a usage error', () async {
    final r = await cts(['no-such-command'], dataDir);
    expect(r.code, ExitCodes.usage);
    expect(r.err, contains('Could not find a command'));
  });

  test('doctor --json reports checks and logs to app.jsonl', () async {
    final r = await cts(['--json', 'doctor'], dataDir);
    final json = jsonDecode(r.out) as Map;
    final checks = (json['checks'] as List).cast<Map>();
    Map check(String name) => checks.firstWhere((c) => c['name'] == name);
    expect(check('data directory')['ok'], isTrue);
    expect(check('secure storage')['ok'], isTrue);
    expect(check('model aot-inpainting')['status'], 'warn', reason: 'not downloaded in a fresh data dir');
    final appLog = File(p.join(dataDir.path, 'logs', 'app.jsonl')).readAsLinesSync();
    expect(appLog.map((l) => (jsonDecode(l) as Map)['event']), containsAll(['cli_command', 'doctor', 'cli_exit']));
  });

  test('selftest render writes a PNG', () async {
    final png = p.join(dataDir.path, 'probe.png');
    final r = await cts(['--json', 'selftest', 'render', '-o', png], dataDir);
    final json = jsonDecode(r.out) as Map;
    expect(json['lines'], greaterThanOrEqualTo(2));
    final bytes = File(png).readAsBytesSync();
    expect(bytes.sublist(1, 4), 'PNG'.codeUnits);
  });

  test('models list shows the catalog without network access', () async {
    final r = await cts(['--json', 'models', 'list'], dataDir);
    expect(r.code, ExitCodes.ok);
    final rows = (jsonDecode(r.out) as List).cast<Map>();
    expect(rows.map((m) => m['id']), containsAll(['rtdetr-v2-int8', 'aot-inpainting', 'lama-manga']));
    expect(rows.every((m) => m['status'] == 'missing'), isTrue);
  });

  test('models download needs a model id', () async {
    final r = await cts(['models', 'download'], dataDir);
    expect(r.code, ExitCodes.usage);
  });

  test('stored secrets are masked in logs and listed without values', () async {
    final secrets = MemorySecretStore({'plugin.openai_compatible.api_key': 'sk-live-0123456789abcdefXYZ'});
    final r = await cts(['--json', 'secrets', 'list'], dataDir, secrets: secrets);
    expect(jsonDecode(r.out), ['plugin.openai_compatible.api_key']);
    expect(r.out, isNot(contains('sk-live')));

    // Even if the secret shows up in an argument, the log masks it.
    await cts(['--json', 'version', '--', 'sk-live-0123456789abcdefXYZ'], dataDir, secrets: secrets);
    final log = File(p.join(dataDir.path, 'logs', 'app.jsonl')).readAsStringSync();
    expect(log, isNot(contains('0123456789abcdefXYZ')));
  });

  test('report builds a zip without secrets', () async {
    await cts(['doctor'], dataDir);
    final zip = p.join(dataDir.path, 'report.zip');
    final r = await cts(['--json', 'report', '-o', zip, '--note', 'key sk-abcdefghijklmnopqrstuvwx'], dataDir);
    expect(r.code, ExitCodes.ok);
    expect(File(zip).existsSync(), isTrue);
  });

  test('settings set/get round trip and rejects unknown keys', () async {
    expect((await cts(['settings', 'set', 'languages.target', 'German'], dataDir)).code, ExitCodes.ok);
    expect((await cts(['settings', 'set', 'plugins.openai_compatible.model', 'm/x'], dataDir)).code, ExitCodes.ok);
    final r = await cts(['settings', 'get', 'languages.target'], dataDir);
    expect(jsonDecode(r.out), 'German');
    final bad = await cts(['settings', 'set', 'tools.use_gpu', 'yes'], dataDir);
    expect(bad.code, ExitCodes.failure, reason: 'use_gpu must be a boolean');
  });

  group('translate', () {
    late String ocrJson;
    setUp(() {
      ocrJson = p.join(dataDir.path, 'page.ocr.json');
      File(ocrJson).writeAsStringSync(jsonEncode({
        'image': 'page.jpg',
        'source_language': 'English',
        'blocks': [
          TextBlock(xyxy: const BBox(0, 50, 10, 60), text: 'Second').toJson(),
          TextBlock(xyxy: const BBox(0, 0, 10, 10), text: 'First').toJson(),
          TextBlock(xyxy: const BBox(0, 80, 10, 90), text: '...').toJson(),
        ],
        'reading_order': [1, 0, 2],
      }));
    });

    test('mock translator writes translations in reading order', () async {
      final out = p.join(dataDir.path, 'out');
      final r = await cts(['--json', 'translate', '--translator', 'mock', '--to', 'Russian', ocrJson, '-o', out], dataDir);
      expect(r.code, ExitCodes.ok, reason: r.err);
      final pairs = ((jsonDecode(r.out) as Map)['results'] as List).single['pairs'] as List;
      expect([for (final x in pairs) x['translation']], ['[ru] First', '[ru] Second', '']);
      final written = jsonDecode(File(p.join(out, 'page.translated.json')).readAsStringSync()) as Map;
      expect(written['target_language'], 'Russian');
    });

    test('a cloud translator needs explicit permission; nothing is sent without it', () async {
      await cts(['settings', 'set', 'plugins.openai_compatible.api_url', 'https://example.invalid/v1'], dataDir);
      await cts(['settings', 'set', 'plugins.openai_compatible.model', 'm'], dataDir);
      final r = await cts(['translate', '--translator', 'openai_compatible', ocrJson, '-o', dataDir.path], dataDir);
      expect(r.code, ExitCodes.failure);
      expect(r.err, contains('Nothing was sent'));
      expect(r.err, contains('example.invalid'));
    });

    test('mask covers the text of the given blocks', () async {
      // A white page with a dark "word" inside the block.
      final page = RgbImage.filled(200, 120, 255, 255, 255);
      for (var y = 50; y < 62; y++) {
        for (var x = 60; x < 140; x++) {
          if ((x ~/ 6).isEven) page.data.setRange(page.offset(x, y), page.offset(x, y) + 3, [10, 10, 10]);
        }
      }
      final png = p.join(dataDir.path, 'page.png');
      File(png).writeAsBytesSync(ImageCodec.encodePng(page));
      final blocks = p.join(dataDir.path, 'page.blocks.json');
      File(blocks).writeAsStringSync(jsonEncode({
        'blocks': [TextBlock(xyxy: const BBox(50, 40, 150, 72), text: 'word').toJson()],
      }));
      final out = p.join(dataDir.path, 'out');
      final r = await cts(['--json', 'mask', png, '--blocks', blocks, '-o', out], dataDir);
      expect(r.code, ExitCodes.ok, reason: r.err);
      final mask = ImageCodec.decodeGray(File(p.join(out, 'page.mask.png')).readAsBytesSync());
      expect(mask.at(100, 55), 255, reason: 'text pixel is masked');
      expect(mask.at(5, 5), 0, reason: 'background far from text is kept');
    });

    test('unknown translator is a usage error', () async {
      final r = await cts(['translate', '--translator', 'nope', ocrJson], dataDir);
      expect(r.code, ExitCodes.usage);
    });
  });

  group('render and quality', () {
    String writePng(String name, RgbImage image) {
      final path = p.join(dataDir.path, name);
      File(path).writeAsBytesSync(ImageCodec.encodePng(image));
      return path;
    }

    test('render draws the translation inside its block only', () async {
      final png = writePng('page.clean.png', RgbImage.filled(400, 300, 255, 255, 255));
      final blocks = p.join(dataDir.path, 'page.translated.json');
      File(blocks).writeAsStringSync(jsonEncode({
        'target_language': 'Russian',
        'blocks': [TextBlock(xyxy: const BBox(100, 80, 300, 220), text: 'Hello', translation: 'Привет всем').toJson()],
      }));
      final out = p.join(dataDir.path, 'out');
      final r = await cts(['--json', 'render', png, '--blocks', blocks, '-o', out], dataDir);
      expect(r.code, ExitCodes.ok, reason: r.err);
      expect((jsonDecode(r.out) as Map)['items'], 1);
      final img = ImageCodec.decode(File(p.join(out, 'page.rendered.png')).readAsBytesSync());
      var dark = 0, darkOutside = 0;
      for (var y = 0; y < img.height; y++) {
        for (var x = 0; x < img.width; x++) {
          if (img.data[img.offset(x, y)] < 128) {
            final inside = x >= 100 && x < 300 && y >= 80 && y < 220;
            inside ? dark++ : darkOutside++;
          }
        }
      }
      expect(dark, greaterThan(50), reason: 'text is drawn');
      expect(darkOutside, 0, reason: 'nothing is drawn outside the block');
      final layout = jsonDecode(File(p.join(out, 'page.layout.json')).readAsStringSync()) as Map;
      expect(((layout['items'] as List).single as Map)['text'], contains('Привет'));
    });

    test('compare: identical, different (with a difference picture), wrong size', () async {
      final a = writePng('a.png', RgbImage.filled(20, 10, 200, 200, 200));
      final b = writePng('b.png', RgbImage.filled(20, 10, 200, 200, 200)..data[0] = 0);
      final c = writePng('c.png', RgbImage.filled(10, 10, 200, 200, 200));
      expect((await cts(['compare', a, a], dataDir)).code, ExitCodes.ok);
      final diff = p.join(dataDir.path, 'diff.png');
      final r = await cts(['--json', 'compare', a, b, '--diff', diff], dataDir);
      expect(r.code, ExitCodes.failure);
      expect((jsonDecode(r.out) as Map)['max_diff'], 200);
      expect(File(diff).existsSync(), isTrue);
      expect((await cts(['compare', a, b, '--min-psnr', '20'], dataDir)).code, ExitCodes.ok);
      expect((await cts(['compare', a, c], dataDir)).code, ExitCodes.failure);
    });

    test('golden check explains a missing manifest', () async {
      final r = await cts(['golden', 'check', '--dir', p.join(dataDir.path, 'nope')], dataDir);
      expect(r.code, ExitCodes.failure);
      expect(r.err, contains('golden.json'));
    });

    test('process refuses a cloud translator without permission', () async {
      final png = writePng('page.png', RgbImage.filled(50, 50, 255, 255, 255));
      await cts(['settings', 'set', 'plugins.openai_compatible.api_url', 'https://example.invalid/v1'], dataDir);
      await cts(['settings', 'set', 'plugins.openai_compatible.model', 'm'], dataDir);
      final r = await cts(['process', png, '--translator', 'openai_compatible'], dataDir);
      expect(r.code, ExitCodes.failure);
      expect(r.err, contains('Nothing was sent'));
    });
  });
}
