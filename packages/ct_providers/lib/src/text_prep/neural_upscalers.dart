/// Preparing small text for reading with a neural network (ONNX): the
/// pieces of a page with thin lines are enlarged ×2 before OCR. New in this
/// project; the levels and the tiling come from the experiment of step 2
/// (`ocr-experiment/sr_run.py`, `RESULTS.md`):
/// - Simple: waifu2x CUNet art ×2 (MIT);
/// - Medium: waifu2x Swin-UNet art ×2 (MIT);
/// - High: Fatality Comix ×4 by Twittman (CC-BY-NC-SA-4.0), brought to ×2; the
///   default for comics (best in the check of step 2.1, and quick enough on
///   the pieces alone).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:ct_onnx/ct_onnx.dart';

const waifu2xCunetInfo = PluginInfo(
  id: 'waifu2x_cunet',
  displayName: 'Simple: waifu2x CUNet',
  description: 'Neural network, 5 MB. About 1 s per screenshot page.',
  kind: PluginKind.textPrep,
  privacy: Privacy.local,
  models: ['waifu2x-cunet-art-2x'],
);

const waifu2xSwinInfo = PluginInfo(
  id: 'waifu2x_swin',
  displayName: 'Medium: waifu2x Swin-UNet',
  description: 'Neural network, 17 MB. About 2 s per screenshot page.',
  kind: PluginKind.textPrep,
  privacy: Privacy.local,
  models: ['waifu2x-swin-art-2x'],
);

const fatalityComixInfo = PluginInfo(
  id: 'fatality_comix',
  displayName: 'High: Fatality Comix',
  description: 'Neural network, 64 MB, removes print screening. About 15 s per screenshot page.',
  kind: PluginKind.textPrep,
  privacy: Privacy.local,
  models: ['fatality-comix-4x'],
);

final waifu2xCunetFactory = PluginFactory<TextUpscaler>(
  waifu2xCunetInfo,
  (config, env) => NeuralTextUpscaler.load(waifu2xCunetInfo, ModelCatalog.waifu2xCunet, env, scale: 2, pad: 18),
);

final waifu2xSwinFactory = PluginFactory<TextUpscaler>(
  waifu2xSwinInfo,
  (config, env) => NeuralTextUpscaler.load(waifu2xSwinInfo, ModelCatalog.waifu2xSwin, env, scale: 2, pad: 8),
);

final fatalityComixFactory = PluginFactory<TextUpscaler>(
  fatalityComixInfo,
  (config, env) => NeuralTextUpscaler.load(fatalityComixInfo, ModelCatalog.fatalityComix, env, scale: 4, pad: 0),
);

/// A super-resolution network run in tiles. Its output (×[scale]) is
/// brought to the size asked for with Lanczos (×4 → ×2).
class NeuralTextUpscaler implements TextUpscaler {
  NeuralTextUpscaler(this.info, this._session, {required this.scale, required this.pad});

  static Future<NeuralTextUpscaler> load(
    PluginInfo info,
    ModelSpec model,
    PluginEnvironment env, {
    required int scale,
    required int pad,
  }) async {
    final path = await env.models.ensureFile(model, model.files.single.name);
    final session = OrtSession.open(
      path,
      device: env.useGpu ? OrtDevice.directml : OrtDevice.cpu,
      config: const OrtSessionConfig(intraOpThreads: 4, interOpThreads: 1, sequential: true, optimizationLevel: 99),
    );
    env.log.info('text_prep_session', {
      'model': model.id,
      'device': session.device.name,
      if (session.fallbackReason != null) 'fallback': session.fallbackReason,
    });
    return NeuralTextUpscaler(info, session, scale: scale, pad: pad);
  }

  /// Tiles (source pixels) and their overlap, as in the experiment.
  static const tile = 192;
  static const overlap = 16;

  /// Some networks need sides divisible by 16 (windows, U-Net levels).
  static const multiple = 16;

  @override
  final PluginInfo info;
  final OrtSession _session;

  /// The network's own factor.
  final int scale;

  /// Pixels the network loses at each edge (waifu2x), on the source scale:
  /// added back by mirroring the piece.
  final int pad;

  @override
  double get factor => 2.0;

  @override
  Future<RgbImage> enlarge(RgbImage piece, int width, int height, PluginContext context) async {
    final h = piece.height, w = piece.width;
    final out = Uint8List(h * scale * w * scale * 3);
    for (final (y0, x0) in _tiles(w, h)) {
      // Between tiles a cancel can come in (a minute of work on "High").
      await context.cancel.checkpoint();
      _tile(piece, out, y0, x0);
    }
    return _resized(RgbImage(w * scale, h * scale, out), width, height);
  }

