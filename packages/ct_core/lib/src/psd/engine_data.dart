/// EngineData: the text engine's description of a text layer (text, fonts,
/// style and paragraph runs), a PostScript-like syntax inside the layer's
/// descriptor. Written as Photoshop and ag-psd (MIT) write it.
library;

import 'dart:convert';
import 'dart:typed_data';

/// A `/Name` value.
class EdName {
  const EdName(this.name);

  final String name;

  @override
  bool operator ==(Object other) => other is EdName && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// Serialises [root] (a map of maps, lists, numbers, strings, bools,
/// [EdName]). [double]s are written with a decimal point, [int]s without.
Uint8List serializeEngineData(Map<String, Object?> root) {
  final out = BytesBuilder(copy: false);
  var indent = 0;

  void ascii(String s) => out.add(latin1.encode(s));
  void tabs() => ascii('\t' * indent);

  late void Function(Object? v, {required bool inProperty}) value;

  void dict(Map<String, Object?> m) {
    tabs();
    ascii('<<\n');
    indent++;
    for (final MapEntry(:key, value: v) in m.entries) {
      tabs();
      ascii('/$key');
      value(v, inProperty: true);
      ascii('\n');
    }
    indent--;
    tabs();
    ascii('>>');
  }

  value = (Object? v, {required bool inProperty}) {
    void prefix() => inProperty ? ascii(' ') : tabs();
    switch (v) {
      case null:
        prefix();
        ascii('null');
      case bool():
        prefix();
        ascii(v ? 'true' : 'false');
      case int():
        prefix();
        ascii('$v');
      case double():
        prefix();
        ascii(_float(v));
      case EdName():
        prefix();
        ascii('/${v.name}');
      case String():
        prefix();
        ascii('(');
        out.add(const [0xFE, 0xFF]);
        for (final c in v.codeUnits) {
          for (final b in [c >> 8, c & 0xFF]) {
            if (b == 0x28 || b == 0x29 || b == 0x5C) out.addByte(0x5C);
            out.addByte(b);
          }
        }
        ascii(')');
      case List<Object?>() when v.every((x) => x is num):
        prefix();
        ascii('[');
        for (final x in v) {
          ascii(' ${x is int ? '$x' : _float((x as num).toDouble())}');
        }
        ascii(' ]');
      case List<Object?>():
        prefix();
        ascii('[\n');
        indent++;
        for (final x in v) {
          value(x, inProperty: false);
          ascii('\n');
        }
        indent--;
        tabs();
        ascii(']');
      case Map<String, Object?>():
        if (inProperty) ascii('\n');
        dict(v);
      default:
        throw ArgumentError('cannot write ${v.runtimeType} in EngineData');
    }
  };

  ascii('\n\n');
  dict(root);
  return out.takeBytes();
}

/// `12.0`, `.5`, `-.25` (five decimals at most).
String _float(double v) {
  var s = v.toStringAsFixed(5);
  s = s.replaceFirstMapped(RegExp(r'(\d)0+$'), (m) => m[1]!);
  s = s.replaceFirstMapped(RegExp(r'^0+\.(\d)'), (m) => '.${m[1]}');
  s = s.replaceFirstMapped(RegExp(r'^-0+\.(\d)'), (m) => '-.${m[1]}');
  return s == '-.0' ? '.0' : s;
}

/// Parses EngineData back into maps and lists (numbers with a point become
/// [double]s).
Map<String, Object?> parseEngineData(Uint8List data) {
  var i = 0;
  var end = data.length;
  while (end > 0 && data[end - 1] == 0) {
    end--;
  }
  bool space(int c) => c == 32 || c == 10 || c == 13 || c == 9;
  bool numeric(int c) => (c >= 48 && c <= 57) || c == 46 || c == 45;

  final stack = <Object>[]; // maps, lists and pending keys
  Map<String, Object?>? root;

  void push(Object? v) {
    if (stack.isEmpty) throw const FormatException('EngineData: value outside a dictionary');
    final top = stack.last;
    if (top is String) {
      stack.removeLast();
      (stack.last as Map<String, Object?>)[top] = v;
    } else if (top is List<Object?>) {
      top.add(v);
    } else {
      throw const FormatException('EngineData: value without a key');
    }
  }

  void open(Object container) {
    if (stack.isEmpty) {
      root = container as Map<String, Object?>;
    } else {
      push(container);
    }
    stack.add(container);
  }

  int textByte() {
    var b = data[i++];
    if (b == 0x5C && i < end) b = data[i++];
    return b;
  }

  String text() {
    final units = <int>[];
    if (i + 1 < end && data[i] == 0xFE && data[i + 1] == 0xFF) {
      i += 2;
      while (i < end && data[i] != 0x29) {
        final hi = textByte();
        if (i >= end) break;
        final lo = textByte();
        units.add(hi << 8 | lo);
      }
    } else {
      while (i < end && data[i] != 0x29) {
        units.add(textByte());
      }
    }
    i++;
    return String.fromCharCodes(units);
  }

  bool word(String w) {
    if (i + w.length > end) return false;
    for (var k = 0; k < w.length; k++) {
      if (data[i + k] != w.codeUnitAt(k)) return false;
    }
    return true;
  }

  while (i < end) {
    final c = data[i];
    if (space(c)) {
      i++;
    } else if (c == 0x3C && i + 1 < end && data[i + 1] == 0x3C) {
      i += 2;
      open(<String, Object?>{});
    } else if (c == 0x3E && i + 1 < end && data[i + 1] == 0x3E) {
      i += 2;
      if (stack.isNotEmpty) stack.removeLast();
    } else if (c == 0x2F) {
      final start = ++i;
      while (i < end && !space(data[i]) && !const {0x3C, 0x3E, 0x5B, 0x5D, 0x28, 0x2F}.contains(data[i])) {
        i++;
      }
      final name = latin1.decode(data.sublist(start, i));
      if (stack.isEmpty) open(<String, Object?>{});
      final top = stack.last;
      if (top is Map<String, Object?>) {
        stack.add(name);
      } else {
        push(EdName(name));
      }
    } else if (c == 0x28) {
      i++;
      push(text());
    } else if (c == 0x5B) {
      i++;
      open(<Object?>[]);
    } else if (c == 0x5D) {
      i++;
      if (stack.isNotEmpty) stack.removeLast();
    } else if (word('true')) {
      i += 4;
      push(true);
    } else if (word('false')) {
      i += 5;
      push(false);
    } else if (word('null')) {
      i += 4;
      push(null);
    } else if (numeric(c)) {
      final start = i;
      while (i < end && numeric(data[i])) {
        i++;
      }
      final s = latin1.decode(data.sublist(start, i));
      push(s.contains('.') ? double.tryParse(s) ?? 0.0 : int.tryParse(s) ?? 0);
    } else {
      i++;
    }
  }
  return root ?? {};
}
