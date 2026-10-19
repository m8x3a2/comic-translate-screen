/// PDF pages as page images, rendered with PDFium (pdfrx_engine). The
/// original takes the embedded image of single-image pages and renders the
/// others; here every page is rendered, at 200 dpi.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx_engine/pdfrx_engine.dart';

const _dpi = 200.0;

/// Longest side of a rendered page, in pixels.
const _maxSide = 4000.0;

var _initialized = false;

/// [PdfRasterizer] for [importPages]: renders every page of [pdf] into
/// [outDir] as `001.png`, `002.png` …
Future<List<ImportedPage>> rasterizePdf(String pdf, Directory outDir, CancelToken cancel) async {
  if (!_initialized) {
    await pdfrxInitialize(tmpPath: p.join(Directory.systemTemp.path, 'comic_translate_pdfrx'));
    _initialized = true;
  }
  final doc = await PdfDocument.openFile(pdf);
  try {
    final pages = <ImportedPage>[];
    final digits = math.max(3, doc.pages.length.toString().length);
    for (final (i, page) in doc.pages.indexed) {
      cancel.throwIfCancelled();
      final scale = math.min(_dpi / 72, _maxSide / math.max(page.width, page.height));
      final w = math.max(1, (page.width * scale).round()), h = math.max(1, (page.height * scale).round());
      final image = await page.render(fullWidth: w.toDouble(), fullHeight: h.toDouble(), backgroundColor: 0xFFFFFFFF);
      if (image == null) continue;
      try {
        final target = p.join(outDir.path, '${(i + 1).toString().padLeft(digits, '0')}.png');
        await File(target).writeAsBytes(ImageCodec.encodePng(_bgraToRgb(image)));
        pages.add(ImportedPage(path: target, name: '${p.basenameWithoutExtension(pdf)} — ${i + 1}', source: pdf));
      } finally {
        image.dispose();
      }
    }
    return pages;
  } finally {
    await doc.dispose();
  }
}

RgbImage _bgraToRgb(PdfImage image) {
  final src = image.pixels;
  final out = Uint8List(image.width * image.height * 3);
  for (var s = 0, d = 0; d < out.length; s += 4, d += 3) {
    out[d] = src[s + 2];
    out[d + 1] = src[s + 1];
    out[d + 2] = src[s];
  }
  return RgbImage(image.width, image.height, out);
}
