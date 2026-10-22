/// Files on the clipboard, as Explorer's "Copy" puts them there: Ctrl+V in a
/// chat in the browser attaches all of them at once.
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

const _cfHdrop = 15;
const _gmemMoveable = 0x0002;
const _dropEffectCopy = 1;

final _user32 = DynamicLibrary.open('user32.dll');
final _kernel32 = DynamicLibrary.open('kernel32.dll');

final _openClipboard = _user32.lookupFunction<Int32 Function(IntPtr), int Function(int)>('OpenClipboard');
final _emptyClipboard = _user32.lookupFunction<Int32 Function(), int Function()>('EmptyClipboard');
final _closeClipboard = _user32.lookupFunction<Int32 Function(), int Function()>('CloseClipboard');
final _setClipboardData = _user32.lookupFunction<IntPtr Function(Uint32, IntPtr), int Function(int, int)>(
  'SetClipboardData',
);
final _registerFormat = _user32.lookupFunction<Uint32 Function(Pointer<Utf16>), int Function(Pointer<Utf16>)>(
  'RegisterClipboardFormatW',
);
final _globalAlloc = _kernel32.lookupFunction<IntPtr Function(Uint32, IntPtr), int Function(int, int)>('GlobalAlloc');
final _globalLock = _kernel32.lookupFunction<Pointer<Uint8> Function(IntPtr), Pointer<Uint8> Function(int)>(
  'GlobalLock',
);
final _globalUnlock = _kernel32.lookupFunction<Int32 Function(IntPtr), int Function(int)>('GlobalUnlock');
final _globalFree = _kernel32.lookupFunction<IntPtr Function(IntPtr), int Function(int)>('GlobalFree');

/// Puts [paths] on the clipboard as files. False when it could not (another
/// program holds the clipboard, or not on Windows).
bool copyFilesToClipboard(List<String> paths) {
  if (!Platform.isWindows || paths.isEmpty) return false;
  final bytes = dropFiles([for (final path in paths) File(path).absolute.path]);
  final effect = Uint8List(4)..buffer.asByteData().setUint32(0, _dropEffectCopy, Endian.little);

  for (var attempt = 0; attempt < 5; attempt++) {
    if (_openClipboard(0) != 0) break;
    if (attempt == 4) return false;
    sleep(const Duration(milliseconds: 30));
  }
  try {
    _emptyClipboard();
    if (!_put(_cfHdrop, bytes)) return false;
    final name = 'Preferred DropEffect'.toNativeUtf16();
    try {
      _put(_registerFormat(name), effect);
    } finally {
      calloc.free(name);
    }
    return true;
  } finally {
    _closeClipboard();
  }
}

/// The clipboard's file list (DROPFILES): offset of the list, a point, two
/// flags (wide names); then the names, each ending with a zero, and one more
/// zero at the end.
Uint8List dropFiles(List<String> paths) {
  final names = [
    for (final path in paths) ...[...path.codeUnits, 0],
    0,
  ];
  final bytes = Uint8List(20 + names.length * 2);
  bytes.buffer.asByteData()
    ..setUint32(0, 20, Endian.little)
    ..setUint32(16, 1, Endian.little);
  for (final (i, c) in names.indexed) {
    bytes[20 + i * 2] = c & 0xff;
    bytes[21 + i * 2] = c >> 8;
  }
  return bytes;
}

bool _put(int format, Uint8List data) {
  if (format == 0) return false;
  final handle = _globalAlloc(_gmemMoveable, data.length);
  if (handle == 0) return false;
  final ptr = _globalLock(handle);
  if (ptr == nullptr) {
    _globalFree(handle);
    return false;
  }
  ptr.asTypedList(data.length).setAll(0, data);
  _globalUnlock(handle);
  // The clipboard owns the memory once it took it.
  if (_setClipboardData(format, handle) == 0) {
    _globalFree(handle);
    return false;
  }
  return true;
}
