/// Files on the clipboard, as Explorer's "Copy" puts them there: Ctrl+V in a
/// chat in the browser attaches all of them at once. And back: Ctrl+V in the
/// app adds copied files or a copied picture (a screenshot, "Copy image" in a
/// browser) as pages.
library;

import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:ffi/ffi.dart';

const _cfDib = 8;
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
final _globalSize = _kernel32.lookupFunction<IntPtr Function(IntPtr), int Function(int)>('GlobalSize');
final _isFormatAvailable = _user32.lookupFunction<Int32 Function(Uint32), int Function(int)>(
  'IsClipboardFormatAvailable',
);
final _getClipboardData = _user32.lookupFunction<IntPtr Function(Uint32), int Function(int)>('GetClipboardData');

/// Puts [paths] on the clipboard as files. False when it could not (another
/// program holds the clipboard, or not on Windows).
bool copyFilesToClipboard(List<String> paths) {
  if (!Platform.isWindows || paths.isEmpty) return false;
  final bytes = dropFiles([for (final path in paths) File(path).absolute.path]);
  final effect = Uint8List(4)..buffer.asByteData().setUint32(0, _dropEffectCopy, Endian.little);
  if (!_open()) return false;
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

/// Opens the clipboard; another program may hold it for a moment.
bool _open() {
  for (var attempt = 0; attempt < 5; attempt++) {
    if (_openClipboard(0) != 0) return true;
    sleep(const Duration(milliseconds: 30));
  }
  return false;
}

/// What Ctrl+V can add as pages.
sealed class ClipboardPages {
  const ClipboardPages();
}

/// Files copied in Explorer.
class ClipboardFiles extends ClipboardPages {
  const ClipboardFiles(this.paths);

  final List<String> paths;
}

/// A picture: a PNG file's bytes (browsers put one there) or a Windows
/// bitmap (DIB: screenshots), see [pictureToPng].
class ClipboardPicture extends ClipboardPages {
  const ClipboardPicture(this.bytes, {required this.png});

  final Uint8List bytes;
  final bool png;
}

/// The files or the picture on the clipboard; null when there is neither
/// (or not on Windows, or another program holds the clipboard).
ClipboardPages? readClipboardPages() {
  if (!Platform.isWindows || !_open()) return null;
  try {
    if (_isFormatAvailable(_cfHdrop) != 0) {
      final bytes = _get(_cfHdrop);
      if (bytes != null) return ClipboardFiles(filesOfDrop(bytes));
    }
    final name = 'PNG'.toNativeUtf16();
    final int png;
    try {
      png = _registerFormat(name);
    } finally {
      calloc.free(name);
    }
    if (png != 0 && _isFormatAvailable(png) != 0) {
      final bytes = _get(png);
      if (bytes != null) return ClipboardPicture(bytes, png: true);
    }
    if (_isFormatAvailable(_cfDib) != 0) {
      final bytes = _get(_cfDib);
      if (bytes != null) return ClipboardPicture(bytes, png: false);
    }
    return null;
  } finally {
    _closeClipboard();
  }
}

/// A copy of the clipboard's data in [format] (the clipboard is open).
Uint8List? _get(int format) {
  final handle = _getClipboardData(format);
  if (handle == 0) return null;
  final size = _globalSize(handle);
  final ptr = _globalLock(handle);
  if (ptr == nullptr) return null;
  try {
    return Uint8List.fromList(ptr.asTypedList(size));
  } finally {
    _globalUnlock(handle);
  }
}

/// The names in a DROPFILES block (see [dropFiles]).
List<String> filesOfDrop(Uint8List bytes) {
  final data = bytes.buffer.asByteData(bytes.offsetInBytes, bytes.length);
  if (bytes.length < 20) return const [];
  final start = data.getUint32(0, Endian.little);
  final wide = data.getUint32(16, Endian.little) != 0;
  final names = <String>[];
  var name = <int>[];
  final step = wide ? 2 : 1;
  for (var i = start; i + step <= bytes.length; i += step) {
    final c = wide ? data.getUint16(i, Endian.little) : bytes[i];
    if (c != 0) {
      name.add(c);
      continue;
    }
    if (name.isEmpty) break; // the second zero: end of the list
    names.add(wide ? String.fromCharCodes(name) : systemEncoding.decode(name));
    name = [];
  }
  return names;
}

/// A clipboard picture as a PNG file's bytes. Windows bitmaps of 24 or 32
/// bits are read here (their fourth byte is usually not a real alpha:
/// screenshots would come out transparent), others through OpenCV.
Uint8List pictureToPng(ClipboardPicture picture) {
  if (picture.png) return picture.bytes;
  final dib = picture.bytes;
  final data = dib.buffer.asByteData(dib.offsetInBytes, dib.length);
  final header = data.getUint32(0, Endian.little);
  final width = data.getInt32(4, Endian.little);
  final rawHeight = data.getInt32(8, Endian.little);
  final bits = data.getUint16(14, Endian.little);
  final compression = data.getUint32(16, Endian.little);
  final used = data.getUint32(32, Endian.little);
  // BI_BITFIELDS: three masks after a 40-byte header.
  final masks = compression == 3 && header == 40 ? 12 : 0;
  final colors = used != 0 ? used : (bits <= 8 ? 1 << bits : 0);
  final pixels = header + masks + colors * 4;
  if ((bits == 24 || bits == 32) && (compression == 0 || compression == 3)) {
    final height = rawHeight.abs();
    final stride = (width * bits + 31) ~/ 32 * 4;
    final step = bits ~/ 8;
    final rgb = Uint8List(width * height * 3);
    for (var y = 0; y < height; y++) {
      // Positive height: the bottom row comes first.
      final row = pixels + (rawHeight > 0 ? height - 1 - y : y) * stride;
      for (var x = 0, s = row, d = y * width * 3; x < width; x++, s += step, d += 3) {
        rgb[d] = dib[s + 2];
        rgb[d + 1] = dib[s + 1];
        rgb[d + 2] = dib[s];
      }
    }
    return ImageCodec.encodePng(RgbImage(width, height, rgb));
  }
  final file = Uint8List(14 + dib.length);
  file.buffer.asByteData()
    ..setUint8(0, 0x42)
    ..setUint8(1, 0x4d)
    ..setUint32(2, file.length, Endian.little)
    ..setUint32(10, 14 + pixels, Endian.little);
  file.setAll(14, dib);
  return ImageCodec.encodePng(ImageCodec.decode(file));
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
