import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../cancel.dart';
import '../diagnostics/event_log.dart';
import '../diagnostics/log_event.dart';
import 'model_catalog.dart';

enum ModelStatus {
  /// All files present and verified.
  installed,

  /// At least one file is missing.
  missing,

  /// A file exists but its size or checksum is wrong.
  corrupt,
}

/// Thrown when a model is needed but not downloaded and downloading was not
/// allowed. The message tells the user how to get it.
class ModelNotInstalledException implements Exception {
  ModelNotInstalledException(this.spec);

  final ModelSpec spec;

  @override
  String toString() =>
      'Model "${spec.displayName}" is not downloaded '
      '(${formatBytes(spec.totalSize)} from ${spec.hosts.join(', ')}). '
      'Download it in Settings or run: cts models download ${spec.id}';
}

class ModelDownloadException implements Exception {
  ModelDownloadException(this.message, {this.network = false});

  final String message;

  /// The connection failed or broke: worth trying again (the download
  /// resumes where it stopped).
  final bool network;

  @override
  String toString() => 'ModelDownloadException: $message';
}

/// Progress of a model download in bytes across all its files.
class DownloadProgress {
  const DownloadProgress(this.received, this.total, this.file);

  final int received;
  final int total;
  final String file;

  double get fraction => total <= 0 ? 0 : received / total;
}

/// Downloads, verifies and locates models under `models/<model id>/`.
///
/// Downloads never start implicitly: callers pass `allowDownload: true` only
/// after the user agreed (GUI dialog) or asked for it (`cts models download`).
class ModelManager {
  ModelManager(
    this.root, {
    EventLog? log,
    HttpClient Function()? httpClientFactory,
    this.downloadAttempts = 4,
    this.retryDelay = const Duration(seconds: 3),
  }) : _log = log ?? EventLog.silent(),
       _httpClientFactory = httpClientFactory ?? _defaultClient;

  /// Tries per file when the connection fails or breaks (the next try
  /// resumes the partial file), waiting [retryDelay] × the try number.
  final int downloadAttempts;
  final Duration retryDelay;

  final Directory root;
  final EventLog _log;
  final HttpClient Function() _httpClientFactory;

  static const userAgent = 'ComicTranslateScreen-ModelManager';

  static HttpClient _defaultClient() => HttpClient()
    ..findProxy = HttpClient.findProxyFromEnvironment
    ..connectionTimeout = const Duration(seconds: 30)
    ..userAgent = userAgent;

  Directory dirOf(ModelSpec spec) => Directory(p.join(root.path, spec.id));

  File fileOf(ModelSpec spec, String name) => File(p.join(dirOf(spec).path, name));

  /// Path of [name] in [spec], downloading first if [allowDownload].
  Future<String> ensureFile(
    ModelSpec spec,
    String name, {
    bool allowDownload = false,
    void Function(DownloadProgress)? onProgress,
    CancelToken? cancel,
  }) async {
    await ensure(spec, allowDownload: allowDownload, onProgress: onProgress, cancel: cancel);
    return fileOf(spec, name).path;
  }

  Future<void> ensure(
    ModelSpec spec, {
    bool allowDownload = false,
    void Function(DownloadProgress)? onProgress,
    CancelToken? cancel,
  }) async {
    if (await status(spec) == ModelStatus.installed) return;
    if (!allowDownload) throw ModelNotInstalledException(spec);
    await download(spec, onProgress: onProgress, cancel: cancel);
  }

  /// Quick status: existence, size and a cached checksum marker. Use
  /// [verify] for a full re-hash.
  Future<ModelStatus> status(ModelSpec spec) async {
    var anyMissing = false;
    for (final f in spec.files) {
      final file = fileOf(spec, f.name);
      if (!file.existsSync()) {
        anyMissing = true;
        continue;
      }
      if (await file.length() != f.size) return ModelStatus.corrupt;
      if (!await _markerMatches(file, f)) {
        if (await _sha256(file) != f.sha256) return ModelStatus.corrupt;
        await _writeMarker(file, f);
      }
    }
    return anyMissing ? ModelStatus.missing : ModelStatus.installed;
  }

