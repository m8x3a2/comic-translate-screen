import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

RgbImage filled(int w, int h, int v) => RgbImage.filled(w, h, v, v, v);

TextBlock block(int x1, int y1, int x2, int y2) => TextBlock(xyxy: BBox(x1, y1, x2, y2));

void main() {
  test('the page below is centred under a wider page, white around it', () {
    final page = filled(10, 4, 0);
    final next = RgbImage(
      6,
      3,
      Uint8List.fromList([
        for (var i = 0; i < 6 * 3; i++) ...[i, i, i],
      ]),
    );
    final out = extendBelow(page, next, 2);
    expect((out.width, out.height), (10, 6));
    int at(int x, int y) => out.data[(y * 10 + x) * 3];
    expect(at(5, 3), 0, reason: 'the page itself');
    expect(at(1, 4), 255, reason: 'left of the narrower page');
    expect(at(2, 4), 0, reason: 'first pixel of the page below');
    expect(at(7, 5), 6 + 5);
    expect(at(8, 5), 255);
    // A wider page below is cut to the page's width.
    final wide = extendBelow(
      filled(4, 2, 0),
      RgbImage(
        8,
        1,
        Uint8List.fromList([
          for (var i = 0; i < 8; i++) ...[i, i, i],
        ]),
      ),
      5,
    );
    expect((wide.width, wide.height), (4, 3));
    expect([for (var x = 0; x < 4; x++) wide.data[(2 * 4 + x) * 3]], [2, 3, 4, 5]);
  });

  test('blocks that start below the edge are left to the next page', () {
    final found = [block(0, 10, 50, 90), block(0, 80, 50, 140), block(0, 101, 50, 160)];
    expect(ownBlocks(found, 100).map((b) => b.xyxy.y1), [10, 80]);
    expect(overflowOf(found, 100), 60);
    expect(overflowOf(ownBlocks(found, 100), 100), 40);
    expect(seamRows(ownBlocks(found, 100), 100, 500), 40 + seamPad);
    expect(seamRows(ownBlocks(found, 100), 100, 60), 60, reason: 'no more than the next page');
    expect(seamRows([block(0, 0, 10, 100)], 100, 500), 0);
  });

  test('the next page drops what continues a bubble of the page above', () {
    final upper = [block(20, 80, 60, 140), block(0, 0, 10, 10)];
    final covered = reachInto(upper, 100, 100, 80);
    // 10 px to the left: the page below is 20 px narrower and centred.
    expect(covered.map((b) => b.toList()), [
      [10, -20, 50, 40],
    ]);
    final lower = [block(12, 0, 48, 38), block(10, 30, 50, 90), block(200, 0, 220, 20)];
    expect(withoutCovered(lower, covered).map((b) => b.xyxy.y1), [30, 0]);
  });

  test('cleaning below the edge becomes a patch drawn over the next page', () {
    final cleaned = filled(4, 6, 9);
    final mask = GrayImage.zeros(4, 6)..data[5 * 4 + 1] = 255;
    final (page, patch) = splitBelow(cleaned, mask, 4);
    expect((page.width, page.height), (4, 4));
    expect(patch, isNotNull);
    expect((patch!.image.height, patch.alpha.countNonZero()), (2, 1));

    final lower = filled(2, 3, 200);
    final out = applyPatch(lower, patch, 4);
    // Column 1 of the upper page is column 0 of the 2 px wide page below.
    expect([for (var i = 0; i < 6; i++) out.data[i * 3]], [200, 200, 9, 200, 200, 200]);

    final (_, none) = splitBelow(cleaned, GrayImage.zeros(4, 6), 4);
    expect(none, isNull, reason: 'nothing cleaned below the edge');
    expect(splitBelow(filled(4, 4, 1), GrayImage.zeros(4, 4), 4).$2, isNull);
  });

  test('a patch keeps its transparency in a PNG', () {
    final image = RgbImage(2, 1, Uint8List.fromList([1, 2, 3, 4, 5, 6]));
    final alpha = GrayImage(2, 1, Uint8List.fromList([0, 255]));
    final (rgb, a) = ImageCodec.decodeRgba(ImageCodec.encodeRgbaPng(image, alpha));
    expect(rgb.data, [1, 2, 3, 4, 5, 6]);
    expect(a.data, [0, 255]);
    final (_, opaque) = ImageCodec.decodeRgba(ImageCodec.encodePng(image));
    expect(opaque.data, [255, 255]);
  });

  test('text areas may reach below the page when allowed', () {
    final b = [block(0, 80, 100, 160)..translation = 'x'];
    expect(textAreaOf(b, 0, 100, 100).y2, 100);
    expect(textAreaOf(b, 0, 100, 200).y2, greaterThan(150));
  });
}
