/// A PDF made of page pictures, one picture per page at 1 pixel = 1 point
/// (as the original's `make_pdf` with pypdfium2), written straight to the
/// file so long chapters do not have to fit in memory.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../image/raster.dart';

class ImagePdfWriter {
  ImagePdfWriter(String path) : _out = File(path).openSync(mode: FileMode.write) {
    _write('%PDF-1.4\n%âãÏÓ\n');
    _object(1, '<< /Type /Catalog /Pages 2 0 R >>');
  }

  final RandomAccessFile _out;
  final _offsets = <int, int>{};
  final _pages = <int>[];
  var _next = 3;
  var _position = 0;

  int get pageCount => _pages.length;

  /// A page showing a JPEG picture as it is.
  void addJpeg(Uint8List jpeg, int width, int height) => _page(width, height, '/Filter /DCTDecode', jpeg);

  /// A page showing [image] without loss (deflate).
  void addRgb(RgbImage image) => _page(image.width, image.height, '/Filter /FlateDecode', zlib.encode(image.data));

  /// Writes the page list and the index; the file is complete after this.
  void close() {
    _object(2, '<< /Type /Pages /Kids [${_pages.map((p) => '$p 0 R').join(' ')}] /Count ${_pages.length} >>');
    final xref = _position;
    final index = StringBuffer('xref\n0 $_next\n0000000000 65535 f \n');
    for (var n = 1; n < _next; n++) {
      index.write('${_offsets[n]!.toString().padLeft(10, '0')} 00000 n \n');
    }
    index.write('trailer\n<< /Size $_next /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n');
    _write(index.toString());
    _out.closeSync();
  }

  void _page(int width, int height, String filter, List<int> data) {
    final page = _next, content = _next + 1, picture = _next + 2;
    _next += 3;
    _object(
      picture,
      '<< /Type /XObject /Subtype /Image /Width $width /Height $height /ColorSpace /DeviceRGB '
      '/BitsPerComponent 8 $filter /Length ${data.length} >>',
      data,
    );
    final draw = latin1.encode('q $width 0 0 $height 0 0 cm /Im0 Do Q');
    _object(content, '<< /Length ${draw.length} >>', draw);
    _object(
      page,
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $width $height] '
      '/Resources << /XObject << /Im0 $picture 0 R >> >> /Contents $content 0 R >>',
    );
    _pages.add(page);
  }

  void _object(int number, String dictionary, [List<int>? stream]) {
    _offsets[number] = _position;
    _write('$number 0 obj\n$dictionary\n');
    if (stream != null) {
      _write('stream\n');
      _bytes(stream);
      _write('\nendstream\n');
    }
    _write('endobj\n');
  }

  void _write(String s) => _bytes(latin1.encode(s));

  void _bytes(List<int> bytes) {
    _out.writeFromSync(bytes);
    _position += bytes.length;
  }
}
