/// Can the graphics card be used? Checked when the GPU setting is switched
/// on and by `cts doctor`: the adapters Windows knows, and a tiny model run
/// through DirectML.
library;

import 'package:ct_core/ct_core.dart';
import 'package:ct_onnx/ct_onnx.dart';

/// Drivers older than this are pointed out (DirectML needs DirectX 12).
const oldDriverAge = Duration(days: 4 * 365);

class GpuCheck {
  const GpuCheck(this.adapters, this.ort);

  /// All adapters, the software ones included.
  final List<GpuAdapter> adapters;
  final OrtSelfTestResult ort;

  List<GpuAdapter> get cards => [
    for (final a in adapters)
      if (!a.software) a,
  ];

  /// Only graphics built into the processor: usable, but rarely faster.
  bool get onlyIntegrated => cards.isNotEmpty && cards.every((a) => a.integrated);

  /// DirectML runs, on a real card (when the adapters cannot be listed,
  /// DirectML working is enough).
  bool get usable => ort.directmlOk && (adapters.isEmpty || cards.isNotEmpty);

  /// Why the card cannot be used (English, for logs and `cts doctor`).
  String get problem {
    if (!ort.directmlRequested) return 'DirectML is not available in this build or on this system';
    if (!ort.directmlOk) return ort.directmlFallbackReason ?? ort.error ?? 'DirectML did not run';
    if (adapters.isNotEmpty && cards.isEmpty) return 'no graphics card, only ${adapters.map((a) => a.name).join(', ')}';
    return '';
  }

  /// Cards whose driver is older than [oldDriverAge].
  List<GpuAdapter> oldDrivers(DateTime now) => [
    for (final a in cards)
      if (a.driverDate != null && now.difference(a.driverDate!) > oldDriverAge) a,
  ];

  static Future<GpuCheck> run() async => GpuCheck(await GpuInfo.list(), await OrtSelfTest.run());
}

/// `NVIDIA GeForce MX150 (2 GB)`.
String gpuLabel(GpuAdapter a) {
  final mem = a.memoryBytes;
  return mem == null ? a.name : '${a.name} (${formatBytes(mem)})';
}

/// A failure message as kept in the settings: one line, at most 300
/// characters.
String shortGpuReason(String reason) {
  final line = reason.replaceAll(RegExp(r'\s+'), ' ').trim();
  return line.length > 300 ? '${line.substring(0, 300)}…' : line;
}
