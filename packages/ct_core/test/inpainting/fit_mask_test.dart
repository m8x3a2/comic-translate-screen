import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

const _w = 200, _h = 100;

/// Letters: bars 4 px wide, 12 px high, on [background] in two words.
bool _letter(int x, int y) => y >= 40 && y < 52 && ((x >= 20 && x < 60) || (x >= 120 && x < 160)) && (x - 20) % 10 < 4;

RgbImage _page({List<int> background = const [255, 255, 255], List<int> ink = const [0, 0, 0]}) {
  final data = Uint8List(_w * _h * 3);
  for (var i = 0; i < _w * _h; i++) {
    final x = i % _w, y = i ~/ _w;
    data.setRange(i * 3, i * 3 + 3, _letter(x, y) ? ink : background);
  }
  return RgbImage(_w, _h, data);
}

/// Two rough blobs of the brush around the two words, value [v].
GrayImage _rough({int v = 255}) {
  final m = GrayImage.zeros(_w, _h);
  for (var y = 25; y < 70; y++) {
    for (var x = 5; x < 75; x++) {
      m.data[y * _w + x] = v;
    }
    for (var x = 105; x < 175; x++) {
      m.data[y * _w + x] = v;
    }
  }
  return m;
}

int _count(GrayImage m, {int x1 = 0, int x2 = _w}) {
  var n = 0;
  for (var y = 0; y < _h; y++) {
    for (var x = x1; x < x2; x++) {
      if (m.data[y * _w + x] != 0) n++;
    }
  }
  return n;
}

/// Whether every letter pixel and nothing farther than [margin] from one is
/// in [m] (within x1…x2).
void _expectFitted(GrayImage m, int margin, {int x1 = 0, int x2 = _w}) {
  for (var y = 0; y < _h; y++) {
    for (var x = x1; x < x2; x++) {
      final v = m.data[y * _w + x];
      if (_letter(x, y)) expect(v, 255, reason: 'letter at $x,$y');
      var near = false;
      for (var dy = -margin; dy <= margin && !near; dy++) {
        for (var dx = -margin; dx <= margin && !near; dx++) {
          if (_letter(x + dx, y + dy)) near = true;
        }
      }
      if (!near) expect(v, 0, reason: 'far from letters at $x,$y');
    }
  }
}

void main() {
  test('a clicked piece shrinks to its letters by contrast; the other stays', () {
    final r = fitMaskToLetters(_page(), _rough(), [const Point2(10, 30)]);
    expect(r.fitted, 1);
    expect(r.empty, 0);
    _expectFitted(r.mask, fitMaskMargin, x2: 100);
    expect(_count(r.mask, x1: 100), 70 * 45, reason: 'the other piece is untouched');
  });

  test('no seeds: every piece; light letters on a dark background too', () {
    final r = fitMaskToLetters(
      _page(background: const [20, 20, 90], ink: const [250, 250, 250]),
      _rough(v: maskMarginValue),
      const [],
      margin: 2,
    );
    expect(r.fitted, 2);
    _expectFitted(r.mask, 2);
  });

  test("the masker's letters win when it found them", () {
    // The masker sees only the first two bars of the first word.
    final letters = GrayImage.zeros(_w, _h);
    for (var y = 0; y < _h; y++) {
      for (var x = 20; x < 34; x++) {
        if (_letter(x, y)) letters.data[y * _w + x] = 255;
      }
    }
    final r = fitMaskToLetters(_page(), _rough(), [const Point2(40, 60)], letters: letters, margin: 0);
    expect(r.fitted, 1);
    expect(_count(r.mask, x2: 100), 2 * 4 * 12);
  });

  test('a piece without letters is left as it was', () {
    final blank = RgbImage(_w, _h, Uint8List(_w * _h * 3)..fillRange(0, _w * _h * 3, 255));
    final mask = _rough();
    final r = fitMaskToLetters(blank, mask, [const Point2(10, 30), const Point2(500, 500), const Point2(1, 1)]);
    expect(r.fitted, 0);
    expect(r.empty, 1);
    expect(r.mask.data, mask.data);
  });

  test('rows of a webtoon mask below the image stay', () {
    final tall = GrayImage.zeros(_w, _h + 20);
    for (var y = 25; y < _h + 20; y++) {
      for (var x = 5; x < 75; x++) {
        tall.data[y * _w + x] = 255;
      }
    }
    final r = fitMaskToLetters(_page(), tall, [const Point2(10, 30)]);
    expect(r.mask.height, _h + 20);
    for (var y = _h; y < _h + 20; y++) {
      expect(r.mask.data[y * _w + 10], 255);
    }
    expect(r.mask.data[30 * _w + 10], 0);
  });
}
