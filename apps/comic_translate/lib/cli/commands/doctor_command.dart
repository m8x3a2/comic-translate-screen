import 'dart:io';

import 'package:path/path.dart' as p;

import '../../render/render_probe.dart';
import '../cli.dart';
import '../cli_context.dart';

/// One environment check reported by `cts doctor`.
class DoctorCheck {
  DoctorCheck(this.name, this.ok, this.detail);

  final String name;
  final bool ok;
  final String detail;

  Map<String, Object?> toJson() => {'name': name, 'ok': ok, 'detail': detail};
}

class DoctorCommand extends CtsCommand {
  DoctorCommand(super.holder);

  @override
  String get name => 'doctor';

  @override
  String get description =>
      'Check the environment: versions, data directory, text rendering engine.';

  @override
  Future<int> run() async {
    final checks = <DoctorCheck>[
      await _checkDataDir(),
      await _checkRender(),
    ];
    final env = ctx.services.environment();
    final allOk = checks.every((c) => c.ok);
    ctx.services.appLog.info('doctor', {
      'checks': [for (final c in checks) c.toJson()],
    });

    if (ctx.json) {
      ctx.printJson({'ok': allOk, 'environment': env, 'checks': [for (final c in checks) c.toJson()]});
    } else {
      final app = env['app'] as Map;
      final runtime = env['runtime'] as Map;
      final os = env['os'] as Map;
      final cpu = env['cpu'] as Map;
      ctx
        ..say('${app['name']} ${app['version']}')
        ..say('  Flutter ${runtime['flutter'] ?? '?'}, Dart ${(runtime['dart'] as String).split(' ').first}')
        ..say('  ${os['version']}')
        ..say('  CPU: ${cpu['identifier'] ?? '?'} (${cpu['logical_processors']} threads)')
        ..say('  Data: ${env['data_dir']}')
        ..say('');
      for (final c in checks) {
        ctx.say('${c.ok ? '[ok]  ' : '[FAIL]'} ${c.name}: ${c.detail}');
      }
    }
    return allOk ? ExitCodes.ok : ExitCodes.failure;
  }

  Future<DoctorCheck> _checkDataDir() async {
    final root = ctx.services.paths.root;
    try {
      await root.create(recursive: true);
      final probe = File(p.join(root.path, '.write_probe'));
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return DoctorCheck('data directory', true, 'writable');
    } catch (e) {
      return DoctorCheck('data directory', false, 'not writable: $e');
    }
  }

  Future<DoctorCheck> _checkRender() async {
    try {
      final r = await RenderProbe.run();
      return DoctorCheck('text rendering (dart:ui)', r.ok,
          '${r.lineCount} lines, ${r.inkPixels} ink px, ${r.elapsed.inMilliseconds} ms');
    } catch (e) {
      return DoctorCheck('text rendering (dart:ui)', false, '$e');
    }
  }
}
