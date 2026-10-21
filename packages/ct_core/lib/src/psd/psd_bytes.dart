/// Big-endian reading and writing for PSD files.
library;

import 'dart:convert';
import 'dart:typed_data';

/// A growing big-endian byte buffer.
class PsdWriter {
  PsdWriter([int capacity = 1 << 16]) : _buf = Uint8List(capacity);

  Uint8List _buf;
  var _view = ByteData(0);
  int length = 0;

  void _ensure(int extra) {
    if (length + extra <= _buf.length) return;
    var size = _buf.length * 2;
    while (size < length + extra) {
      size *= 2;
    }
    _buf = Uint8List(size)..setRange(0, length, _buf);
    _view = ByteData(0);
  }

  ByteData get _data => _view.lengthInBytes == _buf.length ? _view : (_view = ByteData.sublistView(_buf));

  void u8(int v) {
    _ensure(1);
    _buf[length++] = v;
  }

  void u16(int v) {
    _ensure(2);
    _data.setUint16(length, v);
    length += 2;
  }

  void i16(int v) {
    _ensure(2);
    _data.setInt16(length, v);
    length += 2;
  }

  void u32(int v) {
    _ensure(4);
    _data.setUint32(length, v);
    length += 4;
  }

  void i32(int v) {
    _ensure(4);
    _data.setInt32(length, v);
    length += 4;
  }

  void u64(int v) {
    u32(v >> 32);
    u32(v & 0xFFFFFFFF);
  }

  void f32(double v) {
    _ensure(4);
    _data.setFloat32(length, v);
    length += 4;
  }

  void f64(double v) {
    _ensure(8);
    _data.setFloat64(length, v);
    length += 8;
  }

  void bytes(List<int> b) {
    _ensure(b.length);
    _buf.setRange(length, length + b.length, b);
    length += b.length;
  }

  void zeros(int n) {
    _ensure(n);
    _buf.fillRange(length, length + n, 0);
    length += n;
  }

  /// Four ASCII characters ('8BIM').
  void sig(String s) {
    assert(s.length == 4);
    bytes(latin1.encode(s));
  }

  /// Length byte + ASCII, padded so that the whole is a multiple of [pad].
  void pascal(String s, int pad) {
    final b = [for (final c in s.codeUnits.take(255)) c < 128 ? c : 0x3F];
    u8(b.length);
    bytes(b);
    var n = b.length + 1;
    while (n % pad != 0) {
      u8(0);
      n++;
    }
  }

  /// UTF-16 code unit count + the units + a 0 (descriptor strings).
  void unicodeZ(String s) {
    u32(s.length + 1);
    for (final c in s.codeUnits) {
      u16(c);
    }
    u16(0);
  }

  /// UTF-16 code unit count + the units ('luni', version info).
  void unicode(String s) {
    u32(s.length);
    for (final c in s.codeUnits) {
      u16(c);
    }
  }

  /// A length-prefixed block: [body] writes it, the length goes before it
  /// ([long]: 8 bytes, PSB). The block is padded to a multiple of [pad];
  /// the padding counts in the length when [padInLength].
  void section(void Function() body, {int pad = 1, bool long = false, bool padInLength = true}) {
    final at = length;
    long ? u64(0) : u32(0);
    final start = length;
    body();
    var n = length - start;
    final raw = n;
    while (n % pad != 0) {
      u8(0);
      n++;
    }
    final value = padInLength ? n : raw;
    if (long) {
      _data
        ..setUint32(at, value >> 32)
        ..setUint32(at + 4, value & 0xFFFFFFFF);
    } else {
      _data.setUint32(at, value);
    }
  }

  Uint8List takeBytes() => Uint8List.sublistView(_buf, 0, length);
}

class PsdFormatException implements Exception {
  const PsdFormatException(this.message);

  final String message;

  @override
  String toString() => 'PSD: $message';
}

/// Big-endian reader over the whole file.
class PsdReader {
  PsdReader(this.data) : _view = ByteData.sublistView(data);

  final Uint8List data;
  final ByteData _view;
  int pos = 0;

  void _need(int n) {
    if (pos + n > data.length) throw const PsdFormatException('unexpected end of file');
  }

  int u8() {
    _need(1);
    return data[pos++];
  }

  int u16() {
    _need(2);
    final v = _view.getUint16(pos);
    pos += 2;
    return v;
  }

  int i16() {
    _need(2);
    final v = _view.getInt16(pos);
    pos += 2;
    return v;
  }

  int u32() {
    _need(4);
    final v = _view.getUint32(pos);
    pos += 4;
    return v;
  }

  int i32() {
    _need(4);
    final v = _view.getInt32(pos);
    pos += 4;
    return v;
  }

  int u64() => u32() << 32 | u32();

  double f32() {
    _need(4);
    final v = _view.getFloat32(pos);
    pos += 4;
    return v;
  }

  double f64() {
    _need(8);
    final v = _view.getFloat64(pos);
    pos += 8;
    return v;
  }

  Uint8List bytes(int n) {
    _need(n);
    final b = Uint8List.sublistView(data, pos, pos + n);
    pos += n;
    return b;
  }

  void skip(int n) {
    _need(n);
    pos += n;
  }

  String sig() => latin1.decode(bytes(4));

  String pascal(int pad) {
    final n = u8();
    final s = latin1.decode(bytes(n));
    var total = n + 1;
    while (total % pad != 0) {
      skip(1);
      total++;
    }
    return s;
  }

  /// See [PsdWriter.unicodeZ]: trailing zeros are dropped.
  String unicodeZ() {
    final n = u32();
    final units = [for (var i = 0; i < n; i++) u16()];
    while (units.isNotEmpty && units.last == 0) {
      units.removeLast();
    }
    return String.fromCharCodes(units);
  }

  String unicode() {
    final n = u32();
    return String.fromCharCodes([for (var i = 0; i < n; i++) u16()]);
  }
}
