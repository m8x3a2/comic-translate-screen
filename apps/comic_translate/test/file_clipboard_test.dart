// The file list put on the clipboard by "Copy the pictures".

import 'dart:typed_data';

import 'package:comic_translate/services/file_clipboard.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// The names in a DROPFILES block, as Windows reads them.
List<String> _names(Uint8List bytes) {
  final data = bytes.buffer.asByteData();
  expect(data.getUint32(0, Endian.little), 20, reason: 'the names start after the header');
  expect(data.getUint32(16, Endian.little), 1, reason: 'wide names');
  final units = [for (var i = 20; i < bytes.length; i += 2) data.getUint16(i, Endian.little)];
  final names = <String>[];
  var start = 0;
  for (var i = 0; i < units.length; i++) {
    if (units[i] != 0) continue;
    if (i == start) break; // the second zero: end of the list
    names.add(String.fromCharCodes(units.sublist(start, i)));
    start = i + 1;
  }
  return names;
}

void main() {
  test('every file is its own name, the list ends with two zeros', () {
    const paths = [r'C:\ex\sheet_01.png', r'C:\ex\sheet_02.png', r'C:\Обмен\страница 3.png'];
    final bytes = dropFiles(paths);
    expect(_names(bytes), paths);
    expect(bytes.sublist(bytes.length - 4), [0, 0, 0, 0]);
  });

  test('copied files are read back', () {
    const paths = [r'C:\pages\01.png', r'D:\Комикс\страница 2.jpg'];
    expect(filesOfDrop(dropFiles(paths)), paths);
  });

  /// A 3×2 Windows bitmap: red, green, blue on the top row, white below.
  Uint8List dib(int bits, {bool topDown = false, int compression = 0}) {
    const top = [(255, 0, 0), (0, 255, 0), (0, 0, 255)];
    const bottom = [(255, 255, 255), (255, 255, 255), (255, 255, 255)];
    final step = bits ~/ 8;
    final stride = (3 * bits + 31) ~/ 32 * 4;
    final masks = compression == 3 ? 12 : 0;
    final bytes = Uint8List(40 + masks + stride * 2);
    final data = bytes.buffer.asByteData()
      ..setUint32(0, 40, Endian.little)
      ..setInt32(4, 3, Endian.little)
      ..setInt32(8, topDown ? -2 : 2, Endian.little)
      ..setUint16(12, 1, Endian.little)
      ..setUint16(14, bits, Endian.little)
      ..setUint32(16, compression, Endian.little);
    if (compression == 3) {
      data
        ..setUint32(40, 0xff0000, Endian.little)
        ..setUint32(44, 0xff00, Endian.little)
        ..setUint32(48, 0xff, Endian.little);
    }
    for (final (row, colors) in [top, bottom].indexed) {
      final start = 40 + masks + (topDown ? row : 1 - row) * stride;
      for (final (x, (r, g, b)) in colors.indexed) {
        // Blue, green, red; the fourth byte (alpha) stays zero.
        bytes.setAll(start + x * step, [b, g, r]);
      }
    }
    return bytes;
  }

  for (final (bits, topDown, compression) in [(24, false, 0), (32, false, 0), (32, true, 3)]) {
    test('a screenshot ($bits bits${topDown ? ', top row first' : ''}) becomes an opaque PNG', () {
      final png = pictureToPng(ClipboardPicture(dib(bits, topDown: topDown, compression: compression), png: false));
      final image = ImageCodec.decode(png);
      expect([image.width, image.height], [3, 2]);
      expect(image.data, [255, 0, 0, 0, 255, 0, 0, 0, 255, for (var i = 0; i < 9; i++) 255]);
    });
  }

  test('an 8-bit bitmap goes through OpenCV', () {
    // Two colours in the table: black, then yellow; one row of 2 pixels.
    final bytes = Uint8List(40 + 8 + 4);
    bytes.buffer.asByteData()
      ..setUint32(0, 40, Endian.little)
      ..setInt32(4, 2, Endian.little)
      ..setInt32(8, 1, Endian.little)
      ..setUint16(12, 1, Endian.little)
      ..setUint16(14, 8, Endian.little)
      ..setUint32(32, 2, Endian.little);
    bytes.setAll(40, [0, 0, 0, 0, 0, 255, 255, 0]);
    bytes.setAll(48, [1, 0]);
    final image = ImageCodec.decode(pictureToPng(ClipboardPicture(bytes, png: false)));
    expect(image.data, [255, 255, 0, 0, 0, 0]);
  });
}
