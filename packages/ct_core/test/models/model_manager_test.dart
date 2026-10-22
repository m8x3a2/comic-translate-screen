import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Serves [payload] at /model.bin, honouring Range requests; can drop the
/// connection after [cutAfter] bytes once.
class FakeModelServer {
  FakeModelServer(this.payload);

  final Uint8List payload;
  int? cutAfter;
  int requests = 0;
  final List<String?> rangeHeaders = [];
  late HttpServer _server;

  Uri get url => Uri.parse('http://127.0.0.1:${_server.port}/model.bin');

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((req) async {
      requests++;
      final range = req.headers.value(HttpHeaders.rangeHeader);
      rangeHeaders.add(range);
      var start = 0;
      if (range != null) {
        start = int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
        req.response.statusCode = HttpStatus.partialContent;
      }
      final body = payload.sublist(start);
      final cut = cutAfter;
      if (cut != null) {
        // Promise the full body, send part of it, then drop the connection.
        cutAfter = null;
        req.response.contentLength = body.length;
        final socket = await req.response.detachSocket(writeHeaders: true);
        socket.add(body.sublist(0, cut));
        await socket.flush();
        socket.destroy();
        return;
      }
      req.response.contentLength = body.length;
      req.response.add(body);
      await req.response.close();
    });
  }

  Future<void> stop() => _server.close(force: true);
}

ModelSpec specFor(Uri url, Uint8List payload, {String? sha}) => ModelSpec(
  id: 'test-model',
  displayName: 'Test model',
  purpose: 'tests',
  license: 'MIT',
  homepage: 'https://example.com',
  files: [
    ModelFile(
      name: 'model.bin',
      url: url.toString(),
      sha256: sha ?? sha256.convert(payload).toString(),
      size: payload.length,
    ),
  ],
);

