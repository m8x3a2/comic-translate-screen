/// LaMa (manga fine-tune, ONNX) — higher-quality, slower inpainter. Port of
/// `modules/inpainting/lama.py`.
library;

import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:ct_onnx/ct_onnx.dart';

const lamaInfo = PluginInfo(
  id: 'lama',
  displayName: 'LaMa (manga)',
  description:
      'Removes text with a larger model: better on detailed backgrounds, slower, 197 MB download. Runs locally.',
  kind: PluginKind.inpainter,
  privacy: Privacy.local,
  platforms: {PlatformId.windows, PlatformId.android, PlatformId.linux, PlatformId.macos},
  models: ['lama-manga'],
);

final lamaFactory = PluginFactory<Inpainter>(lamaInfo, (config, env) async {
  final path = await env.models.ensureFile(ModelCatalog.lamaManga, 'lama-manga-dynamic.onnx');
  final inpainter = LamaInpainter.open(path, device: env.useGpu ? OrtDevice.directml : OrtDevice.cpu);
  env.log.info('inpainter_session', {
    'model': 'lama-manga',
    'device': inpainter.device.name,
    if (inpainter.fallbackReason != null) 'fallback': inpainter.fallbackReason,
  });
  return inpainter;
});

final _f32 = Float32List(1);
double _fround(double v) {
  _f32[0] = v;
  return _f32[0];
}

/// `v / 255` in float32 for every byte value.
final Float32List _unit = Float32List.fromList([for (var v = 0; v < 256; v++) _fround(v / 255)]);

class LamaInpainter implements Inpainter {
  LamaInpainter._(this._session);

  factory LamaInpainter.open(String modelPath, {OrtDevice device = OrtDevice.cpu}) =>
      LamaInpainter._(OrtSession.open(modelPath, device: device));

  final OrtSession _session;

  OrtDevice get device => _session.device;
  String? get fallbackReason => _session.fallbackReason;

  late final InpaintModel model = InpaintModel(forward, padMod: 8);

  @override
  PluginInfo get info => lamaInfo;

  @override
  Future<RgbImage> inpaint(RgbImage image, GrayImage mask, InpaintConfig config, PluginContext context) async {
    await context.cancel.checkpoint();
    return model.call(image, mask, config);
  }

  /// `LaMa.forward` (ONNX branch).
  RgbImage forward(RgbImage image, GrayImage mask) {
    final w = image.width, h = image.height, plane = w * h;
    final x = Float32List(3 * plane);
    final mx = Float32List(plane);
    for (var i = 0; i < plane; i++) {
      mx[i] = mask.data[i] > 0 ? 1.0 : 0.0;
      for (var c = 0; c < 3; c++) {
        x[c * plane + i] = _unit[image.data[i * 3 + c]];
      }
    }
    final out = _session.run({
      _session.inputs[0].name: OrtTensor.float32(x, [1, 3, h, w]),
      _session.inputs[1].name: OrtTensor.float32(mx, [1, 1, h, w]),
    })[_session.outputs.first.name]!.asFloat32;
    final result = Uint8List(plane * 3);
    for (var i = 0; i < plane; i++) {
      for (var c = 0; c < 3; c++) {
        final v = _fround(out[c * plane + i] * 255);
        result[i * 3 + c] = v <= 0 ? 0 : (v >= 255 ? 255 : v.toInt());
      }
    }
    return RgbImage(w, h, result);
  }

  @override
  Future<void> dispose() async => _session.dispose();
}
