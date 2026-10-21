/// Script identification for the "Auto" source language: the OSD LSTM model
/// (Tesseract's script detector in ONNX) reads the largest line of each block.
/// Port of `ScriptDetector` (`modules/detection/script_detection.py`) and of
/// the "Auto" routing of `modules/ocr/processor.py`. Runs on the CPU, as in
/// the original: the model is tiny.
library;

import 'dart:convert';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:ct_onnx/ct_onnx.dart';

/// Model needed whenever the source language is "Auto".
const scriptModelId = 'osd-script-id';

class ScriptIdentifier {
  ScriptIdentifier(this._models, {this.log});

  final ModelManager _models;
  final EventLog? log;
  OrtSession? _session;
  List<String>? _labels;

  static const sessionConfig = OrtSessionConfig(
    intraOpThreads: 4,
    interOpThreads: 1,
    sequential: true,
    optimizationLevel: 99,
    cpuArena: true,
    memPattern: true,
  );

  Future<OrtSession> _open() async {
    final existing = _session;
    if (existing != null) return existing;
    const spec = ModelCatalog.osdScript;
    final model = await _models.ensureFile(spec, 'osd_lstm.onnx');
    final labels = await _models.ensureFile(spec, 'osd_labels.json');
    _labels = (jsonDecode(File(labels).readAsStringSync()) as List).cast<String>();
    log?.info('script_session', {'model': spec.id, 'device': 'cpu'});
    return _session = OrtSession.open(model, config: sessionConfig);
  }

  /// `detect_block_script`: the script label of [block] (`Latin`,
  /// `Japanese_vert`, `Cyrillic`, ...), empty when nothing can be read.
  Future<String> identify(RgbImage image, TextBlock block) async {
    final input = scriptInputForBlock(image, block);
    if (input == null) return '';
    final session = await _open();
    final out = session.run({
      'image': OrtTensor.float32(input.data, [1, 1, scriptInputHeight, input.width]),
    })['scores']!;
    final [steps, classes] = out.shape;
    return dominantScript(out.asFloat32, steps, classes, _labels!);
  }

  /// `annotate_blocks`: fills the script of every block (empty when reading
  /// fails; a missing model is reported).
  Future<void> annotate(RgbImage image, List<TextBlock> blocks) async {
    for (final b in blocks) {
      try {
        b.script = await identify(image, b);
      } on ModelNotInstalledException {
        rethrow;
      } on Object {
        b.script = '';
      }
    }
  }

  void dispose() {
    _session?.dispose();
    _session = null;
  }
}

/// Reads [blocks] with the "Auto" source language: identifies their scripts,
/// then hands each OCR bucket (`latin`, `cyrillic`, `japanese`, `korean`,
/// `chinese`) to [read], with each block's `sourceLang` set from its script.
Future<void> recognizeAuto(
  ScriptIdentifier scripts,
  RgbImage image,
  List<TextBlock> blocks,
  PluginContext context,
  Future<void> Function(String bucket, List<TextBlock> blocks) read,
) async {
  await scripts.annotate(image, blocks);
  context.cancel.throwIfCancelled();
  final groups = autoOcrGroups(blocks);
  context.log.info('ocr_auto', {
    'scripts': [for (final b in blocks) b.script],
    'groups': {for (final e in groups.entries) e.key: e.value.length},
  });
  for (final MapEntry(key: bucket, value: group) in groups.entries) {
    context.cancel.throwIfCancelled();
    await read(bucket, group);
  }
}
