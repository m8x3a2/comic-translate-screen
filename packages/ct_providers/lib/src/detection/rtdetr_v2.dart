/// RT-DETR-v2 comic text and speech-bubble detector. Port of
/// `modules/detection/rtdetr_v2_onnx.py`.
library;

import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:ct_onnx/ct_onnx.dart';

const rtdetrV2Info = PluginInfo(
  id: 'rtdetr_v2',
  displayName: 'RT-DETR-v2 (comic text & bubbles)',
  description: 'Finds speech bubbles and text regions; runs locally.',
  kind: PluginKind.detector,
  privacy: Privacy.local,
  platforms: {PlatformId.windows, PlatformId.android, PlatformId.linux, PlatformId.macos},
  settings: [
    DoubleSetting(
      key: 'confidence',
      label: 'Confidence threshold',
      help: 'Detections below this score are ignored.',
      defaultValue: 0.3,
      min: 0.05,
      max: 0.95,
    ),
  ],
  models: ['rtdetr-v2-int8'],
);

final rtdetrV2Factory = PluginFactory<TextDetector>(rtdetrV2Info, (config, env) async {
  final path = await env.models.ensureFile(ModelCatalog.rtdetrV2, 'detector-v4-s_int8.onnx');
  return RtDetrV2Detector.open(
    path,
    confidence: config.value<double>('confidence'),
    device: env.useGpu ? OrtDevice.directml : OrtDevice.cpu,
    log: env.log,
  );
});

class RtDetrV2Detector implements TextDetector {
  RtDetrV2Detector._(this._session, this.confidence, {this.annotateLines});

  /// Session options of the original: small CPU runs benefit from sequential
  /// execution and four intra-op threads.
  static const sessionConfig = OrtSessionConfig(
    intraOpThreads: 4,
    interOpThreads: 1,
    sequential: true,
    optimizationLevel: 99,
    cpuArena: true,
    memPattern: true,
  );

  static const inputSize = 640;

  factory RtDetrV2Detector.open(
    String modelPath, {
    double confidence = 0.3,
    OrtDevice device = OrtDevice.cpu,
    EventLog? log,
    LineAnnotator? annotateLines,
  }) {
    final session = OrtSession.open(modelPath, device: device, config: sessionConfig);
    log?.info('detector_session', {
      'model': 'rtdetr-v2-int8',
      'device': session.device.name,
      if (session.fallbackReason != null) 'fallback': session.fallbackReason,
    });
    return RtDetrV2Detector._(session, confidence, annotateLines: annotateLines);
  }

  final OrtSession _session;
  final double confidence;
  final ImageSlicer slicer = const ImageSlicer(
    heightToWidthRatioThreshold: 3.5,
    targetSliceRatio: 3.0,
    overlapHeightRatio: 0.2,
    minSliceHeightRatio: 0.7,
  );

  /// Splits blocks into lines (heuristic_lines port); null skips it.
  LineAnnotator? annotateLines;

  OrtDevice get device => _session.device;

  @override
  PluginInfo get info => rtdetrV2Info;

  @override
  Future<List<TextBlock>> detect(RgbImage image, PluginContext context) async {
    context.cancel.throwIfCancelled();
    final boxes = await slicer.processSlicesForDetection(image, (slice) async {
      context.cancel.throwIfCancelled();
      return detectSingle(slice);
    });
    return createTextBlocks(
      image,
      boxes.texts,
      boxes.bubbles,
      annotateLines: annotateLines,
      onAnnotateError: (e, st) => context.log.error('heuristic_lines_failed', e, st),
    );
  }

  /// `_detect_single_image`: one model pass on [image] without slicing.
  BubbleTextBoxes detectSingle(RgbImage image) {
    final raw = runModel(image);
    final bubbles = <BBox>[];
    final texts = <BBox>[];
    for (var i = 0; i < raw.scores.length; i++) {
      if (raw.scores[i] < confidence) continue;
      final b = raw.boxes;
      final box = BBox(b[i * 4].toInt(), b[i * 4 + 1].toInt(), b[i * 4 + 2].toInt(), b[i * 4 + 3].toInt());
      final label = raw.labels[i];
      if (label == 0) {
        bubbles.add(box);
      } else if (label == 1 || label == 2) {
        texts.add(box);
      }
    }
    return (bubbles: bubbles, texts: texts);
  }

  /// Raw model outputs for [image]: boxes in image pixels.
  ({Int64List labels, Float32List boxes, Float32List scores}) runModel(RgbImage image) {
    final input = preprocess(image);
    final out = _session.run({
      'images': input,
      'orig_target_sizes': OrtTensor.int64(Int64List.fromList([image.width, image.height]), [1, 2]),
    });
    final labels = out[_session.outputs[0].name]!;
    final boxes = out[_session.outputs[1].name]!;
    final scores = out[_session.outputs[2].name]!;
    return (
      labels: labels.type == OrtElementType.int64
          ? labels.asInt64
          : Int64List.fromList([for (final v in labels.asInt32) v]),
      boxes: boxes.asFloat32,
      scores: scores.asFloat32,
    );
  }

  /// Pillow bicubic resize to 640×640, scale to [0, 1], HWC → NCHW float32.
  static OrtTensor preprocess(RgbImage image) {
    final resized = pilResizeBicubic(image, inputSize, inputSize);
    const plane = inputSize * inputSize;
    final data = Float32List(3 * plane);
    final src = resized.data;
    for (var i = 0; i < plane; i++) {
      data[i] = src[i * 3] / 255.0;
      data[plane + i] = src[i * 3 + 1] / 255.0;
      data[2 * plane + i] = src[i * 3 + 2] / 255.0;
    }
    return OrtTensor.float32(data, const [1, 3, inputSize, inputSize]);
  }

  @override
  Future<void> dispose() async => _session.dispose();
}
