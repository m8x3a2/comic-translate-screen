// Parity of the PP-OCRv5 line detector with `PPOCRLineDetector.detect_lines`
// of the original. Needs the downloaded model
// (`cts models download ppocr-v5-det-mobile`); skipped otherwise (e.g. on CI).
//
// The original grows each box with pyclipper (round joins on integer
// coordinates); the port grows the rectangle by the same distance, so corners
// may differ by a pixel or two.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final repoRoot = p.normalize(p.join(Directory.current.path, '..', '..'));

const tolerance = 2;

void main() {
  final modelPath = p.join(AppPaths.resolve().models.path, 'ppocr-v5-det-mobile', 'ch_PP-OCRv5_mobile_det.onnx');
  final hasModel = File(modelPath).existsSync();
  final refs = (jsonDecode(
    File(p.join(repoRoot, 'test_data', 'reference', 'ppocr_lines.json')).readAsStringSync(),
  ) as List).cast<Map<String, Object?>>();

  late PpocrLineDetector detector;
  setUpAll(() {
    if (hasModel) detector = PpocrLineDetector.open(modelPath, unclipRatio: 2.0);
  });
  tearDownAll(() async {
    if (hasModel) await detector.dispose();
  });

  bool close(List<num> a, List<num> b) =>
      [for (var i = 0; i < a.length; i++) (a[i] - b[i]).abs()].every((d) => d <= tolerance);

  for (final r in refs) {
    final name = r['page'] as String;
    test(name, () async {
      final image = await ImageCodec.readFile(p.join(repoRoot, 'test_data', 'pages', 'peppercarrot', '$name.jpg'));
      final input = detPreprocess(image);
      expect([1, 3, input.height, input.width], r['input_shape']);
      expect(
        sha256.convert(input.data.buffer.asUint8List()).toString(),
        r['input_sha256'],
        reason: 'preprocessing differs',
      );

      final quads = detector.detectQuads(image);
      final want = [
        for (final q in r['quads'] as List) [for (final pt in q as List) ...(pt as List).cast<num>()],
      ];
      final got = [
        for (final q in quads)
          [
            for (final pt in q) ...[pt.x, pt.y],
          ],
      ];
      expect(got.length, want.length, reason: 'number of line pieces');
      for (final w in want) {
        expect(got.any((g) => close(g, w)), isTrue, reason: 'piece $w not found');
      }

      final lines = detector.detectLines(image);
      final wantLines = [for (final l in r['lines'] as List) (l as List).cast<num>()];
      expect(lines.length, wantLines.length, reason: 'number of lines');
      for (final w in wantLines) {
        expect(lines.any((l) => close([l.x1, l.y1, l.x2, l.y2], w)), isTrue, reason: 'line $w not found');
      }
    }, skip: hasModel ? false : 'model not downloaded');
  }
}
