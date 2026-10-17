import 'dart:convert';
import 'dart:io';

import '../bootstrap.dart';

/// Exit codes used by `cts`.
abstract final class ExitCodes {
  static const ok = 0;
  static const failure = 1;
  static const usage = 64; // sysexits EX_USAGE
  static const internal = 70; // sysexits EX_SOFTWARE
}

/// Everything a command needs: services, output mode and streams.
class CliContext {
  CliContext({
    required this.services,
    required this.json,
    required this.verbose,
    IOSink? out,
    IOSink? err,
  })  : out = out ?? stdout,
        err = err ?? stderr;

  final AppServices services;

  /// `--json`: print exactly one JSON document to stdout.
  final bool json;
  final bool verbose;
  final IOSink out;
  final IOSink err;

  void printJson(Object? value) =>
      out.writeln(const JsonEncoder.withIndent('  ').convert(value));

  /// Human-readable line; suppressed in `--json` mode.
  void say(String line) {
    if (!json) out.writeln(line);
  }
}
