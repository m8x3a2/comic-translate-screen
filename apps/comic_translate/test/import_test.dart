import 'dart:convert';
import 'dart:io';

import 'package:comic_translate/import/pdf_pages.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// A two-page PDF (144×72 pt each): the left half of every page is red.
List<int> _samplePdf() {
  const content = '1 0 0 rg 0 0 72 72 re f';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R 4 0 R] /Count 2 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 144 72] /Contents 5 0 R >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 144 72] /Contents 5 0 R >>',
    '<< /Length ${content.length} >>\nstream\n$content\nendstream',
  ];
  final out = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (final (i, o) in objects.indexed) {
    offsets.add(out.length);
    out.write('${i + 1} 0 obj\n$o\nendobj\n');
  }
  final xref = out.length;
  out.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final o in offsets) {
    out.write('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  out.write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
  return latin1.encode(out.toString());
}

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('cts_import_test_'));
  tearDown(() => dir.delete(recursive: true));

  test('PDF pages are rendered at 200 dpi', () async {
    final pdf = File(p.join(dir.path, 'book.pdf'))..writeAsBytesSync(_samplePdf());
    final pages = await importPages([pdf.path], cacheDir: Directory(p.join(dir.path, 'cache')), pdf: rasterizePdf);
    expect(pages.map((e) => p.basename(e.path)), ['001.png', '002.png']);
    expect(pages.first.name, 'book — 1');
    final image = ImageCodec.decode(File(pages.first.path).readAsBytesSync());
    expect([image.width, image.height], [400, 200]);
    expect(image.data.sublist(image.offset(50, 100), image.offset(50, 100) + 3), [255, 0, 0]);
    expect(image.data.sublist(image.offset(350, 100), image.offset(350, 100) + 3), [255, 255, 255]);
  });
}
