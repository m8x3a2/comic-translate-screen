import 'dart:typed_data';

/// One picture of an .ico file: a square [size] px with straight (not
/// premultiplied) RGBA pixels, rows top to bottom. [png] is used instead of
/// the pixels when given (Windows wants the 256 px picture as PNG).
class IcoImage {
  IcoImage(this.size, this.rgba, {this.png}) {
    if (size < 1 || size > 256) throw ArgumentError.value(size, 'size', 'must be 1..256');
    if (rgba.length != size * size * 4) throw ArgumentError('rgba must have size*size*4 bytes');
  }

  final int size;
  final Uint8List rgba;
  final Uint8List? png;
}

/// The sizes Windows asks an icon for (title bar 16-24, taskbar 24-48,
/// Explorer up to 256), as in the program's own app_icon.ico.
const icoSizes = [16, 20, 24, 32, 40, 48, 64, 96, 128, 256];

/// Builds an .ico file: PNG pictures where given, the rest as classic 32-bit
/// bitmaps with an AND mask (every Windows reader takes them).
Uint8List encodeIco(List<IcoImage> images) {
  if (images.isEmpty) throw ArgumentError('no images');
  final blobs = [for (final i in images) i.png ?? _dib(i)];
  final out = BytesBuilder(copy: false);
  final head = ByteData(6 + 16 * images.length)
    ..setUint16(0, 0, Endian.little)
    ..setUint16(2, 1, Endian.little)
    ..setUint16(4, images.length, Endian.little);
  var offset = head.lengthInBytes;
  for (var n = 0; n < images.length; n++) {
    final e = 6 + 16 * n;
    final side = images[n].size >= 256 ? 0 : images[n].size;
    head
      ..setUint8(e, side)
      ..setUint8(e + 1, side)
      ..setUint8(e + 2, 0)
      ..setUint8(e + 3, 0)
      ..setUint16(e + 4, 1, Endian.little)
      ..setUint16(e + 6, 32, Endian.little)
      ..setUint32(e + 8, blobs[n].length, Endian.little)
      ..setUint32(e + 12, offset, Endian.little);
    offset += blobs[n].length;
  }
  out.add(head.buffer.asUint8List());
  for (final b in blobs) {
    out.add(b);
  }
  return out.takeBytes();
}

/// BITMAPINFOHEADER + BGRA rows bottom to top + 1-bit mask (1 = transparent).
Uint8List _dib(IcoImage i) {
  final s = i.size;
  final maskRow = ((s + 31) ~/ 32) * 4;
  final pixels = s * s * 4;
  final out = Uint8List(40 + pixels + maskRow * s);
  ByteData.sublistView(out)
    ..setUint32(0, 40, Endian.little)
    ..setInt32(4, s, Endian.little)
    ..setInt32(8, s * 2, Endian.little) // colour + mask
    ..setUint16(12, 1, Endian.little)
    ..setUint16(14, 32, Endian.little)
    ..setUint32(20, pixels + maskRow * s, Endian.little);
  for (var y = 0; y < s; y++) {
    final src = (s - 1 - y) * s * 4;
    final dst = 40 + y * s * 4;
    for (var x = 0; x < s; x++) {
      final a = src + x * 4;
      final b = dst + x * 4;
      out[b] = i.rgba[a + 2];
      out[b + 1] = i.rgba[a + 1];
      out[b + 2] = i.rgba[a];
      out[b + 3] = i.rgba[a + 3];
      if (i.rgba[a + 3] == 0) out[40 + pixels + y * maskRow + (x >> 3)] |= 0x80 >> (x & 7);
    }
  }
  return out;
}
