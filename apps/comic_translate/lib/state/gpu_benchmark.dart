/// Graphics card or processor: which is faster on this computer? The same
/// test page goes through finding text, reading it and cleaning (the
/// translator is the offline mock) once on each, after a warm-up run, in the
/// background worker as real work does.
library;

import 'dart:async';

import 'package:ct_core/ct_core.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../bootstrap.dart';
import '../pipeline/page_pipeline.dart';
import '../pipeline/pipeline_worker.dart';

const speedTestPageAsset = 'assets/samples/speed_test_page.jpg';

/// The graphics card counts as faster when it saves at least this share.
const gpuFasterShare = 0.15;

enum GpuVerdict { gpuFaster, cpuBetter, gpuFailed }

class GpuBenchmarkResult {
  const GpuBenchmarkResult({this.cpuMs, this.gpuMs, this.cpuError, this.gpuError, this.fallbacks = const []});

  /// One page on the processor / graphics card, after the warm-up run.
  final int? cpuMs;
  final int? gpuMs;
  final String? cpuError;
  final String? gpuError;

  /// Models that failed on the graphics card and went on on the processor.
  final List<GpuFallback> fallbacks;

  /// How much faster the graphics card is, in whole percent (negative when
  /// slower; 0 when unknown).
  int get gainPercent {
    final cpu = cpuMs, gpu = gpuMs;
    if (cpu == null || gpu == null || cpu == 0) return 0;
    return ((cpu - gpu) * 100 / cpu).round();
  }

  GpuVerdict get verdict {
    if (gpuError != null || fallbacks.isNotEmpty || gpuMs == null) return GpuVerdict.gpuFailed;
    final cpu = cpuMs;
    if (cpu == null) return GpuVerdict.gpuFaster;
    return gpuMs! < cpu * (1 - gpuFasterShare) ? GpuVerdict.gpuFaster : GpuVerdict.cpuBetter;
  }

  Map<String, Object?> toJson() => {
    'cpu_ms': cpuMs,
    'gpu_ms': gpuMs,
    'cpu_error': ?cpuError,
    'gpu_error': ?gpuError,
    'fallbacks': [
      for (final f in fallbacks) {'model': f.model, 'reason': f.reason},
    ],
    'verdict': verdict.name,
  };
}

/// Times the test page on the processor, then on the graphics card.
/// [onStep] tells which one is running (`cpu`, `gpu`).
Future<GpuBenchmarkResult> runGpuBenchmark(
  AppServices services,
  AppSettings settings,
  PluginRegistry Function() registry, {
  void Function(String step)? onStep,
}) async {
  final bytes = await rootBundle.load(speedTestPageAsset);
  final page = ImageCodec.decode(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
  final log = services.appLog.child(stage: 'gpu_benchmark');

  Future<int> time(bool gpu) async {
    final spec = await PipelineSpec.resolve(
      services,
      settings,
      sourceLanguage: 'English',
      targetLanguage: 'Russian',
      translatorId: 'mock',
      useGpu: gpu,
    );
    final worker = await PipelineWorker.start(
      WorkerSetup(
        spec: spec,
        modelsDir: services.models.root.path,
        homeDir: AppPaths.homeDir(),
        registry: registry,
        runLabel: 'gpu_benchmark',
      ),
      log: log,
    );
    try {
      Future<void> once() =>
          worker.prepare('speed_test_page.jpg', image: page, sourceLanguage: 'English', targetLanguage: 'Russian');
      await once();
      final sw = Stopwatch()..start();
      await once();
      return sw.elapsedMilliseconds;
    } finally {
      await worker.dispose();
    }
  }

  int? cpuMs, gpuMs;
  String? cpuError, gpuError;
  onStep?.call('cpu');
  try {
    cpuMs = await time(false);
  } on Object catch (e) {
    cpuError = '$e';
  }
  onStep?.call('gpu');
  final fallbacks = <GpuFallback>[];
  final sub = gpuFallbacks.stream.listen(fallbacks.add);
  try {
    gpuMs = await time(true);
  } on Object catch (e) {
    gpuError = '$e';
  } finally {
    // Fallback messages arrive through the same port, before the result.
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
  }
  final result = GpuBenchmarkResult(
    cpuMs: cpuMs,
    gpuMs: gpuMs,
    cpuError: cpuError,
    gpuError: gpuError,
    fallbacks: fallbacks,
  );
  services.appLog.info('gpu_benchmark', result.toJson());
  return result;
}
