import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:ct_core/ct_core.dart';

import '../bootstrap.dart';
import 'cli_context.dart';
import 'commands/doctor_command.dart';
import 'commands/report_command.dart';
import 'commands/selftest_command.dart';
import 'commands/version_command.dart';

/// Holds the context created after global options are parsed; commands read
/// it lazily because CommandRunner constructs them up front.
class CliContextHolder {
  CliContext? _context;
  CliContext get context => _context ?? (throw StateError('CLI context not initialized'));
}

/// Base class for `cts` commands.
abstract class CtsCommand extends Command<int> {
  CtsCommand(this._holder);

  final CliContextHolder _holder;
  CliContext get ctx => _holder.context;
}

CommandRunner<int> buildRunner(CliContextHolder holder) {
  final runner = CommandRunner<int>(
    'cts',
    'Comic Translate Screen — command-line interface.\n'
        'All pipeline functions are available here for testing without the GUI.',
  )
    ..argParser.addOption('data-dir',
        help: 'Data directory (logs, runs, models). '
            'Defaults to \$${AppPaths.dataDirEnv} or %LOCALAPPDATA%\\${AppPaths.windowsFolderName}.')
    ..argParser.addFlag('json', negatable: false, help: 'Print one JSON document to stdout.')
    ..argParser.addFlag('verbose', abbr: 'v', negatable: false, help: 'Print log events to stderr.');

  runner
    ..addCommand(VersionCommand(holder))
    ..addCommand(DoctorCommand(holder))
    ..addCommand(SelftestCommand(holder))
    ..addCommand(ReportCommand(holder));
  return runner;
}

/// Entry point for `cts.exe`. Returns the process exit code.
Future<int> runCli(List<String> args, {IOSink? out, IOSink? err, String? dataDirOverride}) async {
  final stderrSink = err ?? stderr;
  final holder = CliContextHolder();
  final runner = buildRunner(holder);

  final ArgResults results;
  try {
    results = runner.parse(args);
  } on UsageException catch (e) {
    stderrSink
      ..writeln(e.message)
      ..writeln()
      ..writeln(e.usage);
    return ExitCodes.usage;
  }

  final verbose = results.flag('verbose');
  final redactorForConsole = Redactor(homeDir: AppPaths.homeDir());
  final services = AppServices.create(
    dataDirOverride: dataDirOverride ?? results.option('data-dir'),
    extraSinks: [if (verbose) ConsoleSink(redactorForConsole, out: stderrSink)],
  );
  holder._context = CliContext(
    services: services,
    json: results.flag('json'),
    verbose: verbose,
    out: out,
    err: stderrSink,
  );

  final log = services.appLog.child(stage: 'cli');
  log.info('cli_command', {'args': args});
  try {
    final code = await runner.runCommand(results) ?? ExitCodes.ok;
    log.info('cli_exit', {'code': code});
    return code;
  } on UsageException catch (e) {
    stderrSink
      ..writeln(e.message)
      ..writeln()
      ..writeln(e.usage);
    return ExitCodes.usage;
  } catch (e, st) {
    log.error('cli_crash', e, st);
    stderrSink.writeln(services.redactor.redact('Error: $e'));
    stderrSink.writeln('Details are in ${services.paths.appLog.path}. '
        'Run `cts report` to build a bug report.');
    return ExitCodes.internal;
  } finally {
    await services.dispose();
  }
}
