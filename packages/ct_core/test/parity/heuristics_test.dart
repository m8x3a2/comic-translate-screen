// Parity of the heuristic line splitter with the original comic-translate
// (`_detect_lines_and_direction_in_crop`) on crops of the test pages:
// detected blocks and bubbles, rotated by 90° (vertical text), inverted and
// random regions. Reference: tools/reference/gen_reference.py (heuristics).

import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

import 'reference.dart';

/// `np.rot90(crop)`: counter-clockwise.
RgbImage rot90(RgbImage src) {
  final w = src.height, h = src.width;
  final out = RgbImage.filled(w, h, 0, 0, 0);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final s = src.offset(src.width - 1 - y, x);
      final d = out.offset(x, y);
      out.data.setRange(d, d + 3, src.data, s);
    }
  }
  return out;
}

RgbImage invert(RgbImage src) =>
    RgbImage(src.width, src.height, Uint8List.fromList([for (final v in src.data) 255 - v]));

void main() {
  final cases = (loadReference('heuristics.json')['cases'] as List).cast<Map<String, Object?>>();
  final pages = <String, RgbImage>{};

  setUpAll(() async {
    for (final name in {for (final c in cases) c['page'] as String}) {
      pages[name] = await ImageCodec.readFile(pagePath(name));
    }
  });

  final byPage = <String, List<(int, Map<String, Object?>)>>{};
  for (final (i, c) in cases.indexed) {
    byPage.putIfAbsent(c['page'] as String, () => []).add((i, c));
  }

  for (final MapEntry(key: page, value: pageCases) in byPage.entries) {
    test('$page (${pageCases.length} crops)', () {
      final failures = <String>[];
      for (final (i, c) in pageCases) {
        final box = (c['box'] as List).cast<int>();
        var crop = pages[page]!.crop(BBox(box[0], box[1], box[2], box[3]));
        crop = switch (c['transform']) {
          'rot90' => rot90(crop),
          'invert' => invert(crop),
          _ => crop,
        };
        final label = '#$i $box ${c['transform']} lang="${c['lang']}"';
        try {
          final (lines, direction) = detectLinesAndDirectionInCrop(crop, c['lang'] as String);
          // The original fails on these crops (IndexError where a line box
          // ends at the crop's edge); ours sums like a slice and goes on.
          if (c.containsKey('error')) continue;
          final expected = [for (final l in c['lines'] as List) HLine.fromJson(l)];
          if (direction != c['direction'] || !_sameLines(lines, expected)) {
            failures.add('$label:\n  expected ${c['direction']} $expected\n  actual   $direction $lines');
          }
        } on RangeError catch (e) {
          failures.add('$label: unexpected $e');
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  }
}

bool _sameLines(List<HLine> a, List<HLine> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
