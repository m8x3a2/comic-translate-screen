/// Saving a webtoon strip as one long picture, or cut again into parts of
/// about the same height (not in the original, which saves its pages as
/// they are). Cuts go along the calmest rows near the wanted height (an
/// even background between panels), not through a bubble or a drawing.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../image/cv_bridge.dart';
import '../image/raster.dart';
import '../webtoon/seams.dart';

/// How the pages of a webtoon are saved.
enum StripExport {
  /// Each page as it is.
  pages,

  /// All pages (of a chapter) as one picture.
  single,

  /// The strip cut again into parts of about [ExportOptions.sliceHeight].
  slices;

  static StripExport parse(String? name) => values.firstWhere((v) => v.name == name, orElse: () => pages);
}

const minSliceHeight = 400;

/// WebP pictures can be no taller than this.
const maxSliceHeight = 16000;

/// Tallest JPEG and WebP pictures (taller ones are saved as PNG).
const _maxJpeg = 65500, _maxWebp = 16383;

/// Where each page of the strip starts horizontally: each page is centred
/// on the one above it (as in the webtoon view).
List<int> stripOffsets(List<int> widths) {
  final xs = <int>[];
  var x = 0;
  for (final (i, w) in widths.indexed) {
    if (i > 0) x += seamDx(widths[i - 1], w);
    xs.add(x);
  }
  final left = xs.isEmpty ? 0 : xs.reduce(math.min);
  return [for (final v in xs) v - left];
}

/// How uneven row [y] of [image] is: pixels that differ clearly from the
/// row's average brightness.
int _rowNoise(RgbImage image, int y) {
  final w = image.width, d = image.data, o = y * w * 3;
  var sum = 0;
  for (var x = 0; x < w; x++) {
    sum += d[o + x * 3] + d[o + x * 3 + 1] + d[o + x * 3 + 2];
  }
  final mean = sum / w;
  var n = 0;
  for (var x = 0; x < w; x++) {
    final v = d[o + x * 3] + d[o + x * 3 + 1] + d[o + x * 3 + 2];
    if ((v - mean).abs() > 72) n++;
  }
  return n;
}

/// The row to cut [image] at, near [target]: the calmest one within a
/// quarter of [target] around it (the nearest among equally calm ones).
int chooseCut(RgbImage image, int target) {
  final lo = math.max(1, target - target ~/ 4), hi = math.min(image.height - 1, target + target ~/ 4);
  if (hi <= lo) return math.min(target, image.height);
  var best = target.clamp(lo, hi), bestNoise = 1 << 30;
  for (var y = lo; y <= hi; y++) {
    final n = _rowNoise(image, y);
    if (n < bestNoise || (n == bestNoise && (y - target).abs() < (best - target).abs())) {
      best = y;
      bestNoise = n;
    }
  }
  return best;
}

/// The extension a picture of [height] rows can be saved with.
String stripExtension(String ext, int height) {
  final e = ext.toLowerCase();
  if ((e == '.jpg' || e == '.jpeg') && height > _maxJpeg) return '.png';
  if (e == '.webp' && height > _maxWebp) return '.png';
  return e;
}

/// Joins the pictures [files] into one strip and saves it into [dir] as
/// `stem.ext`, or cut into parts `stem_001.ext` … of about [sliceHeight]
/// rows. The cuts are chosen on the strip unless given in [cuts] (strip
/// rows; the other kind of picture of the same pages is cut at the same
/// rows). Returns the written files and the cuts.
Future<(List<String>, List<int>)> joinStrip(
  List<String> files,
  String dir,
  String stem,
  String ext, {
  int? sliceHeight,
  List<int>? cuts,
}) async {
  // The widths first: the strip is as wide as its widest page.
  final widths = <int>[];
  final heights = <int>[];
  for (final f in files) {
    final img = await ImageCodec.readFile(f);
    widths.add(img.width);
    heights.add(img.height);
  }
  final xs = stripOffsets(widths);
  var width = 0;
  for (final (i, w) in widths.indexed) {
    width = math.max(width, xs[i] + w);
  }
  Directory(dir).createSync(recursive: true);
  final out = <String>[];
  final chosen = <int>[];

  Future<void> write(RgbImage image, String name) async {
    final file = p.join(dir, '$name${stripExtension(ext, image.height)}');
    await ImageCodec.writeFile(file, image);
    out.add(file);
  }

  if (sliceHeight == null && cuts == null) {
    // One picture: filled in place.
    final total = heights.fold(0, (a, b) => a + b);
    final strip = Uint8List(total * width * 3)..fillRange(0, total * width * 3, 255);
    var top = 0;
    for (final (i, f) in files.indexed) {
      final img = await ImageCodec.readFile(f);
      for (var y = 0; y < img.height; y++) {
        final at = ((top + y) * width + xs[i]) * 3;
        strip.setRange(at, at + img.width * 3, img.data, y * img.width * 3);
      }
      top += img.height;
    }
    await write(RgbImage(width, total, strip), stem);
    return (out, const <int>[]);
  }

  // Rows not written yet, starting at strip row [start].
  var pending = Uint8List(0);
  var start = 0;
  RgbImage rows() => RgbImage(width, pending.length ~/ (width * 3), pending);
  void drop(int n) {
    pending = Uint8List.fromList(Uint8List.sublistView(pending, n * width * 3));
    start += n;
  }

  final given = [...?cuts];
  var part = 0;
  String partName() => '${stem}_${'${++part}'.padLeft(3, '0')}';
  for (final (i, f) in files.indexed) {
    final img = await ImageCodec.readFile(f);
    final merged = Uint8List(pending.length + img.height * width * 3)
      ..setAll(0, pending)
      ..fillRange(pending.length, pending.length + img.height * width * 3, 255);
    for (var y = 0; y < img.height; y++) {
      final at = pending.length + (y * width + xs[i]) * 3;
      merged.setRange(at, at + img.width * 3, img.data, y * img.width * 3);
    }
    pending = merged;
    final n = sliceHeight;
    if (n == null) continue;
    while (true) {
      final have = pending.length ~/ (width * 3);
      int cut;
      if (cuts != null) {
        if (given.isEmpty || given.first > start + have) break;
        cut = given.removeAt(0) - start;
      } else {
        // What is left at the end (up to a quarter more) stays one part.
        if (have < n + n ~/ 4) break;
        cut = chooseCut(rows(), n);
        chosen.add(start + cut);
      }
      if (cut <= 0) continue;
      await write(RgbImage(width, cut, Uint8List.sublistView(pending, 0, cut * width * 3)), partName());
      drop(cut);
    }
  }
  if (pending.isNotEmpty) await write(rows(), partName());
  return (out, cuts ?? chosen);
}
