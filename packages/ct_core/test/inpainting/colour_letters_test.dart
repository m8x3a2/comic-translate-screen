import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:ct_core/src/inpainting/colour_letters.dart';
import 'package:test/test.dart';

const _w = 200, _h = 100;
const _box = BBox(10, 30, 190, 66);

bool _glyph(int x, int y) => y >= 40 && y < 56 && x >= 20 && x < 186 && (x - 20) % 16 < 6;

bool _hatch(int x, int y) => x >= 100 && x % 3 == 0;

/// Letters of [ink] on white; the right half is hatched with black lines,
/// letters drawn over them. [aroundInk] paints a stripe just below the box.
RgbImage _page(List<int> ink, {List<int>? aroundInk}) {
  final data = Uint8List(_w * _h * 3)..fillRange(0, _w * _h * 3, 255);
  void put(int x, int y, List<int> c) => data.setRange((y * _w + x) * 3, (y * _w + x) * 3 + 3, c);
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < _w; x++) {
      if (_hatch(x, y)) put(x, y, const [0, 0, 0]);
      if (_glyph(x, y)) put(x, y, ink);
      if (aroundInk != null && y >= 70 && y < 90) put(x, y, aroundInk);
    }
  }
  return RgbImage(_w, _h, data);
}

/// What a text masker finds: the letters on plain background only.
GrayImage _found() {
  final out = GrayImage.zeros(_w, _h);
  for (var y = 0; y < _h; y++) {
    for (var x = 0; x < 100; x++) {
      if (_glyph(x, y)) out.data[y * _w + x] = 255;
    }
  }
  return out;
}

int _at(GrayImage boxMask, int x, int y) => boxMask.data[(y - _box.y1) * boxMask.width + x - _box.x1];

void main() {
  const red = [220, 40, 40];

  test('coloured letters are followed over the hatching, the hatching is not', () {
    final c = colourLetters(_page(red), _found(), _box)!;
    for (var y = _box.y1; y < _box.y2; y++) {
      for (var x = _box.x1; x < _box.x2; x++) {
        expect(_at(c, x, y), _glyph(x, y) ? 255 : 0, reason: '($x, $y)');
      }
    }
  });

  test('black letters are not searched by colour', () {
    expect(colourLetters(_page(const [0, 0, 0]), _found(), _box), isNull);
  });

  test('a drawing of the same colour around the text turns it off', () {
    expect(colourLetters(_page(red, aroundInk: const [200, 30, 50]), _found(), _box), isNull);
  });

  test('too few found letters turn it off', () {
    final few = GrayImage.zeros(_w, _h);
    for (var y = 40; y < 56; y++) {
      for (var x = 20; x < 26; x++) {
        few.data[y * _w + x] = 255;
      }
    }
    expect(colourLetters(_page(red), few, _box), isNull);
  });

  test('the mask hands the coloured letters over the hatching to the network', () {
    final image = _page(red);
    final block = TextBlock(xyxy: _box, lines: [TextLine.box(_box)], text: 'text');
    final mask = generateMask(image, [block], letters: _found());
    // A letter over the hatching (x 132..137) and a hatch line beside it.
    expect(mask.data[48 * _w + 134], 255);
    expect(mask.data[48 * _w + 135], 255);
    expect(mask.data[48 * _w + 141] == 255, isFalse);
  });

  test('turned off in the settings, the letters over the hatching stay out of the network', () {
    final block = TextBlock(xyxy: _box, lines: [TextLine.box(_box)], text: 'text');
    final mask = generateMask(_page(red), [block], letters: _found(), byColour: false);
    expect(mask.data[48 * _w + 134] == 255, isFalse);
    expect(mask.data[48 * _w + 54], 255, reason: 'a letter on white is still found by the masker');
  });
}
