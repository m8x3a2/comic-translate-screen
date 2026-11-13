import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

void main() {
  test('ico: directory, PNG kept as is, bitmaps bottom-up in BGRA with a mask', () {
    // 2x2: top row red (opaque) + clear, bottom row green + blue half-transparent
    final rgba = Uint8List.fromList([255, 0, 0, 255, 0, 0, 0, 0, 0, 255, 0, 255, 0, 0, 255, 128]);
    final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);
    final ico = encodeIco([IcoImage(2, rgba), IcoImage(256, Uint8List(256 * 256 * 4), png: png)]);
    final d = ByteData.sublistView(ico);
    expect(d.getUint16(2, Endian.little), 1); // icon
    expect(d.getUint16(4, Endian.little), 2);
    // entry 0: 2x2, 32 bpp
    expect(ico[6], 2);
    expect(d.getUint16(6 + 6, Endian.little), 32);
    final size0 = d.getUint32(6 + 8, Endian.little);
    final off0 = d.getUint32(6 + 12, Endian.little);
    expect(off0, 6 + 32);
    // entry 1: 256 is written as 0, data is the PNG
    expect(ico[22], 0);
    final off1 = d.getUint32(22 + 12, Endian.little);
    expect(off1, off0 + size0);
    expect(ico.sublist(off1), png);

    final dib = ByteData.sublistView(ico, off0, off0 + size0);
    expect(dib.getUint32(0, Endian.little), 40);
    expect(dib.getInt32(8, Endian.little), 4); // height doubled
    final px = ico.sublist(off0 + 40, off0 + 40 + 16);
    // first stored row = bottom row: green, then blue (BGRA)
    expect(px.sublist(0, 8), [0, 255, 0, 255, 255, 0, 0, 128]);
    // second stored row = top row: red, then clear
    expect(px.sublist(8, 16), [0, 0, 255, 255, 0, 0, 0, 0]);
    // mask rows are 4 bytes; only the clear pixel (top row, x=1) is set
    final mask = ico.sublist(off0 + 40 + 16, off0 + size0);
    expect(mask, [0, 0, 0, 0, 0x40, 0, 0, 0]);
  });

  test('ico: bad sizes are refused', () {
    expect(() => IcoImage(0, Uint8List(0)), throwsArgumentError);
    expect(() => IcoImage(2, Uint8List(3)), throwsArgumentError);
    expect(() => encodeIco([]), throwsArgumentError);
  });
}
