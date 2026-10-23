/// PP-OCRv5 text line detector: finds lines of ordinary text (screenshots,
/// sites, games, visual novels) and gathers them into blocks. The model and
/// the line handling are the original's (`modules/detection/ppocr_lines.py`),
/// which uses them only to split RT-DETR blocks into lines; finding blocks
/// with it is new (see `groupLinesIntoBlocks`).
library;

import 'package:ct_core/ct_core.dart';
import 'package:ct_onnx/ct_onnx.dart';

const ppocrLinesInfo = PluginInfo(
  id: 'ppocr_lines',
  displayName: 'PP-OCR text lines (screens, sites, games)',
  description: 'Finds lines of ordinary text, not only speech bubbles; runs locally.',
  kind: PluginKind.detector,
  privacy: Privacy.local,
  platforms: {PlatformId.windows, PlatformId.android, PlatformId.linux, PlatformId.macos},
  settings: [
    DoubleSetting(
      key: 'box_threshold',
      label: 'Confidence threshold',
      help: 'Lines below this score are ignored.',
      info:
          'How sure the program must be that it found a line of text (0.2 to 0.9). Lower finds faint text, '
          'but may take patterns for text; higher misses small or faint lines. Usually 0.5.',
      defaultValue: 0.5,
      min: 0.2,
      max: 0.9,
    ),
  ],
  models: ['ppocr-v5-det-mobile'],
);

final ppocrLinesFactory = PluginFactory<TextDetector>(ppocrLinesInfo, (config, env) async {
  final path = await env.models.ensureFile(ModelCatalog.ppocrDet, 'ch_PP-OCRv5_mobile_det.onnx');
  return PpocrLineDetector.open(
    path,
    boxThreshold: config.value<double>('box_threshold'),
    device: env.useGpu ? OrtDevice.directml : OrtDevice.cpu,
    log: env.log,
  );
});

/// How much the boxes the model finds are grown. The original's 2.0 makes
/// boxes so tall that the recognizer misreads long lines; on English
/// screenshots of games and novels 1.2–1.4 read best (93 % of words against
/// 71 %), and 1.4 loses least on tiny comic text.
const lineUnclipRatio = 1.4;

/// Pieces of one line are merged across a gap of at most this many line
/// heights (the original allows two, or 8 % of the page, which joins two
/// columns of a phone screenshot into one line).
const lineMergeGap = 1.0;

class PpocrLineDetector implements LineDetector {
  PpocrLineDetector._(this._session, this.post, this.lineGap);

  factory PpocrLineDetector.open(
    String modelPath, {
    double boxThreshold = 0.5,
    double unclipRatio = lineUnclipRatio,
    double? lineGap = lineMergeGap,
    OrtDevice device = OrtDevice.cpu,
    EventLog? log,
  }) {
    final session = OrtSession.open(modelPath, device: device);
    log?.info('detector_session', {
      'model': 'ppocr-v5-det-mobile',
      'device': session.device.name,
      if (session.fallbackReason != null) 'fallback': session.fallbackReason,
    });
    return PpocrLineDetector._(session, DbPostProcessor(boxThresh: boxThreshold, unclipRatio: unclipRatio), lineGap);
  }

  final OrtSession _session;
  final DbPostProcessor post;

  /// See [lineMergeGap]; null: the original's rule.
  final double? lineGap;

  /// Very tall pages (webtoons, long screenshots) are read in overlapping
  /// slices, as RT-DETR does.
  final ImageSlicer slicer = const ImageSlicer();

  OrtDevice get device => _session.device;

  @override
  PluginInfo get info => ppocrLinesInfo;

  @override
  Future<List<TextBlock>> detect(RgbImage image, PluginContext context) async =>
      groupLinesIntoBlocks(await findLines(image, context));

  @override
  Future<List<BBox>> findLines(RgbImage image, PluginContext context) async {
    context.cancel.throwIfCancelled();
    final found = await slicer.processSlicesForDetection(image, (slice) async {
      context.cancel.throwIfCancelled();
      return (bubbles: const <BBox>[], texts: detectLines(slice));
    });
    return mergeLineBoxes(found.texts, image.width, image.height, maxGap: lineGap);
  }

  /// `PPOCRLineDetector.detect_lines`: whole text lines of [image].
  List<BBox> detectLines(RgbImage image) =>
      mergeLineBoxes([for (final q in detectQuads(image)) axisBox(q)], image.width, image.height, maxGap: lineGap);

  /// The line quadrilaterals the model finds on [image] (page pixels).
  List<Quad> detectQuads(RgbImage image) {
    final input = detPreprocess(image);
    final out = _session.run({
      _session.inputs.first.name: OrtTensor.float32(input.data, [1, 3, input.height, input.width]),
    })[_session.outputs.first.name]!;
    return post(out.asFloat32, input.width, input.height, image.width, image.height);
  }

  @override
  Future<void> dispose() async => _session.dispose();
}