void main() {
  late Directory tmp;
  late FakeModelServer server;
  final payload = Uint8List.fromList(List.generate(300000, (i) => (i * 31) & 0xff));

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('ct_models_');
    server = FakeModelServer(payload);
    await server.start();
  });

  tearDown(() async {
    await server.stop();
    tmp.deleteSync(recursive: true);
  });

  test('model files are imported from disk, folders and zip archives without network access', () async {
    final manager = ModelManager(Directory(p.join(tmp.path, 'models')));
    final spec = specFor(server.url, payload);
    final src = Directory(p.join(tmp.path, 'usb'))..createSync();
    final file = File(p.join(src.path, 'whatever-name.onnx'))..writeAsBytesSync(payload);
    final other = File(p.join(src.path, 'notes.txt'))..writeAsStringSync('hello');
    final sameSize = File(p.join(src.path, 'fake.onnx'))..writeAsBytesSync(Uint8List(payload.length));

    var results = await manager.importFiles([sameSize.path, other.path, p.join(src.path, 'nope.bin')], catalog: [spec]);
    expect(results.map((r) => r.imported), [false, false, false]);
    expect(results.first.error, contains('checksum'));
    expect(await manager.status(spec), ModelStatus.missing);

    results = await manager.importFiles([file.path], catalog: [spec]);
    expect(results.single.model, 'test-model');
    expect(results.single.file, 'model.bin');
    expect(await manager.status(spec), ModelStatus.installed);

    await manager.delete(spec);
    final zip = File(p.join(tmp.path, 'models.zip'))
      ..writeAsBytesSync(
        ZipEncoder().encode(
          Archive()
            ..add(ArchiveFile.bytes('pack/model.bin', payload))
            ..add(ArchiveFile.bytes('pack/readme.txt', 'hi'.codeUnits)),
        ),
      );
    results = await manager.importFiles([zip.path], catalog: [spec]);
    expect(results.where((r) => r.imported).single.path, endsWith('pack/model.bin'));
    expect(await manager.status(spec), ModelStatus.installed);
    expect(Directory(p.join(tmp.path, 'models', '_import')).existsSync(), isFalse);

    await manager.delete(spec);
    results = await manager.importFiles([src.path], catalog: [spec]);
    expect(results.where((r) => r.imported), hasLength(1));
    expect(server.requests, 0);
  });

  test('missing model is not downloaded without permission', () async {
    final manager = ModelManager(tmp);
    final spec = specFor(server.url, payload);
    expect(await manager.status(spec), ModelStatus.missing);
    await expectLater(manager.ensure(spec), throwsA(isA<ModelNotInstalledException>()));
    expect(server.requests, 0);
  });

  test('download verifies, reports progress and installs', () async {
    final mem = MemorySink(Redactor());
    final manager = ModelManager(tmp, log: EventLog([mem]));
    final spec = specFor(server.url, payload);
    final progress = <double>[];
    final path = await manager.ensureFile(
      spec,
      'model.bin',
      allowDownload: true,
      onProgress: (p) => progress.add(p.fraction),
    );
    expect(File(path).readAsBytesSync(), payload);
    expect(progress.last, 1.0);
    expect(await manager.status(spec), ModelStatus.installed);
    expect(mem.events.map((e) => e.event), containsAll(['model_download_start', 'model_download_end']));
    // A second ensure does not hit the network.
    await manager.ensure(spec);
    expect(server.requests, 1);
  });

  test('interrupted download resumes with a Range request', () async {
    final manager = ModelManager(tmp, downloadAttempts: 1);
    final spec = specFor(server.url, payload);
    server.cutAfter = 100000;
    await expectLater(manager.download(spec), throwsA(isA<ModelDownloadException>()));
    expect(File('${manager.fileOf(spec, 'model.bin').path}.part').lengthSync(), 100000);

    await manager.download(spec);
    expect(server.rangeHeaders.last, 'bytes=100000-');
    expect(manager.fileOf(spec, 'model.bin').readAsBytesSync(), payload);
  });

  test('a broken connection is tried again at once, resuming the file', () async {
    final mem = MemorySink(Redactor());
    final manager = ModelManager(tmp, log: EventLog([mem]), retryDelay: const Duration(milliseconds: 10));
    final spec = specFor(server.url, payload);
    server.cutAfter = 100000;
    await manager.download(spec);
    expect(server.rangeHeaders.last, 'bytes=100000-');
    expect(manager.fileOf(spec, 'model.bin').readAsBytesSync(), payload);
    expect(mem.events.map((e) => e.event), contains('model_download_retry'));
  });

  test('a server that cannot be reached fails after the tries, as a network error', () async {
    final spec = specFor(server.url, payload);
    await server.stop();
    final manager = ModelManager(tmp, retryDelay: const Duration(milliseconds: 10));
    await expectLater(
      manager.download(spec),
      throwsA(isA<ModelDownloadException>().having((e) => e.network, 'network', isTrue)),
    );
    await server.start();
  });

  test('checksum mismatch deletes the file and fails', () async {
    final manager = ModelManager(tmp);
    final spec = specFor(server.url, payload, sha: '0' * 64);
    await expectLater(manager.download(spec), throwsA(isA<ModelDownloadException>()));
    expect(manager.fileOf(spec, 'model.bin').existsSync(), isFalse);
    expect(File('${manager.fileOf(spec, 'model.bin').path}.part').existsSync(), isFalse);
  });

  test('tampered file is reported as corrupt and verify finds it', () async {
    final manager = ModelManager(tmp);
    final spec = specFor(server.url, payload);
    await manager.download(spec);
    final file = manager.fileOf(spec, 'model.bin');
    final bytes = file.readAsBytesSync()..[10] ^= 0xff;
    file.writeAsBytesSync(bytes);
    expect(await manager.status(spec), ModelStatus.corrupt);
    expect(await manager.verify(spec), ['model.bin']);
  });

  test('cancel stops the download', () async {
    final manager = ModelManager(tmp);
    final spec = specFor(server.url, payload);
    final cancel = CancelToken();
    final future = manager.download(
      spec,
      cancel: cancel,
      onProgress: (p) {
        if (p.received > 0) cancel.cancel();
      },
    );
    await expectLater(future, throwsA(isA<CancelledException>()));
    expect(manager.fileOf(spec, 'model.bin').existsSync(), isFalse);
  });

  test('catalog entries are well-formed', () {
    for (final m in ModelCatalog.all) {
      expect(m.files, isNotEmpty);
      for (final f in m.files) {
        expect(f.sha256, matches(RegExp(r'^[0-9a-f]{64}$')), reason: m.id);
        expect(f.size, greaterThan(0));
        expect(Uri.parse(f.url).scheme, 'https');
      }
    }
    expect(ModelCatalog.byId('aot-inpainting'), same(ModelCatalog.aot));
    expect(formatBytes(206291843), '197 MB');
  });
}
