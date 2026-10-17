import 'dart:io';
import 'dart:typed_data';

import 'ort.dart';

/// Result of [OrtSelfTest.run].
class OrtSelfTestResult {
  OrtSelfTestResult({
    required this.version,
    required this.providers,
    required this.cpuOk,
    required this.directmlRequested,
    required this.directmlOk,
    this.directmlFallbackReason,
    this.error,
  });

  final String? version;
  final List<String> providers;
  final bool cpuOk;
  final bool directmlRequested;
  final bool directmlOk;
  final String? directmlFallbackReason;
  final String? error;

  Map<String, Object?> toJson() => {
        'version': version,
        'providers': providers,
        'cpu_ok': cpuOk,
        'directml_requested': directmlRequested,
        'directml_ok': directmlOk,
        if (directmlFallbackReason != null) 'directml_fallback_reason': directmlFallbackReason,
        if (error != null) 'error': error,
      };
}

/// Loads ONNX Runtime and runs a tiny embedded model (C = A + B) on CPU and,
/// when available, DirectML. Used by `cts doctor`.
abstract final class OrtSelfTest {
  /// `add.onnx` from test/fixtures (see tool/make_test_models.py).
  static final Uint8List _addModel = Uint8List.fromList(const [
    8, 8, 58, 87, 10, 14, 10, 1, 65, 10, 1, 66, 18, 1, 67, 34, 3, 65, 100, 100, 18, 3, 97, 100, 100, 90, 20, 10, //
    1, 65, 18, 15, 10, 13, 8, 1, 18, 9, 10, 3, 18, 1, 78, 10, 2, 8, 3, 90, 20, 10, 1, 66, 18, 15, 10, 13, 8, 1, //
    18, 9, 10, 3, 18, 1, 78, 10, 2, 8, 3, 98, 20, 10, 1, 67, 18, 15, 10, 13, 8, 1, 18, 9, 10, 3, 18, 1, 78, 10, //
    2, 8, 3, 66, 4, 10, 0, 16, 13,
  ]);

  static Future<OrtSelfTestResult> run({bool tryDirectML = true}) async {
    final dir = await Directory.systemTemp.createTemp('cts_ort_selftest_');
    final model = File('${dir.path}${Platform.pathSeparator}add.onnx');
    try {
      await model.writeAsBytes(_addModel, flush: true);
      final rt = OrtRuntime.instance;
      final providers = rt.availableProviders;
      final cpuOk = _runOnce(model.path, OrtDevice.cpu).$1;
      var dmlOk = false;
      String? reason;
      final wantDml = tryDirectML && rt.hasDirectML;
      if (wantDml) {
        final (ok, device, fallback) = _runOnce(model.path, OrtDevice.directml);
        dmlOk = ok && device == OrtDevice.directml;
        reason = fallback;
      }
      return OrtSelfTestResult(
        version: rt.version,
        providers: providers,
        cpuOk: cpuOk,
        directmlRequested: wantDml,
        directmlOk: dmlOk,
        directmlFallbackReason: reason,
      );
    } catch (e) {
      return OrtSelfTestResult(
        version: null,
        providers: const [],
        cpuOk: false,
        directmlRequested: tryDirectML,
        directmlOk: false,
        error: e.toString(),
      );
    } finally {
      await dir.delete(recursive: true);
    }
  }

  static (bool, OrtDevice, String?) _runOnce(String path, OrtDevice device) {
    final s = OrtSession.open(path, device: device);
    try {
      final a = OrtTensor.float32(Float32List.fromList([1, 2, 3]), [1, 3]);
      final c = s.run({'A': a, 'B': a})['C']!.asFloat32;
      return (c[0] == 2 && c[1] == 4 && c[2] == 6, s.device, s.fallbackReason);
    } finally {
      s.dispose();
    }
  }
}
