import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('ct_import_test_'));
  tearDown(() => dir.delete(recursive: true));

  final png = ImageCodec.encodePng(RgbImage.filled(4, 3, 10, 20, 30));
  const entries = ['ch1/page10.png', 'ch1/page2.png', 'ch1/Page1.png', '__MACOSX/ch1/._page2.png', 'info.txt'];

  Archive sample() {
    final a = Archive();
    for (final name in entries) {
      a.add(ArchiveFile.bytes(name, name.endsWith('.txt') ? 'hello'.codeUnits : png));
    }
    return a;
  }

  test('natural order', () {
    expect((['p10', 'P1', 'p2']..sort(naturalCompare)), ['P1', 'p2', 'p10']);
  });

  test('zip, cbz and epub: images only, in natural order, junk skipped', () async {
    final cbz = File(p.join(dir.path, 'book.cbz'))..writeAsBytesSync(ZipEncoder().encode(sample()));
    final pages = await importPages([cbz.path], cacheDir: Directory(p.join(dir.path, 'cache')));
    expect(pages.map((e) => e.name), ['Page1.png', 'page2.png', 'page10.png']);
    expect(pages.map((e) => p.basename(e.path)), ['001.png', '002.png', '003.png']);
    expect(pages.first.source, cbz.path);
    expect(ImageCodec.decode(File(pages.first.path).readAsBytesSync()).width, 4);
  });

  test('tar and cbt', () async {
    final cbt = File(p.join(dir.path, 'book.cbt'))..writeAsBytesSync(TarEncoder().encode(sample()));
    final pages = await importPages([cbt.path], cacheDir: Directory(p.join(dir.path, 'cache')));
    expect(pages.map((e) => e.name), ['Page1.png', 'page2.png', 'page10.png']);
  });

  test('folders, images and archives keep the given order; other files are listed as skipped', () async {
    final folder = Directory(p.join(dir.path, 'scans'))..createSync();
    File(p.join(folder.path, 'b.jpg')).writeAsBytesSync(png);
    File(p.join(folder.path, 'a.png')).writeAsBytesSync(png);
    final cbz = File(p.join(dir.path, 'x.zip'))..writeAsBytesSync(ZipEncoder().encode(sample()));
    final skipped = <String>[];
    final pages = await importPages(
      [cbz.path, folder.path, p.join(dir.path, 'notes.docx'), p.join(dir.path, 'one.webp')],
      cacheDir: Directory(p.join(dir.path, 'cache')),
      skipped: skipped,
    );
    expect(pages.map((e) => e.name), ['Page1.png', 'page2.png', 'page10.png', 'a.png', 'b.jpg', 'one.webp']);
    expect(skipped, [p.join(dir.path, 'notes.docx')]);
  });

  test('a broken archive gives a readable error', () async {
    final bad = File(p.join(dir.path, 'bad.cbz'))..writeAsStringSync('not a zip');
    await expectLater(importPages([bad.path], cacheDir: Directory(p.join(dir.path, 'cache'))),
        throwsA(isA<PageImportException>().having((e) => e.message, 'message', contains('bad.cbz'))));
    final errors = <String>[];
    final png = File(p.join(dir.path, 'ok.png'))..writeAsBytesSync([1]);
    final pages = await importPages([bad.path, png.path],
        cacheDir: Directory(p.join(dir.path, 'cache')), onError: (input, e) => errors.add(p.basename(input)));
    expect(pages.map((e) => e.name), ['ok.png']);
    expect(errors, ['bad.cbz']);
  });

  final sevenZip = findArchiveTool('x.cb7');
  test('cb7 through 7-Zip', () async {
    final src = Directory(p.join(dir.path, 'src', 'ch1'))..createSync(recursive: true);
    for (final n in ['page10.png', 'page2.png', 'Page1.png']) {
      File(p.join(src.path, n)).writeAsBytesSync(png);
    }
    final cb7 = p.join(dir.path, 'book.cb7');
    final r = await Process.run(sevenZip!, ['a', '-t7z', cb7, p.join(dir.path, 'src', '*')]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final pages = await importPages([cb7], cacheDir: Directory(p.join(dir.path, 'cache')));
    expect(pages.map((e) => e.name), ['Page1.png', 'page2.png', 'page10.png']);
    expect(Directory(p.join(p.dirname(pages.first.path), '_unpack')).existsSync(), isFalse);
  }, skip: sevenZip == null ? '7-Zip is not installed' : false);
}
