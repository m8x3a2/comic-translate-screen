// The GPU setting: when the graphics card can be used.

import 'package:comic_translate/pipeline/pipeline_worker.dart' show GpuFallback;
import 'package:comic_translate/state/gpu_benchmark.dart';
import 'package:comic_translate/state/gpu_check.dart';
import 'package:ct_core/ct_core.dart';
import 'package:ct_onnx/ct_onnx.dart';
import 'package:flutter_test/flutter_test.dart';

OrtSelfTestResult ort({bool dml = true, String? reason}) => OrtSelfTestResult(
  version: '1',
  providers: const [],
  cpuOk: true,
  directmlRequested: true,
  directmlOk: dml,
  directmlFallbackReason: reason,
);

void main() {
  final mx150 = GpuAdapter(name: 'NVIDIA GeForce MX150', memoryBytes: 2 << 30, driverDate: DateTime.utc(2020, 1, 29));
  final uhd = GpuAdapter(name: 'Intel(R) UHD Graphics 620', driverDate: DateTime.utc(2025, 1, 1));
  const basic = GpuAdapter(name: 'Microsoft Basic Display Adapter');

  test('a card and DirectML working: usable; old drivers are pointed out', () {
    final c = GpuCheck([mx150, uhd], ort());
    expect(c.usable, isTrue);
    expect(c.onlyIntegrated, isFalse);
    expect(c.oldDrivers(DateTime.utc(2026, 10, 21)), [mx150]);
    expect(gpuLabel(mx150), 'NVIDIA GeForce MX150 (2.0 GB)');
  });

  test('only built-in graphics: usable, with a note', () {
    final c = GpuCheck([uhd], ort());
    expect(c.usable, isTrue);
    expect(c.onlyIntegrated, isTrue);
  });

  test('no card or DirectML failing: not usable, with the reason', () {
    final noCard = GpuCheck(const [basic], ort());
    expect(noCard.usable, isFalse);
    expect(noCard.problem, contains('Microsoft Basic Display Adapter'));
    final failed = GpuCheck([mx150], ort(dml: false, reason: 'device removed'));
    expect(failed.usable, isFalse);
    expect(failed.problem, 'device removed');
    expect(GpuCheck(const [], ort()).usable, isTrue, reason: 'adapters not listed: DirectML decides');
  });

  test('speed test verdict: faster by 15 % or more, else the processor; any failure', () {
    expect(const GpuBenchmarkResult(cpuMs: 2000, gpuMs: 1500).verdict, GpuVerdict.gpuFaster);
    expect(const GpuBenchmarkResult(cpuMs: 2000, gpuMs: 1800).verdict, GpuVerdict.cpuBetter);
    expect(const GpuBenchmarkResult(cpuMs: 1900, gpuMs: 2200).verdict, GpuVerdict.cpuBetter);
    expect(const GpuBenchmarkResult(cpuMs: 1400, gpuError: 'Softmax').verdict, GpuVerdict.gpuFailed);
    expect(
      const GpuBenchmarkResult(cpuMs: 1400, gpuMs: 900, fallbacks: [GpuFallback('rec.onnx', 'Softmax')]).verdict,
      GpuVerdict.gpuFailed,
      reason: 'fast only because a model ran on the processor',
    );
    expect(const GpuBenchmarkResult(cpuMs: 1400, gpuMs: 900).toJson()['verdict'], 'gpuFaster');
  });
}
