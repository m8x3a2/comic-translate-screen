import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import 'event_log.dart';
import 'redactor.dart';

/// Records one processing run in test mode: JSONL events, per-stage
/// artifacts (masks, boxes, OCR text, before/after images), timings and the
/// environment snapshot.
///
/// Layout:
/// ```
/// runs/<run_id>/
///   env.json
///   events.jsonl
///   timings.json
///   result.json
///   pages/<page>/<stage>/<artifact>
/// ```
class RunRecorder {
  RunRecorder._(this.runId, this.dir, this.log, this._redactor, this.saveArtifacts,
      this._fileSink, this._started);

  final String runId;
  final Directory dir;
  final EventLog log;
  final bool saveArtifacts;
  final Redactor _redactor;
  final JsonlFileSink _fileSink;
  final DateTime _started;
  final List<Map<String, Object?>> _timings = [];

  static Future<RunRecorder> start({
    required Directory runsDir,
    required Redactor redactor,
    required Map<String, Object?> environment,
    bool saveArtifacts = true,
    List<LogSink> extraSinks = const [],
    String? label,
  }) async {
    final now = DateTime.now();
    final runId = newRunId(now, label: label);
    final dir = Directory(p.join(runsDir.path, runId));
    await dir.create(recursive: true);
    final sink = JsonlFileSink(File(p.join(dir.path, 'events.jsonl')), redactor);
    final log = EventLog([sink, ...extraSinks]).child(runId: runId);
    final recorder =
        RunRecorder._(runId, dir, log, redactor, saveArtifacts, sink, now);
    await recorder._writeJson(File(p.join(dir.path, 'env.json')), environment);
    log.info('run_start', {'save_artifacts': saveArtifacts, 'label': ?label});
    return recorder;
  }

  /// `20261017-203015-ab12` (+ `-label`): sortable and unique enough.
  static String newRunId(DateTime now, {String? label}) {
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final rnd = Random().nextInt(0xffff).toRadixString(16).padLeft(4, '0');
    final safeLabel = label == null ? '' : '-${sanitize(label)}';
    return '$stamp-$rnd$safeLabel';
  }

  /// Makes a string safe for use as a single path segment.
  static String sanitize(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^A-Za-z0-9._\-]+'), '_');
    final trimmed = cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned;
    return trimmed.isEmpty ? '_' : trimmed;
  }

  Directory stageDir(String stage, {String? page}) => Directory(p.joinAll([
        dir.path,
        if (page != null) ...['pages', sanitize(page)],
        sanitize(stage),
      ]));

  /// Saves a binary artifact (PNG etc.). No-op unless [saveArtifacts].
  Future<File?> writeArtifact(String stage, String name, List<int> bytes, {String? page}) async {
    if (!saveArtifacts) return null;
    final file = File(p.join(stageDir(stage, page: page).path, sanitize(name)));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    log.child(page: page, stage: stage).debug('artifact', {'file': p.relative(file.path, from: dir.path), 'bytes': bytes.length});
    return file;
  }

  /// Saves a JSON artifact; content is redacted. No-op unless [saveArtifacts].
  Future<File?> writeJsonArtifact(String stage, String name, Object? json, {String? page}) async {
    if (!saveArtifacts) return null;
    final file = File(p.join(stageDir(stage, page: page).path, sanitize(name)));
    await _writeJson(file, json);
    log.child(page: page, stage: stage).debug('artifact', {'file': p.relative(file.path, from: dir.path)});
    return file;
  }

  void recordTiming(String stage, Duration duration, {String? page}) {
    _timings.add({
      'page': ?page,
      'stage': stage,
      'dur_ms': duration.inMilliseconds,
    });
  }

  Future<void> finish({required bool success, Map<String, Object?>? summary}) async {
    final total = DateTime.now().difference(_started);
    await _writeJson(File(p.join(dir.path, 'timings.json')), {
      'total_ms': total.inMilliseconds,
      'stages': _timings,
    });
    await _writeJson(File(p.join(dir.path, 'result.json')), {
      'success': success,
      'total_ms': total.inMilliseconds,
      ...?summary,
    });
    log.info('run_end', {'success': success, 'total_ms': total.inMilliseconds});
    await _fileSink.close();
  }

  Future<void> _writeJson(File file, Object? json) async {
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    final text = _redactor.redact(encoder.convert(_redactor.redactJson(json)));
    await file.writeAsString(text, flush: true);
  }
}
