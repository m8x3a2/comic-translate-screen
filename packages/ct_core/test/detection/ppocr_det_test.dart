import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

void main() {
  test('lines of one paragraph make one block, others their own', () {
    final blocks = groupLinesIntoBlocks(const [
      // A paragraph of three lines, left aligned.
      BBox(100, 100, 700, 130),
      BBox(100, 140, 650, 170),
      BBox(100, 180, 400, 210),
      // A name label far above.
      BBox(100, 20, 200, 50),
      // A menu row at the bottom, far from the rest.
      BBox(300, 600, 360, 620),
      BBox(380, 600, 440, 620),
    ]);
    expect([for (final b in blocks) b.lines.length], [1, 3, 1, 1]);
    final paragraph = blocks[1];
    expect(paragraph.xyxy, const BBox(100, 100, 700, 210));
    expect(paragraph.textClass, TextClass.free);
    expect(paragraph.fixedLines, isTrue);
    expect([for (final l in paragraph.lines) l.box!.y1], [100, 140, 180]);
  });

  test('centred lines and lines of other sizes', () {
    final centred = groupLinesIntoBlocks(const [BBox(200, 100, 600, 130), BBox(300, 135, 500, 165)]);
    expect(centred, hasLength(1));
    final title = groupLinesIntoBlocks(const [BBox(100, 100, 600, 180), BBox(100, 190, 600, 215)]);
    expect(title, hasLength(2), reason: 'a big title over small text');
  });

  test('pieces of one line are merged', () {
    final merged = mergeLineBoxes(const [BBox(10, 10, 100, 30), BBox(110, 11, 200, 31)], 1000, 1000);
    expect(merged, [const BBox(10, 10, 200, 31)]);
  });

  test('minimum-area rectangle and polygon fill', () {
    final r = minAreaRect(const [Point2(0, 0), Point2(10, 0), Point2(10, 4), Point2(0, 4)]);
    expect((r.cx, r.cy, r.width, r.height, r.angle), (5.0, 2.0, 4.0, 10.0, 90.0));
    final (box, side) = minBox(const [Point2(0, 0), Point2(10, 0), Point2(10, 4), Point2(0, 4)]);
    expect([for (final p in box) (p.x.round(), p.y.round())], [(0, 0), (10, 0), (10, 4), (0, 4)]);
    expect(side, 4);
    // Same as mahotas: both ends of every scan line, the bottom vertex too.
    final mask = Uint8List(9);
    fillPolygon(mask, 3, 3, const [(2, 0), (0, 2), (2, 1), (1, 0)]);
    expect(mask, [0, 0, 0, 0, 1, 1, 1, 0, 0]);
  });

  test('lines of a line detector are kept when the page is enlarged for reading', () {
    final image = RgbImage.filled(200, 100, 255, 255, 255);
    final block = TextBlock(xyxy: const BBox(10, 10, 190, 20), lines: [TextLine.box(const BBox(10, 10, 190, 20))])
      ..fixedLines = true;
    final reading = prepareReading(image, [block]);
    expect(reading.scaled, isTrue);
    expect(
      block.lines.single.box,
      scaleLine(TextLine.box(const BBox(10, 10, 190, 20)), reading.scaleX, reading.scaleY).box,
    );
    reading.restore();
    expect(block.lines.single.box, const BBox(10, 10, 190, 20));
    expect(block.linePx, 11);
    expect(TextBlock.fromJson(block.toJson()).fixedLines, isTrue);
    block.moveBoxTo(const BBox(10, 10, 100, 40));
    expect(block.fixedLines, isFalse, reason: 'a resized box finds its lines again');
  });

  test('the kind of pages picks the detector', () {
    final s = AppSettings();
    expect(s.activeDetector, 'rtdetr_v2');
    s.contentKind = ContentKind.screens;
    expect(s.activeDetector, 'ppocr_lines');
    final back = AppSettings.fromJson(s.toJson());
    expect(back.contentKind, ContentKind.screens);
    expect(back.screenDetector, 'ppocr_lines');
  });
}