  /// Re-hashes every file. Returns the files that failed.
  Future<List<String>> verify(ModelSpec spec) async {
    final bad = <String>[];
    for (final f in spec.files) {
      final file = fileOf(spec, f.name);
      if (!file.existsSync() || await _sha256(file) != f.sha256) {
        bad.add(f.name);
      } else {
        await _writeMarker(file, f);
      }
    }
    _log.info('model_verify', {'model': spec.id, 'bad': bad});
    return bad;
  }

  Future<void> delete(ModelSpec spec) async {
    final dir = dirOf(spec);
    if (dir.existsSync()) await dir.delete(recursive: true);
    _log.info('model_delete', {'model': spec.id});
  }

  /// Installs model files from disk, for computers without internet: every
  /// file (also inside folders and zip archives) whose size and SHA-256 match
  /// a file of [catalog] is copied into place. Other files are reported as
  /// not matching.
  Future<List<ModelImportResult>> importFiles(List<String> paths, {List<ModelSpec> catalog = ModelCatalog.all}) async {
    final bySize = <int, List<(ModelSpec, ModelFile)>>{};
    for (final spec in catalog) {
      for (final f in spec.files) {
        (bySize[f.size] ??= []).add((spec, f));
      }
    }
    final results = <ModelImportResult>[];
    final staging = Directory(p.join(root.path, '_import'));

    Future<void> offer(File file, String label) async {
      final candidates = bySize[await file.length()];
      if (candidates == null) {
        results.add(ModelImportResult(label, error: 'not a known model file'));
        return;
      }
      final hash = await _sha256(file);
      for (final (spec, f) in candidates) {
        if (f.sha256 != hash) continue;
        final target = fileOf(spec, f.name);
        await target.parent.create(recursive: true);
        final part = File('${target.path}.importing');
        await file.copy(part.path);
        if (target.existsSync()) await target.delete();
        await part.rename(target.path);
        await _writeMarker(target, f);
        _log.info('model_import', {'model': spec.id, 'file': f.name});
        results.add(ModelImportResult(label, model: spec.id, file: f.name));
        return;
      }
      results.add(ModelImportResult(label, error: 'checksum does not match any known model file'));
    }

    try {
      for (final path in paths) {
        if (FileSystemEntity.isDirectorySync(path)) {
          for (final f in Directory(path).listSync(recursive: true).whereType<File>()) {
            await offer(f, f.path);
          }
        } else if (p.extension(path).toLowerCase() == '.zip') {
          final input = InputFileStream(path);
          try {
            for (final entry in ZipDecoder().decodeStream(input).files) {
              if (!entry.isFile) continue;
              if (!bySize.containsKey(entry.size)) {
                results.add(ModelImportResult('$path/${entry.name}', error: 'not a known model file'));
                continue;
              }
              await staging.create(recursive: true);
              final tmp = File(p.join(staging.path, 'entry'));
              final out = OutputFileStream(tmp.path);
              try {
                entry.writeContent(out);
              } finally {
                await out.close();
              }
              await offer(tmp, '$path/${entry.name}');
              await tmp.delete();
            }
          } finally {
            await input.close();
          }
        } else if (File(path).existsSync()) {
          await offer(File(path), path);
        } else {
          results.add(ModelImportResult(path, error: 'file not found'));
        }
      }
    } finally {
      if (staging.existsSync()) await staging.delete(recursive: true);
    }
    return results;
  }

  /// Downloads missing or broken files, resuming partial downloads.
  Future<void> download(ModelSpec spec, {void Function(DownloadProgress)? onProgress, CancelToken? cancel}) async {
    final token = cancel ?? CancelToken.none;
    await dirOf(spec).create(recursive: true);
    final total = spec.totalSize;
    var doneBefore = 0;
    final log = _log.child(stage: 'model_download');
    log.info('model_download_start', {'model': spec.id, 'bytes': total, 'hosts': spec.hosts.toList()});
    final sw = Stopwatch()..start();
    try {
      for (final f in spec.files) {
        token.throwIfCancelled();
        final target = fileOf(spec, f.name);
        if (target.existsSync() && await target.length() == f.size && await _sha256(target) == f.sha256) {
          await _writeMarker(target, f);
        } else {
          for (var attempt = 1; ; attempt++) {
            try {
              await _downloadFile(f, target, token, (received) {
                onProgress?.call(DownloadProgress(doneBefore + received, total, f.name));
              });
              break;
            } on ModelDownloadException catch (e) {
              if (!e.network || attempt >= downloadAttempts) rethrow;
              log.warn('model_download_retry', {
                'model': spec.id,
                'file': f.name,
                'attempt': attempt,
                'error': e.message,
              });
              await token.wait(retryDelay * attempt);
            }
          }
        }
        doneBefore += f.size;
        onProgress?.call(DownloadProgress(doneBefore, total, f.name));
      }
      log.log(LogLevel.info, 'model_download_end', durMs: sw.elapsedMilliseconds, data: {'model': spec.id});
    } catch (e, st) {
      if (e is CancelledException) {
        log.info('model_download_cancelled', {'model': spec.id});
      } else {
        log.error('model_download_failed', e, st, {'model': spec.id});
      }
      rethrow;
    }
  }

