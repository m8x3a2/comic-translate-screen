import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

const _w = 200, _h = 80;

/// A page of [background] with a line of "letters" (x 40..160, y 30..50,
/// bars 6 px wide every 10 px) already redrawn by a network: [redrawn] gives
/// the colour it left at each letter pixel.
(RgbImage, GrayImage) _cleaned(
  (int, int, int) Function(int x, int y) background,
  (int, int, int) Function(int x, int y) redrawn,
) {
  final data = Uint8List(_w * _h * 3);
  final mask = GrayImage.zeros(_w, _h);
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      final letter = x >= 40 && x < 160 && y >= 30 && y < 50 && (x - 40) % 10 < 6;
      if (letter) mask.data[y * _w + x] = 255;
      final (r, g, b) = letter ? redrawn(x, y) : background(x, y);
      data.setAll((y * _w + x) * 3, [r, g, b]);
    }
  }
  return (RgbImage(_w, _h, data), mask);
}

(int, int, int) _at(RgbImage image, int x, int y) {
  final o = image.offset(x, y);
  return (image.data[o], image.data[o + 1], image.data[o + 2]);
}

void main() {
  test('faint ghosts of letters on white paper become white', () {
    final (image, mask) = _cleaned(
      (_, _) => (255, 255, 255),
      (x, y) => (x + y).isEven ? (254, 253, 254) : (255, 254, 252),
    );
    final changed = snapToFlatBackground(image, mask);
    expect(changed, greaterThan(0));
    expect(image.data.every((v) => v == 255), isTrue);
  });

  test('a flat coloured background is matched exactly', () {
    final (image, mask) = _cleaned((_, _) => (200, 120, 60), (_, _) => (198, 121, 62));
    snapToFlatBackground(image, mask);
    expect(_at(image, 45, 40), (200, 120, 60));
  });

  test('drawing the network brought back stays', () {
    // A dark line through the letters, as the network continued it.
    final (image, mask) = _cleaned(
      (_, y) => y == 40 ? (30, 30, 30) : (255, 255, 255),
      (_, y) => y == 40 ? (35, 35, 35) : (254, 254, 254),
    );
    snapToFlatBackground(image, mask);
    expect(_at(image, 45, 40), (35, 35, 35));
    expect(_at(image, 45, 35), (255, 255, 255));
  });

  test('values further than the tolerance stay', () {
    final (image, mask) = _cleaned((_, _) => (255, 255, 255), (_, _) => (250, 250, 250));
    expect(snapToFlatBackground(image, mask), 0);
    expect(_at(image, 45, 40), (250, 250, 250));
  });

  test('a busy background is left alone', () {
    final (image, mask) = _cleaned((x, y) {
      final v = (x * 37 + y * 91) % 120 + 100;
      return (v, v, v);
    }, (_, _) => (160, 160, 160));
    final before = Uint8List.fromList(image.data);
    expect(snapToFlatBackground(image, mask), 0);
    expect(image.data, before);
  });

  test('pixels outside the mask never change', () {
    final (image, mask) = _cleaned((x, _) => x.isEven ? (255, 255, 255) : (253, 253, 253), (_, _) => (254, 254, 254));
    final before = Uint8List.fromList(image.data);
    snapToFlatBackground(image, mask);
    for (var i = 0; i < _w * _h; i++) {
      if (mask.data[i] == 0) expect(image.data.sublist(i * 3, i * 3 + 3), before.sublist(i * 3, i * 3 + 3));
    }
  });

  test('an empty mask changes nothing', () {
    final (image, _) = _cleaned((_, _) => (255, 255, 255), (_, _) => (254, 254, 254));
    expect(snapToFlatBackground(image, GrayImage.zeros(_w, _h)), 0);
  });
}
