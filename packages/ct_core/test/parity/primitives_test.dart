import 'package:crypto/crypto.dart';
import 'package:ct_core/src/image/raster.dart';
import 'package:ct_core/src/imaging/mahotas.dart';
import 'package:ct_core/src/imaging/pil.dart';
import 'package:ct_core/src/imaging/py_compat.dart';
import 'package:test/test.dart';

import 'reference.dart';

void main() {
  final ref = loadReference('primitives.json');
  List<Map<String, Object?>> cases(String key) =>
      (ref[key] as List).map((e) => (e as Map).cast<String, Object?>()).toList();

  test('pilToGray matches Pillow convert("L")', () {
    for (final c in cases('to_gray')) {
      final img = RgbImage(c['w'] as int, c['h'] as int, b64Bytes(c['rgb']));
      expect(pilToGray(img).data, b64Bytes(c['gray']));
    }
  });

  test('mahotasOtsu matches mahotas.otsu and imkit.otsu_threshold', () {
    var i = 0;
    for (final c in cases('otsu')) {
      final values = b64Bytes(c['values']);
      final t = mahotasOtsu(values);
      expect(t, c['mahotas'], reason: 'case $i');
      expect(t.toDouble(), c['imkit'], reason: 'case $i');
      i++;
    }
  });

  test('connectedComponentsWithStats matches imkit (mahotas labelling)', () {
    var i = 0;
    for (final c in cases('connected_components')) {
      final mask = GrayImage(c['w'] as int, c['h'] as int, b64Bytes(c['mask']));
      final cc = connectedComponentsWithStats(mask, connectivity: c['connectivity'] as int);
      expect(cc.count, c['num_labels'], reason: 'case $i count');
      expect([for (final s in cc.stats) s.toList()], c['stats'], reason: 'case $i stats');
      final centroids = (c['centroids'] as List).cast<List>();
      for (var l = 0; l < centroids.length; l++) {
        expect(cc.centroids[l].$1, closeTo((centroids[l][0] as num).toDouble(), 1e-9), reason: 'case $i centroid x $l');
        expect(cc.centroids[l].$2, closeTo((centroids[l][1] as num).toDouble(), 1e-9), reason: 'case $i centroid y $l');
      }
      if (c.containsKey('labels')) {
        expect(cc.labels, b64Int32(c['labels']), reason: 'case $i labels');
      }
      i++;
    }
  });

  test('npMedian / npPercentile match numpy', () {
    for (final c in cases('median_percentile')) {
      final values = (c['values'] as List).cast<num>();
      expect(npMedian(values), c['median']);
      expect(npPercentile(values, c['q'] as num), closeTo((c['percentile'] as num).toDouble(), 1e-12));
    }
  });

  test('pyRound matches Python round / numpy rint', () {
    for (final c in cases('round')) {
      final x = (c['x'] as num).toDouble();
      expect(pyRound(x), c['round'], reason: 'round($x)');
      expect(npRint(x), (c['np_rint'] as num).toDouble(), reason: 'rint($x)');
    }
  });

  test('pilResizeBicubic matches Pillow Image.resize', () {
    for (final c in cases('pil_resize')) {
      final img = RgbImage(c['w'] as int, c['h'] as int, b64Bytes(c['rgb']));
      final out = pilResizeBicubic(img, c['tw'] as int, c['th'] as int);
      expect([out.width, out.height], [c['tw'], c['th']]);
      if (c.containsKey('out')) expect(out.data, b64Bytes(c['out']), reason: '${c['w']}x${c['h']}');
      expect(sha256.convert(out.data).toString(), c['sha256'], reason: '${c['w']}x${c['h']} -> ${c['tw']}x${c['th']}');
    }
  });
}
