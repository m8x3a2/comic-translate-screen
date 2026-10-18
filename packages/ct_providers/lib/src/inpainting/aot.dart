/// AOT-GAN inpainting (ONNX) — the default inpainter. Port of
/// `modules/inpainting/aot.py`.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:ct_onnx/ct_onnx.dart';

const aotInfo = PluginInfo(
  id: 'aot',
  displayName: 'AOT-GAN',
  description: 'Removes text and redraws the background; fast, runs locally.',
  kind: PluginKind.inpainter,
  privacy: Privacy.local,
  platforms: {PlatformId.windows, PlatformId.android, PlatformId.linux, PlatformId.macos},
  models: ['aot-inpainting'],
);

final aotFactory = PluginFactory<Inpainter>(aotInfo, (config, env) async {
  final path = await env.models.ensureFile(ModelCatalog.aot, 'aot.onnx');
  final inpainter = AotInpainter.open(path, device: env.useGpu ? OrtDevice.directml : OrtDevice.cpu);
  env.log.info('inpainter_session', {
    'model': 'aot-inpainting',
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

/// `v / 127.5 - 1.0` in float32 for every byte value.
final Float32List _normLut = Float32List.fromList([for (var v = 0; v < 256; v++) _fround(_fround(v / 127.5) - 1.0)]);

class AotInpainter implements Inpainter {
  AotInpainter._(this._session);

  factory AotInpainter.open(String modelPath, {OrtDevice device = OrtDevice.cpu}) => AotInpainter._(OrtSession.open(
        modelPath,
        device: device,
        config: const OrtSessionConfig(intraOpThreads: 4, interOpThreads: 1, sequential: true, optimizationLevel: 99),
      ));

  static const maxSize = 1024;

  final OrtSession _session;

  OrtDevice get device => _session.device;
  String? get fallbackReason => _session.fallbackReason;

  /// The model wrapped with the original's padding (multiple of 8, at least
  /// 128 px) and high-resolution strategies.
  late final InpaintModel model = InpaintModel(forward, padMod: 8, minSize: 128);

  @override
  PluginInfo get info => aotInfo;

  @override
  Future<RgbImage> inpaint(RgbImage image, GrayImage mask, InpaintConfig config, PluginContext context) async {
    context.cancel.throwIfCancelled();
    return model.call(image, mask, config);
  }

  /// `AOT.forward` (ONNX branch).
  RgbImage forward(RgbImage image, GrayImage mask) {
    final imH = image.height, imW = image.width;
    var img = image;
    var m = mask;
    if (math.max(imH, imW) > maxSize) {
      final scale = maxSize / math.max(imH, imW);
      final w = pyRound(imW * scale), h = pyRound(imH * scale);
      img = pilResize(img, w, h, filter: PilFilter.bilinear);
      m = pilResizeGray(m, w, h, filter: PilFilter.bilinear);
    }
    final w = img.width, h = img.height, plane = w * h;
    final x = Float32List(3 * plane);
    final mx = Float32List(plane);
    for (var i = 0; i < plane; i++) {
      final masked = _fround(m.data[i] / 255.0) >= 0.5;
      mx[i] = masked ? 1.0 : 0.0;
      for (var c = 0; c < 3; c++) {
        x[c * plane + i] = masked ? 0.0 : _normLut[img.data[i * 3 + c]];
      }
    }
    final out = _session.run({
      _session.inputs[0].name: OrtTensor.float32(x, [1, 3, h, w]),
      _session.inputs[1].name: OrtTensor.float32(mx, [1, 1, h, w]),
    })[_session.outputs.first.name]!.asFloat32;
    final result = Uint8List(plane * 3);
    for (var i = 0; i < plane; i++) {
      for (var c = 0; c < 3; c++) {
        final v = npRint(_fround(_fround(out[c * plane + i] + 1.0) * 127.5));
        result[i * 3 + c] = v < 0 ? 0 : (v > 255 ? 255 : v.toInt());
      }
    }
    var inpainted = RgbImage(w, h, result);
    if (w != imW || h != imH) inpainted = pilResize(inpainted, imW, imH, filter: PilFilter.bilinear);
    return inpainted;
  }

  @override
  Future<void> dispose() async => _session.dispose();
}
