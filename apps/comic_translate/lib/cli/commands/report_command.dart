import 'dart:io';

import 'package:ct_core/ct_core.dart';

import '../cli.dart';
import '../cli_context.dart';

class ReportCommand extends CtsCommand {
  ReportCommand(super.holder) {
    argParser
      ..addOption('run', help: 'Run id to include (default: latest run).')
      ..addFlag('with-images', negatable: false, help: 'Include page images and stage artifacts.')
      ..addOption('note', help: 'Free-text description of the problem.')
      ..addOption('output', abbr: 'o', help: 'Output zip path.', valueHelp: 'file.zip');
  }

  @override
  String get name => 'report';

  @override
  String get description =>
      'Build a bug report zip (logs, environment, last run). Secrets are masked; '
      'images are included only with --with-images.';

  @override
  Future<int> run() async {
    final args = argResults!;
    final services = ctx.services;
    // Make sure everything logged so far is on disk before it is zipped.
    await services.appLog.flush();
    final output = args.option('output');
    final zip = await BugReportBuilder(paths: services.paths, redactor: services.redactor).build(
      environment: services.environment(),
      runId: args.option('run'),
      includeImages: args.flag('with-images'),
      userNote: args.option('note'),
      output: output == null ? null : File(output),
    );
    services.appLog.info('bug_report', {'file': zip.path, 'with_images': args.flag('with-images')});
    if (ctx.json) {
      ctx.printJson({'file': zip.path, 'bytes': zip.lengthSync()});
    } else {
      ctx.say('Bug report: ${zip.path}');
      ctx.say('Secrets and your user folder path are masked. Send this file to the developer.');
    }
    return ExitCodes.ok;
  }
}
