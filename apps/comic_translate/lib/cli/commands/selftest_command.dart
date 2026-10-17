import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../../render/render_probe.dart';
import '../cli.dart';
import '../cli_context.dart';

class SelftestCommand extends Command<int> {
  SelftestCommand(CliContextHolder holder) {
    addSubcommand(_RenderSelftest(holder));
  }

  @override
  String get name => 'selftest';

  @override
  String get description => 'Built-in checks of individual subsystems.';
}

class _RenderSelftest extends CtsCommand {
  _RenderSelftest(super.holder) {
    argParser.addOption('output', abbr: 'o', help: 'Where to write the PNG.', valueHelp: 'file.png');
  }

  @override
  String get name => 'render';

  @override
  String get description => 'Render sample text with dart:ui and save it as PNG.';

  @override
  Future<int> run() async {
    final result = await RenderProbe.run();
    final out = File(argResults!.option('output') ??
        p.join(ctx.services.paths.reports.path, 'selftest-render.png'));
    await out.parent.create(recursive: true);
    await out.writeAsBytes(result.png, flush: true);
    ctx.services.appLog.info('selftest_render', result.toJson());

    if (ctx.json) {
      ctx.printJson({...result.toJson(), 'file': out.path});
    } else {
      ctx.say('${result.ok ? 'OK' : 'FAILED'}: ${result.lineCount} lines, '
          '${result.inkPixels} ink pixels, ${result.elapsed.inMilliseconds} ms');
      ctx.say('Saved ${out.path}');
    }
    return result.ok ? ExitCodes.ok : ExitCodes.failure;
  }
}
