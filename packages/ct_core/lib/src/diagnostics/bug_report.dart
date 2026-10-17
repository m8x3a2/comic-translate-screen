import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../app_paths.dart';
import 'redactor.dart';

/// Builds `bugreport-<ts>.zip`: everything needed to diagnose a problem,
/// with secrets masked. Page images are included only on request.
class BugReportBuilder {
  BugReportBuilder({required this.paths, required this.redactor});

  final AppPaths paths;
  final Redactor redactor;

  /// Max bytes of the app log tail to include.
  static const appLogTailBytes = 4 * 1024 * 1024;

  static const _textExtensions = {'.json', '.jsonl', '.txt', '.log', '.md', '.csv'};
  static const _imageExtensions = {'.png', '.jpg', '.jpeg', '.webp', '.bmp'};

  Future<File> build({
    required Map<String, Object?> environment,
    String? runId,
    bool includeImages = false,
    String? userNote,
    File? output,
  }) async {
    final archive = Archive();
    final now = DateTime.now();
    final manifest = <String, Object?>{
      'created': now.toUtc().toIso8601String(),
      'include_images': includeImages,
      'run_id': runId,
      'files': <String>[],
    };
    final files = manifest['files'] as List<String>;

    void addText(String name, String text) {
      final bytes = utf8.encode(redactor.redact(text));
      archive.addFile(ArchiveFile(name, bytes.length, bytes));
      files.add(name);
    }

    addText('env.json', const JsonEncoder.withIndent('  ').convert(redactor.redactJson(environment)));
    if (userNote != null && userNote.trim().isNotEmpty) addText('note.txt', userNote);

    if (paths.settingsFile.existsSync()) {
      final raw = await paths.settingsFile.readAsString();
      Object? decoded;
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        decoded = raw;
      }
      addText('settings.json', const JsonEncoder.withIndent('  ').convert(redactor.redactJson(decoded)));
    }

    if (paths.appLog.existsSync()) {
      addText('logs/app.jsonl', await _tail(paths.appLog, appLogTailBytes));
    }

    final runDir = _resolveRun(runId);
    if (runDir != null) {
      manifest['run_id'] = p.basename(runDir.path);
      await for (final entity in runDir.list(recursive: true)) {
        if (entity is! File) continue;
        final rel = p.relative(entity.path, from: runDir.path).replaceAll('\\', '/');
        final ext = p.extension(entity.path).toLowerCase();
        final name = 'run/$rel';
        if (_textExtensions.contains(ext)) {
          addText(name, await entity.readAsString());
        } else if (includeImages && _imageExtensions.contains(ext)) {
          final bytes = await entity.readAsBytes();
          archive.addFile(ArchiveFile(name, bytes.length, bytes));
          files.add(name);
        }
      }
    }

    addText('manifest.json', const JsonEncoder.withIndent('  ').convert(manifest));

    final out = output ??
        File(p.join(paths.reports.path, 'bugreport-${_stamp(now)}.zip'));
    await out.parent.create(recursive: true);
    await out.writeAsBytes(ZipEncoder().encode(archive), flush: true);
    return out;
  }

  /// [runId] null → latest run, if any.
  Directory? _resolveRun(String? runId) {
    if (!paths.runs.existsSync()) return null;
    if (runId != null) {
      final dir = Directory(p.join(paths.runs.path, runId));
      return dir.existsSync() ? dir : null;
    }
    final runs = paths.runs.listSync().whereType<Directory>().toList()
      ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    return runs.isEmpty ? null : runs.last;
  }

  static Future<String> _tail(File file, int maxBytes) async {
    final length = await file.length();
    final raf = await file.open();
    try {
      final start = length > maxBytes ? length - maxBytes : 0;
      await raf.setPosition(start);
      final bytes = await raf.read(length - start);
      var text = utf8.decode(bytes, allowMalformed: true);
      if (start > 0) {
        final firstNewline = text.indexOf('\n');
        if (firstNewline >= 0) text = text.substring(firstNewline + 1);
      }
      return text;
    } finally {
      await raf.close();
    }
  }

  static String _stamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}${two(t.second)}';
  }
}
