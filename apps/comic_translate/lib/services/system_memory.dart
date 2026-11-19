/// How much memory (RAM) the device has and how much is free: shown next to
/// what each level of the neural networks needs (the owner's wish of
/// 2026-11-19). Windows asks the system; Linux and Android read
/// /proc/meminfo.
library;

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

class SystemMemory {
  const SystemMemory({required this.totalMb, required this.freeMb});

  final int totalMb;

  /// Free for new programs right now (Windows "available", Linux
  /// "MemAvailable"): what a model can take without pushing others out.
  final int freeMb;

  /// The memory of this device; null where it cannot be told.
  static SystemMemory? read() {
    try {
      if (Platform.isWindows) return _windows();
      if (Platform.isLinux || Platform.isAndroid) return _procMeminfo();
    } catch (_) {
      // Unknown: the levels are shown without the comparison.
    }
    return null;
  }
}

final class _MemoryStatusEx extends Struct {
  @Uint32()
  external int dwLength;
  @Uint32()
  external int dwMemoryLoad;
  @Uint64()
  external int ullTotalPhys;
  @Uint64()
  external int ullAvailPhys;
  @Uint64()
  external int ullTotalPageFile;
  @Uint64()
  external int ullAvailPageFile;
  @Uint64()
  external int ullTotalVirtual;
  @Uint64()
  external int ullAvailVirtual;
  @Uint64()
  external int ullAvailExtendedVirtual;
}

SystemMemory? _windows() {
  final status = DynamicLibrary.open('kernel32.dll')
      .lookupFunction<Int32 Function(Pointer<_MemoryStatusEx>), int Function(Pointer<_MemoryStatusEx>)>(
        'GlobalMemoryStatusEx',
      );
  final s = calloc<_MemoryStatusEx>();
  try {
    s.ref.dwLength = sizeOf<_MemoryStatusEx>();
    if (status(s) == 0) return null;
    return SystemMemory(totalMb: s.ref.ullTotalPhys >> 20, freeMb: s.ref.ullAvailPhys >> 20);
  } finally {
    calloc.free(s);
  }
}

SystemMemory? _procMeminfo() {
  final values = <String, int>{};
  for (final line in File('/proc/meminfo').readAsLinesSync()) {
    final m = RegExp(r'^(\w+):\s+(\d+) kB').firstMatch(line);
    if (m != null) values[m[1]!] = int.parse(m[2]!);
  }
  final total = values['MemTotal'];
  final free = values['MemAvailable'] ?? values['MemFree'];
  if (total == null || free == null) return null;
  return SystemMemory(totalMb: total >> 10, freeMb: free >> 10);
}
