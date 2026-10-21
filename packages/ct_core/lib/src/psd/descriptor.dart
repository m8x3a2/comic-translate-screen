/// Photoshop action descriptors (the key/value structures inside text
/// layers and other layer data).
library;

import 'dart:typed_data';

import 'psd_bytes.dart';

/// A descriptor: class id and items in order. Values: [int] (`long`),
/// [double] (`doub`), [bool], [String] (`TEXT`), [Uint8List] (`tdta`),
/// [DescEnum], [DescUnit], [Descriptor] (`Objc`), [List] (`VlLs`), and
/// [DescRaw] for kinds only read.
class Descriptor {
  Descriptor(this.classId, [Map<String, Object>? items, this.name = '']) : items = items ?? {};

  final String classId;
  final String name;
  final Map<String, Object> items;

  Object? operator [](String key) => items[key];
}

class DescEnum {
  const DescEnum(this.type, this.value);

  final String type;
  final String value;

  @override
  bool operator ==(Object other) => other is DescEnum && other.type == type && other.value == value;

  @override
  int get hashCode => Object.hash(type, value);

  @override
  String toString() => '$type.$value';
}

/// A number with units: `#Pxl` pixels, `#Pnt` points, `#Ang` degrees …
class DescUnit {
  const DescUnit(this.units, this.value);

  final String units;
  final double value;
}

/// A value of a kind that is skipped (references, aliases, large ints).
class DescRaw {
  const DescRaw(this.type);

  final String type;
}

/// The descriptor version (16) and [d].
void writeVersionedDescriptor(PsdWriter w, Descriptor d) {
  w.u32(16);
  writeDescriptor(w, d);
}

void writeDescriptor(PsdWriter w, Descriptor d) {
  w.unicodeZ(d.name);
  _writeId(w, d.classId);
  w.u32(d.items.length);
  for (final MapEntry(:key, :value) in d.items.entries) {
    _writeId(w, key);
    _writeValue(w, value);
  }
}

/// Four-character ids are written as such, longer names with their length.
void _writeId(PsdWriter w, String id) {
  if (id.length == 4 && !const {'warp', 'time', 'hold', 'list'}.contains(id)) {
    w.u32(0);
    w.sig(id);
  } else {
    w.u32(id.length);
    w.bytes(id.codeUnits);
  }
}

void _writeValue(PsdWriter w, Object v) {
  switch (v) {
    case Descriptor():
      w.sig('Objc');
      writeDescriptor(w, v);
    case Uint8List():
      w.sig('tdta');
      w.u32(v.length);
      w.bytes(v);
    case List<Object>():
      w.sig('VlLs');
      w.u32(v.length);
      for (final x in v) {
        _writeValue(w, x);
      }
    case bool():
      w.sig('bool');
      w.u8(v ? 1 : 0);
    case int():
      w.sig('long');
      w.i32(v);
    case double():
      w.sig('doub');
      w.f64(v);
    case String():
      w.sig('TEXT');
      w.unicodeZ(v);
    case DescEnum():
      w.sig('enum');
      _writeId(w, v.type);
      _writeId(w, v.value);
    case DescUnit():
      w.sig('UntF');
      w.sig(v.units);
      w.f64(v.value);
    default:
      throw ArgumentError('cannot write ${v.runtimeType} in a descriptor');
  }
}

/// Reads a descriptor after its version.
Descriptor readVersionedDescriptor(PsdReader r) {
  final version = r.u32();
  if (version != 16) throw PsdFormatException('descriptor version $version');
  return readDescriptor(r);
}

Descriptor readDescriptor(PsdReader r) {
  final name = r.unicodeZ();
  final classId = _readId(r);
  final count = r.u32();
  final items = <String, Object>{};
  for (var i = 0; i < count; i++) {
    final key = _readId(r);
    items[key] = _readValue(r, r.sig());
  }
  return Descriptor(classId, items, name);
}

String _readId(PsdReader r) {
  final n = r.u32();
  return String.fromCharCodes(r.bytes(n == 0 ? 4 : n));
}

Object _readValue(PsdReader r, String type) {
  switch (type) {
    case 'Objc' || 'GlbO':
      return readDescriptor(r);
    case 'VlLs':
      final n = r.u32();
      return <Object>[for (var i = 0; i < n; i++) _readValue(r, r.sig())];
    case 'bool':
      return r.u8() != 0;
    case 'long':
      return r.i32();
    case 'comp':
      r.skip(8);
      return const DescRaw('comp');
    case 'doub':
      return r.f64();
    case 'UntF':
      return DescUnit(r.sig(), r.f64());
    case 'UnFl':
      return DescUnit(r.sig(), r.f32());
    case 'TEXT':
      return r.unicodeZ();
    case 'tdta' || 'alis' || 'Pth ':
      final n = r.u32();
      return Uint8List.fromList(r.bytes(n));
    case 'enum':
      return DescEnum(_readId(r), _readId(r));
    case 'type' || 'GlbC':
      r.unicodeZ();
      return DescEnum('class', _readId(r));
    case 'obj ':
      final n = r.u32();
      for (var i = 0; i < n; i++) {
        switch (r.sig()) {
          case 'prop':
            r.unicodeZ();
            _readId(r);
            _readId(r);
          case 'Clss':
            r.unicodeZ();
            _readId(r);
          case 'Enmr':
            r.unicodeZ();
            _readId(r);
            _readId(r);
            _readId(r);
          case 'rele':
            r.unicodeZ();
            _readId(r);
            r.u32();
          case 'Idnt' || 'indx':
            r.u32();
          case 'name':
            r.unicodeZ();
            _readId(r);
            r.unicodeZ();
          case final t:
            throw PsdFormatException('reference item $t');
        }
      }
      return const DescRaw('obj ');
    case 'ObAr':
      // Arrays of unit values (shape meshes): version, then a descriptor-like
      // body with 'UnFl' lists.
      r.u32();
      r.unicodeZ();
      _readId(r);
      final count = r.u32();
      for (var i = 0; i < count; i++) {
        _readId(r);
        final t = r.sig();
        if (t == 'UnFl') {
          r.sig();
          final n = r.u32();
          r.skip(n * 8);
        } else {
          _readValue(r, t);
        }
      }
      return const DescRaw('ObAr');
    default:
      throw PsdFormatException('descriptor value type $type');
  }
}
