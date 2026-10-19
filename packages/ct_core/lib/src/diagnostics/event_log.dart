import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'log_event.dart';
import 'redactor.dart';

abstract interface class LogSink {
  void write(LogEvent event);
  Future<void> flush();
  Future<void> close();
}

/// Appends redacted JSONL lines to a file.
class JsonlFileSink implements LogSink {
  JsonlFileSink(File file, this._redactor)
      : _sink = (file..parent.createSync(recursive: true))
            .openWrite(mode: FileMode.append, encoding: utf8);

  final IOSink _sink;
  final Redactor _redactor;

  @override
  void write(LogEvent event) => _sink.writeln(encodeLine(event, _redactor));

  /// The exact line written for [event]: JSON-level redaction followed by a
  /// final text pass over the encoded line.
  static String encodeLine(LogEvent event, Redactor redactor) =>
      redactor.redact(jsonEncode(redactor.redactJson(event.toJson())));

  @override
  Future<void> flush() => _sink.flush();

  @override
  Future<void> close() async {
    await _sink.flush();
    await _sink.close();
  }
}

/// Keeps redacted events in memory; used by tests and the GUI log viewer.
class MemorySink implements LogSink {
  MemorySink(this._redactor);

  final Redactor _redactor;
  final List<String> lines = [];

  List<LogEvent> get events => lines
      .map((l) => LogEvent.fromJson((jsonDecode(l) as Map).cast<String, Object?>()))
      .toList();

  @override
  void write(LogEvent event) => lines.add(JsonlFileSink.encodeLine(event, _redactor));

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {}
}

/// Human-readable output for the CLI `--verbose` flag (stderr).
class ConsoleSink implements LogSink {
  ConsoleSink(this._redactor, {IOSink? out}) : _out = out ?? stderr;

  final Redactor _redactor;
  final IOSink _out;

  @override
  void write(LogEvent e) {
    final where = [e.page, e.stage].whereType<String>().join('/');
    final dur = e.durMs != null ? ' ${e.durMs}ms' : '';
    final data = e.data.isEmpty ? '' : ' ${jsonEncode(_redactor.redactJson(e.data))}';
    _out.writeln(_redactor.redact(
        '[${e.level.name.toUpperCase()}] ${where.isEmpty ? '' : '$where '}${e.event}$dur$data'));
  }

  @override
  Future<void> flush() => _out.flush();

  @override
  Future<void> close() => flush();
}

/// Structured event logger. Context (run, page, stage) is carried by child
/// loggers created with [child].
class EventLog {
  EventLog(this._sinks, {this.minLevel = LogLevel.debug})
      : runId = null,
        page = null,
        stage = null;

  EventLog._(this._sinks, this.minLevel, this.runId, this.page, this.stage);

  /// A logger that discards everything.
  factory EventLog.silent() => EventLog(const []);

  final List<LogSink> _sinks;
  final LogLevel minLevel;
  final String? runId;
  final String? page;
  final String? stage;

  EventLog child({String? runId, String? page, String? stage}) => EventLog._(
        _sinks,
        minLevel,
        runId ?? this.runId,
        page ?? this.page,
        stage ?? this.stage,
      );

  void log(
    LogLevel level,
    String event, {
    Map<String, Object?>? data,
    int? durMs,
  }) {
    if (level.index < minLevel.index) return;
    final e = LogEvent(
      level: level,
      event: event,
      runId: runId,
      page: page,
      stage: stage,
      durMs: durMs,
      data: data,
    );
    for (final sink in _sinks) {
      sink.write(e);
    }
  }

  /// Passes an event built elsewhere (e.g. in a background isolate) to the
  /// sinks unchanged.
  void write(LogEvent event) {
    if (event.level.index < minLevel.index) return;
    for (final sink in _sinks) {
      sink.write(event);
    }
  }

  void debug(String event, [Map<String, Object?>? data]) => log(LogLevel.debug, event, data: data);
  void info(String event, [Map<String, Object?>? data]) => log(LogLevel.info, event, data: data);
  void warn(String event, [Map<String, Object?>? data]) => log(LogLevel.warn, event, data: data);

  void error(String event, Object error, [StackTrace? stackTrace, Map<String, Object?>? data]) =>
      log(LogLevel.error, event, data: {
        ...?data,
        'error': error.toString(),
        'error_type': error.runtimeType.toString(),
        if (stackTrace != null) 'stack': stackTrace.toString(),
      });

  /// Runs [body] as a named stage, logging `stage_start` / `stage_end` (with
  /// duration) or `stage_error`.
  Future<T> timed<T>(String stage, Future<T> Function(EventLog log) body,
      {Map<String, Object?>? data}) async {
    final log = child(stage: stage);
    final sw = Stopwatch()..start();
    log.debug('stage_start', data);
    try {
      final result = await body(log);
      log.log(LogLevel.info, 'stage_end', durMs: sw.elapsedMilliseconds, data: data);
      return result;
    } catch (e, st) {
      log.log(LogLevel.error, 'stage_error', durMs: sw.elapsedMilliseconds, data: {
        ...?data,
        'error': e.toString(),
        'error_type': e.runtimeType.toString(),
        'stack': st.toString(),
      });
      rethrow;
    }
  }

  Future<void> flush() => Future.wait(_sinks.map((s) => s.flush()));
  Future<void> close() => Future.wait(_sinks.map((s) => s.close()));
}