  RgbImage _resized(RgbImage out, int width, int height) =>
      out.width == width && out.height == height ? out : pilResize(out, width, height, filter: PilFilter.lanczos);

  /// [img] enlarged ×[scale] (`upscale` of `sr_run.py`), in one go.
  RgbImage run(RgbImage img) {
    final out = Uint8List(img.height * scale * img.width * scale * 3);
    for (final (y0, x0) in _tiles(img.width, img.height)) {
      _tile(img, out, y0, x0);
    }
    return RgbImage(img.width * scale, img.height * scale, out);
  }

  static const _step = tile - 2 * overlap;

  /// Top left corners of the tiles of a [w]×[h] image, row by row.
  static Iterable<(int, int)> _tiles(int w, int h) sync* {
    for (var y0 = 0; y0 < h; y0 += _step) {
      for (var x0 = 0; x0 < w; x0 += _step) {
        yield (y0, x0);
      }
    }
  }

  /// Runs the network on the tile at [y0], [x0] of [img] and writes its
  /// inner part into [out] (×[scale]).
  void _tile(RgbImage img, Uint8List out, int y0, int x0) {
    final h = img.height, w = img.width, s = scale;
    const step = _step;
    final ya = math.max(0, y0 - overlap), xa = math.max(0, x0 - overlap);
    final yb = math.min(h, y0 + step + overlap), xb = math.min(w, x0 + step + overlap);
    final ch = yb - ya, cw = xb - xa;
    final eh = (multiple - ch % multiple) % multiple, ew = (multiple - cw % multiple) % multiple;
    final inH = ch + eh + 2 * pad, inW = cw + ew + 2 * pad;
    // Rows and columns of the input in the source: mirrored past the
    // edges (`np.pad` "reflect"), then the last one repeated to the
    // multiple ("edge").
    final rows = [for (var i = 0; i < inH; i++) _reflect(ya + math.min<int>(i, ch + 2 * pad - 1) - pad, h)];
    final cols = [for (var i = 0; i < inW; i++) _reflect(xa + math.min<int>(i, cw + 2 * pad - 1) - pad, w)];
    final plane = inH * inW;
    final x = Float32List(3 * plane);
    for (var iy = 0; iy < inH; iy++) {
      final row = rows[iy] * w;
      for (var ix = 0; ix < inW; ix++) {
        final o = (row + cols[ix]) * 3, i = iy * inW + ix;
        x[i] = img.data[o] / 255;
        x[plane + i] = img.data[o + 1] / 255;
        x[2 * plane + i] = img.data[o + 2] / 255;
      }
    }
    final result = _session.run({
      _session.inputs.first.name: OrtTensor.float32(x, [1, 3, inH, inW]),
    });
    final y = result[_session.outputs.first.name]!;
    final oh = y.shape[2], ow = y.shape[3], oPlane = oh * ow;
    final data = y.asFloat32;
    // The inner part of the tile.
    final iy0 = (y0 - ya) * s, ix0 = (x0 - xa) * s;
    final hh = (math.min(h, y0 + step) - y0) * s, ww = (math.min(w, x0 + step) - x0) * s;
    for (var yy = 0; yy < hh; yy++) {
      final src = (iy0 + yy) * ow + ix0;
      var dst = ((y0 * s + yy) * w * s + x0 * s) * 3;
      for (var xx = 0; xx < ww; xx++) {
        for (var c = 0; c < 3; c++) {
          out[dst++] = _byte(data[c * oPlane + src + xx]);
        }
      }
    }
  }

  @override
  Future<void> dispose() async => _session.dispose();
}

final _f32 = Float32List(1);
double _fround(double v) {
  _f32[0] = v;
  return _f32[0];
}

/// `(np.clip(v, 0, 1) * 255 + 0.5).astype(np.uint8)` in float32, as numpy.
int _byte(double v) => _fround(_fround((v < 0 ? 0.0 : (v > 1 ? 1.0 : v)) * 255) + 0.5).toInt();

/// Index [i] mirrored into `0..n-1` without repeating the edge pixel.
int _reflect(int i, int n) {
  if (n == 1) return 0;
  final period = 2 * (n - 1);
  var k = i % period;
  if (k < 0) k += period;
  return k < n ? k : period - k;
}
