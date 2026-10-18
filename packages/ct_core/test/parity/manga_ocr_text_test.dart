// Parity of manga-ocr's text post-processing (jaconv.h2z, dot runs,
// pathological-output filters) with the original.

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

import 'reference.dart';

void main() {
  final cases = (loadReference('manga_ocr.json')['postprocess'] as List).cast<Map>();
  test('postprocess matches the original on ${cases.length} strings', () {
    for (final c in cases) {
      expect(MangaOcrText.postprocess(c['in'] as String), c['out'], reason: 'input ${c['in']}');
    }
  });

  test('Python splitlines semantics', () {
    expect(pySplitLines('a\r\nb\rc\nd\x85e f\n'), ['a', 'b', 'c', 'd', 'e', 'f']);
    expect(pySplitLines('a\n\nb'), ['a', '', 'b']);
  });
}