  Future<void> _downloadFile(ModelFile f, File target, CancelToken cancel, void Function(int) onBytes) async {
    final part = File('${target.path}.part');
    var offset = part.existsSync() ? await part.length() : 0;
    if (offset > f.size) {
      await part.delete();
      offset = 0;
    }

    final client = _httpClientFactory();
    cancel.onCancel(() => client.close(force: true));
    try {
      if (offset < f.size) {
        final request = await client.getUrl(Uri.parse(f.url));
        if (offset > 0) request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
        final response = await request.close();
        if (response.statusCode == HttpStatus.ok) {
          offset = 0; // server ignored the range: restart
        } else if (response.statusCode != HttpStatus.partialContent) {
          await response.drain<void>();
          throw ModelDownloadException('GET ${f.url} failed with HTTP ${response.statusCode}');
        }
        final sink = part.openWrite(mode: offset == 0 ? FileMode.write : FileMode.append);
        var received = offset;
        try {
          await for (final chunk in response) {
            if (cancel.isCancelled) break;
            sink.add(chunk);
            received += chunk.length;
            onBytes(received);
          }
        } finally {
          await sink.flush();
          await sink.close();
        }
        cancel.throwIfCancelled();
      }
    } on SocketException catch (e) {
      cancel.throwIfCancelled();
      throw ModelDownloadException('Network error while downloading ${f.name}: ${e.message}', network: true);
    } on HttpException catch (e) {
      cancel.throwIfCancelled();
      throw ModelDownloadException('Network error while downloading ${f.name}: ${e.message}', network: true);
    } on TlsException catch (e) {
      cancel.throwIfCancelled();
      throw ModelDownloadException('Secure connection broke while downloading ${f.name}: ${e.message}', network: true);
    } finally {
      client.close(force: true);
    }

    final size = await part.length();
    if (size != f.size) {
      throw ModelDownloadException(
        '${f.name}: expected ${f.size} bytes, got $size (download incomplete, retry to resume)',
        network: true,
      );
    }
    final actual = await _sha256(part);
    if (actual != f.sha256) {
      await part.delete();
      throw ModelDownloadException('${f.name}: checksum mismatch (expected ${f.sha256}, got $actual); file deleted');
    }
    if (target.existsSync()) await target.delete();
    await part.rename(target.path);
    await _writeMarker(target, f);
  }

  // A small sidecar file records that the file was hashed at a given size and
  // modification time, so startup does not re-hash hundreds of megabytes.
  File _marker(File file) => File('${file.path}.verified');

  Future<bool> _markerMatches(File file, ModelFile f) async {
    final marker = _marker(file);
    if (!marker.existsSync()) return false;
    final stat = await file.stat();
    return (await marker.readAsString()).trim() == '${f.sha256} ${stat.size} ${stat.modified.millisecondsSinceEpoch}';
  }

  Future<void> _writeMarker(File file, ModelFile f) async {
    final stat = await file.stat();
    await _marker(file).writeAsString('${f.sha256} ${stat.size} ${stat.modified.millisecondsSinceEpoch}');
  }

  static Future<String> _sha256(File file) async => (await sha256.bind(file.openRead()).first).toString();
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB'];
  var v = bytes / 1024;
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 ? 0 : 1)} ${units[i]}';
}

/// What [ModelManager.importFiles] did with one file.
class ModelImportResult {
  const ModelImportResult(this.path, {this.model, this.file, this.error});

  /// The file given, or `archive.zip/entry` for files inside a zip.
  final String path;

  /// Id and file name of the model file it was installed as.
  final String? model;
  final String? file;

  /// Why it was not installed.
  final String? error;

  bool get imported => model != null;
}
