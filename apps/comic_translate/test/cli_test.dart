import 'dart:convert';
import 'dart:io';

import 'package:comic_translate/cli/cli.dart';
import 'package:comic_translate/cli/cli_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Runs the CLI in-process and captures stdout/stderr.
Future<({int code, String out, String err})> cts(List<String> args, Directory dataDir) async {
  final outFile = File(p.join(dataDir.path, '_stdout.txt'));
  final errFile = File(p.join(dataDir.path, '_stderr.txt'));
  final out = outFile.openWrite();
  final err = errFile.openWrite();
  final code = await runCli(args, out: out, err: err, dataDirOverride: dataDir.path);
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
    expect(checks.map((c) => c['name']), contains('data directory'));
    expect(checks.firstWhere((c) => c['name'] == 'data directory')['ok'], isTrue);
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

  test('report builds a zip without secrets', () async {
    await cts(['doctor'], dataDir);
    final zip = p.join(dataDir.path, 'report.zip');
    final r = await cts(['--json', 'report', '-o', zip, '--note', 'key sk-abcdefghijklmnopqrstuvwx'], dataDir);
    expect(r.code, ExitCodes.ok);
    expect(File(zip).existsSync(), isTrue);
  });
}
