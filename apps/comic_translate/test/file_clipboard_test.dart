// The file list put on the clipboard by "Copy the pictures".

import 'dart:typed_data';

import 'package:comic_translate/services/file_clipboard.dart';
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
}
