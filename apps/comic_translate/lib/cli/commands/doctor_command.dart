import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:ct_onnx/ct_onnx.dart';
import 'package:path/path.dart' as p;

import '../../render/render_probe.dart';
import '../cli.dart';
import '../cli_context.dart';

enum CheckStatus { ok, warn, fail }

/// One environment check reported by `cts doctor`.
class DoctorCheck {
  DoctorCheck(this.name, this.status, this.detail);

  DoctorCheck.ok(this.name, this.detail) : status = CheckStatus.ok;
  DoctorCheck.warn(this.name, this.detail) : status = CheckStatus.warn;
  DoctorCheck.fail(this.name, this.detail) : status = CheckStatus.fail;

  final String name;
  final CheckStatus status;
  final String detail;

  bool get ok => status != CheckStatus.fail;

  Map<String, Object?> toJson() => {'name': name, 'ok': ok, 'status': status.name, 'detail': detail};
}

/// Runs [body]; any exception becomes a failed check.
Future<DoctorCheck> guardedCheck(String name, Future<DoctorCheck> Function() body) async {
  try {
    return await body();
  } catch (e) {
    return DoctorCheck.fail(name, '$e');
  }
}

class DoctorCommand extends CtsCommand {
  DoctorCommand(super.holder);

  @override
  String get name => 'doctor';

  @override
  String get description =>
      'Check the environment: data directory, text rendering, OpenCV, secure storage, models.';

  @override
  Future<int> run() async {
    final checks = <DoctorCheck>[
      await guardedCheck('data directory', _checkDataDir),
      await guardedCheck('text rendering (dart:ui)', _checkRender),
      await guardedCheck('image codecs (OpenCV)', _checkOpenCv),
      ...await _checkOnnxRuntime(),
      await guardedCheck('secure storage', _checkSecrets),
      ...await _checkModels(),
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
        final tag = switch (c.status) {
          CheckStatus.ok => '[ok]  ',
          CheckStatus.warn => '[warn]',
          CheckStatus.fail => '[FAIL]',
        };
        ctx.say('$tag ${c.name}: ${c.detail}');
      }
    }
    return allOk ? ExitCodes.ok : ExitCodes.failure;
  }

  Future<DoctorCheck> _checkDataDir() async {
    final root = ctx.services.paths.root;
    await root.create(recursive: true);
    final probe = File(p.join(root.path, '.write_probe'));
    await probe.writeAsString('ok', flush: true);
    await probe.delete();
    return DoctorCheck.ok('data directory', 'writable');
  }

  Future<DoctorCheck> _checkRender() async {
    final r = await RenderProbe.run();
    final detail = '${r.lineCount} lines, ${r.inkPixels} ink px, ${r.elapsed.inMilliseconds} ms';
    return r.ok
        ? DoctorCheck.ok('text rendering (dart:ui)', detail)
        : DoctorCheck.fail('text rendering (dart:ui)', detail);
  }

  Future<DoctorCheck> _checkOpenCv() async {
    final image = RgbImage.filled(8, 8, 10, 20, 30);
    final decoded = ImageCodec.decode(ImageCodec.encodePng(image));
    final same = decoded.width == 8 && decoded.data[0] == 10 && decoded.data[2] == 30;
    return same
        ? DoctorCheck.ok('image codecs (OpenCV)', 'PNG encode/decode works')
        : DoctorCheck.fail('image codecs (OpenCV)', 'PNG round trip returned different pixels');
  }

  Future<List<DoctorCheck>> _checkOnnxRuntime() async {
    final r = await OrtSelfTest.run();
    if (r.error != null) return [DoctorCheck.fail('ONNX Runtime', r.error!)];
    return [
      r.cpuOk
          ? DoctorCheck.ok('ONNX Runtime (CPU)', '${r.version}, ${r.providers.join(', ')}')
          : DoctorCheck.fail('ONNX Runtime (CPU)', 'test model returned wrong values'),
      if (!r.directmlRequested)
        DoctorCheck.warn('ONNX Runtime (GPU, DirectML)', 'not available in this build/platform; CPU is used')
      else if (r.directmlOk)
        DoctorCheck.ok('ONNX Runtime (GPU, DirectML)', 'works (high-performance adapter preferred)')
      else
        DoctorCheck.warn('ONNX Runtime (GPU, DirectML)', 'falls back to CPU: ${r.directmlFallbackReason ?? 'unknown'}'),
    ];
  }

  Future<DoctorCheck> _checkSecrets() async {
    final n = (await ctx.services.secrets.keys()).length;
    return DoctorCheck.ok('secure storage', 'available, $n secret(s) stored');
  }

  Future<List<DoctorCheck>> _checkModels() async {
    final checks = <DoctorCheck>[];
    for (final m in ModelCatalog.all) {
      final status = await ctx.services.models.status(m);
      final name = 'model ${m.id}';
      checks.add(switch (status) {
        ModelStatus.installed => DoctorCheck.ok(name, 'downloaded'),
        ModelStatus.missing =>
          DoctorCheck.warn(name, 'not downloaded (${formatBytes(m.totalSize)}): cts models download ${m.id}'),
        ModelStatus.corrupt =>
          DoctorCheck.fail(name, 'damaged: run cts models delete ${m.id} && cts models download ${m.id}'),
      });
    }
    return checks;
  }
}
