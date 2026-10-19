// PDF pages that are one picture come out as that picture; others are
// rendered.

import 'dart:convert';
import 'dart:io';

import 'package:comic_translate/import/pdf_pages.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// A PDF with one page that only draws a square (no picture).
List<int> vectorPdf() {
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 100 100] /Contents 4 0 R >>',
    '<< /Length 26 >>\nstream\n0 0 1 rg 10 10 50 50 re f\nendstream',
  ];
  final out = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (final (i, o) in objects.indexed) {
    offsets.add(latin1.encode(out.toString()).length);
    out.write('${i + 1} 0 obj\n$o\nendobj\n');
  }
  final xref = latin1.encode(out.toString()).length;
  out.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final o in offsets) {
    out.write('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  out.write('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
  return latin1.encode(out.toString());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a scanned page gives its own JPEG or pixels; a drawn page is rendered at 200 dpi', () async {
    final dir = Directory.systemTemp.createTempSync('cts_pdf_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final photo = RgbImage.filled(40, 30, 200, 120, 40);
    final jpeg = ImageCodec.encodeJpeg(photo, quality: 90);
    final sharp = RgbImage.filled(50, 20, 10, 220, 30)..data.setAll(0, [255, 0, 0]);
    final scans = p.join(dir.path, 'scans.pdf');
    ImagePdfWriter(scans)
      ..addJpeg(jpeg, 40, 30)
      ..addRgb(sharp)
      ..close();

    final out = Directory(p.join(dir.path, 'out'))..createSync();
    final pages = await rasterizePdf(scans, out, CancelToken.none);
    expect(pages.map((x) => p.basename(x.path)), ['001.jpg', '002.png']);
    expect(File(pages.first.path).readAsBytesSync(), jpeg, reason: 'the stored JPEG, unchanged');
    final second = await ImageCodec.readFile(pages.last.path);
    expect((second.width, second.height), (50, 20), reason: 'its own resolution, not 200 dpi');
    expect(second.data.sublist(0, 6), [255, 0, 0, 10, 220, 30]);
    expect(pages.first.name, 'scans — 1');

    final drawn = p.join(dir.path, 'drawn.pdf');
    File(drawn).writeAsBytesSync(vectorPdf());
    final rendered = await rasterizePdf(drawn, Directory(p.join(dir.path, 'out2'))..createSync(), CancelToken.none);
    final image = await ImageCodec.readFile(rendered.single.path);
    expect((image.width, image.height), (278, 278), reason: '100 pt at 200 dpi');
  });
}
