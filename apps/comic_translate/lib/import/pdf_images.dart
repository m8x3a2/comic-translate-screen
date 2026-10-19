/// The picture inside a PDF page that is just one picture (a scan, a comic
/// page), taken as it is instead of rendering the page (original
/// `_get_pdf_page_image_bytes`, pypdfium2). A JPEG stays the same JPEG
/// file; other pictures come out at their own resolution.
///
/// Unlike the original, which takes the first picture of any page, a page
/// is taken only when its one picture covers it and nothing visible is
/// drawn over it (text, lines): otherwise text drawn over the picture would
/// be lost. Invisible text (the OCR layer of scans) is allowed.
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium;

/// The picture must cover this much of the page.
const _minCoverage = 0.9;

/// Writes the pictures of the single-picture pages of [pdf] as
/// `<name(index)>.jpg` or `.png` into [outDir]; returns page index → file.
/// Runs PDFium on the calling thread, so nothing else may use PDFium
/// meanwhile (pdfrx renders the other pages afterwards).
Map<int, String> extractPageImages(String pdf, Directory outDir, String Function(int index) name) {
  final lib = pdfium.getPdfium();
  lib.FPDF_InitLibrary();
  final bytes = File(pdf).readAsBytesSync();
  final out = <int, String>{};
  using((arena) {
    final data = arena<Uint8>(bytes.length);
    data.asTypedList(bytes.length).setAll(0, bytes);
    final doc = lib.FPDF_LoadMemDocument64(data.cast(), bytes.length, nullptr);
    if (doc == nullptr) return;
    try {
      final count = lib.FPDF_GetPageCount(doc);
      for (var i = 0; i < count; i++) {
        final page = lib.FPDF_LoadPage(doc, i);
        if (page == nullptr) continue;
        try {
          final picture = _onlyPicture(lib, page, arena);
          if (picture == null) continue;
          final file = _write(lib, picture, outDir, name(i), arena);
          if (file != null) out[i] = file;
        } on Object {
          // This page is rendered instead.
        } finally {
          lib.FPDF_ClosePage(page);
        }
      }
    } finally {
      lib.FPDF_CloseDocument(doc);
    }
  });
  return out;
}

/// The page's one picture, when it covers the page and nothing visible is
/// drawn besides it.
pdfium.FPDF_PAGEOBJECT? _onlyPicture(pdfium.PDFium lib, pdfium.FPDF_PAGE page, Arena arena) {
  final width = lib.FPDF_GetPageWidthF(page), height = lib.FPDF_GetPageHeightF(page);
  if (width <= 0 || height <= 0) return null;
  pdfium.FPDF_PAGEOBJECT? picture;
  for (var k = 0; k < lib.FPDFPage_CountObjects(page); k++) {
    final object = lib.FPDFPage_GetObject(page, k);
    final type = lib.FPDFPageObj_GetType(object);
    if (type == pdfium.FPDF_PAGEOBJ_IMAGE) {
      if (picture != null) return null;
      picture = object;
    } else if (type == pdfium.FPDF_PAGEOBJ_TEXT &&
        lib.FPDFTextObj_GetTextRenderMode(object) == pdfium.FPDF_TEXT_RENDERMODE.FPDF_TEXTRENDERMODE_INVISIBLE) {
      continue;
    } else {
      return null;
    }
  }
  if (picture == null) return null;
  final box = arena<Float>(4);
  if (lib.FPDFPageObj_GetBounds(picture, box, box + 1, box + 2, box + 3) == 0) return null;
  final covered = ((box[2] - box[0]).clamp(0, width) * (box[3] - box[1]).clamp(0, height)) / (width * height);
  return covered >= _minCoverage ? picture : null;
}

String? _write(pdfium.PDFium lib, pdfium.FPDF_PAGEOBJECT picture, Directory outDir, String name, Arena arena) {
  // A JPEG (DCTDecode only) is the stored file itself.
  if (lib.FPDFImageObj_GetImageFilterCount(picture) == 1) {
    final buffer = arena<Char>(32);
    final n = lib.FPDFImageObj_GetImageFilter(picture, 0, buffer.cast(), 32);
    final filter = n > 1 ? buffer.cast<Utf8>().toDartString() : '';
    if (filter == 'DCTDecode') {
      final size = lib.FPDFImageObj_GetImageDataRaw(picture, nullptr, 0);
      if (size > 0) {
        final raw = arena<Uint8>(size);
        lib.FPDFImageObj_GetImageDataRaw(picture, raw.cast(), size);
        final file = File('${outDir.path}${Platform.pathSeparator}$name.jpg')
          ..writeAsBytesSync(Uint8List.fromList(raw.asTypedList(size)));
        return file.path;
      }
    }
  }
  final bitmap = lib.FPDFImageObj_GetBitmap(picture);
  if (bitmap == nullptr) return null;
  try {
    final w = lib.FPDFBitmap_GetWidth(bitmap), h = lib.FPDFBitmap_GetHeight(bitmap);
    final stride = lib.FPDFBitmap_GetStride(bitmap), format = lib.FPDFBitmap_GetFormat(bitmap);
    final channels = switch (format) {
      pdfium.FPDFBitmap_Gray => 1,
      pdfium.FPDFBitmap_BGR => 3,
      pdfium.FPDFBitmap_BGRx || pdfium.FPDFBitmap_BGRA || pdfium.FPDFBitmap_BGRA_Premul => 4,
      _ => 0,
    };
    if (w <= 0 || h <= 0 || channels == 0) return null;
    final src = lib.FPDFBitmap_GetBuffer(bitmap).cast<Uint8>().asTypedList(stride * h);
    final rgb = Uint8List(w * h * 3);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final s = y * stride + x * channels, d = (y * w + x) * 3;
        if (channels == 1) {
          rgb[d] = rgb[d + 1] = rgb[d + 2] = src[s];
        } else {
          rgb[d] = src[s + 2];
          rgb[d + 1] = src[s + 1];
          rgb[d + 2] = src[s];
        }
      }
    }
    final file = File('${outDir.path}${Platform.pathSeparator}$name.png')
      ..writeAsBytesSync(ImageCodec.encodePng(RgbImage(w, h, rgb)));
    return file.path;
  } finally {
    lib.FPDFBitmap_Destroy(bitmap);
  }
}
