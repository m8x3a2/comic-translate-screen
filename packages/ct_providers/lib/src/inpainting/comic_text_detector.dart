/// comic-text-detector (dmMaze, GPL-3.0): its text mask head finds the
/// letters themselves, so the inpainting network repaints little of the
/// drawing around them. New in this project (cleaning levels "Medium" and
/// "High"); the export pruned to the mask and line maps, any input size
/// (`EarthWL/hiyori-onnx`). Pre- and post-processing as in the night
/// experiment of 2026-10-25 (`self\mask-inpaint-experiment\scripts\ctd_mask.py`).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:ct_onnx/ct_onnx.dart';

const comicTextDetectorInfo = PluginInfo(
  id: comicTextDetectorId,
  displayName: 'comic-text-detector',
  description: 'Finds the letters themselves for text removal, so less of the drawing is repainted. Runs locally.',
  kind: PluginKind.textMask,
  privacy: Privacy.local,
  platforms: {PlatformId.windows, PlatformId.android, PlatformId.linux, PlatformId.macos},
  models: ['comic-text-detector'],
);

final comicTextDetectorFactory = PluginFactory<TextMasker>(comicTextDetectorInfo, (config, env) async {
  final path = await env.models.ensureFile(ModelCatalog.comicTextDetector, 'comic-text-detector.onnx');
  final masker = ComicTextDetector.open(path, device: env.useGpu ? OrtDevice.directml : OrtDevice.cpu);
  env.log.info('text_masker_session', {
    'model': 'comic-text-detector',
    'device': masker.device.name,
    if (masker.fallbackReason != null) 'fallback': masker.fallbackReason,
  });
  return masker;
});

final _f32 = Float32List(1);
double _fround(double v) {
  _f32[0] = v;
  return _f32[0];
}

class ComicTextDetector implements TextMasker {
  ComicTextDetector._(this._session);

  /// Without denormals as zero the mask head runs ~50× slower on the CPU.
  factory ComicTextDetector.open(String modelPath, {OrtDevice device = OrtDevice.cpu}) => ComicTextDetector._(
    OrtSession.open(modelPath, device: device, config: const OrtSessionConfig(denormalsAsZero: true)),
  );

  final OrtSession _session;

  OrtDevice get device => _session.device;
  String? get fallbackReason => _session.fallbackReason;

  /// The network sees pages letterboxed to this square.
  static const inputSize = 1024;

  /// Mask probability that counts as a letter (manga-image-translator: 0.3).
  static const threshold = 0.3;

  /// Pages longer than this many times their width (or wider than their
  /// height) are read in overlapping pieces, so that letters stay large.
  static const maxAspect = 3.0;

  @override
  PluginInfo get info => comicTextDetectorInfo;

  @override
  Future<GrayImage> letters(RgbImage image, PluginContext context) async {
    await context.cancel.checkpoint();
    final w = image.width, h = image.height;
    final prob = GrayImage.zeros(w, h);
    for (final piece in _pieces(w, h)) {
      final crop = piece.width == w && piece.height == h ? image : image.crop(piece);
      final p = probability(crop);
      for (var y = 0; y < piece.height; y++) {
        for (var x = 0; x < piece.width; x++) {
          final i = (piece.y1 + y) * w + piece.x1 + x;
          final v = p.data[y * piece.width + x];
          if (v > prob.data[i]) prob.data[i] = v;
        }
      }
      await context.cancel.checkpoint();
    }
    final cut = (threshold * 255).toInt();
    return GrayImage(w, h, Uint8List.fromList([for (final v in prob.data) v > cut ? 255 : 0]));
  }

  /// Overlapping pieces of a very long (or wide) page, or the whole page.
  static List<BBox> _pieces(int w, int h) {
    if (h <= maxAspect * w && w <= maxAspect * h) return [BBox(0, 0, w, h)];
    final tall = h > w;
    final side = tall ? w : h, length = tall ? h : w;
    final size = (side * 1.5).round(), step = (size * 0.85).round();
    final out = <BBox>[];
    for (var start = 0; ; start += step) {
      final end = math.min(length, start + size);
      final s = math.max(0, end - size);
      out.add(tall ? BBox(0, s, w, end) : BBox(s, 0, end, h));
      if (end >= length) break;
    }
    return out;
  }

  /// The mask head's probability (0..255) at the size of [image].
  GrayImage probability(RgbImage image) {
    final w = image.width, h = image.height;
    final r = inputSize / math.max(w, h);
    final nw = math.max(1, pyRound(w * r)), nh = math.max(1, pyRound(h * r));
    final small = nw == w && nh == h ? image : pilResize(image, nw, nh, filter: PilFilter.bilinear);
    const s = inputSize, plane = s * s;
    final x = Float32List(3 * plane);
    for (var yy = 0; yy < nh; yy++) {
      for (var xx = 0; xx < nw; xx++) {
        final o = small.offset(xx, yy), i = yy * s + xx;
        x[i] = small.data[o] / 255.0;
        x[plane + i] = small.data[o + 1] / 255.0;
        x[2 * plane + i] = small.data[o + 2] / 255.0;
      }
    }
    final out = _session.run({
      _session.inputs.first.name: OrtTensor.float32(x, [1, 3, s, s]),
    });
    final seg = (out['seg'] ?? out[_session.outputs.first.name]!).asFloat32;
    final q = Uint8List(nw * nh);
    for (var yy = 0; yy < nh; yy++) {
      for (var xx = 0; xx < nw; xx++) {
        final v = _fround(seg[yy * s + xx] * 255);
        q[yy * nw + xx] = v <= 0 ? 0 : (v >= 255 ? 255 : v.toInt());
      }
    }
    final m = GrayImage(nw, nh, q);
    return nw == w && nh == h ? m : pilResizeGray(m, w, h, filter: PilFilter.bilinear);
  }

  @override
  Future<void> dispose() async => _session.dispose();
}
