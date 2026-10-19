// A wide outline is one solid band around the letters, not shifted copies.

import 'dart:math' as math;

import 'package:comic_translate/render/text_renderer.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a wide outline leaves no gaps next to the letters', () async {
    const w = 6.0;
    final engines = await TextEngines.load(
      const RenderSettings(outline: true, outlineColor: 0xFFFF0000, outlineWidth: w),
    );
    final item = TextItem(
      text: 'ЭТО бизнес',
      fontSizePt: 30,
      x: 20,
      y: 20,
      width: 360,
      height: 80,
      color: 0xFF000000,
      vertical: false,
      block: TextBlock(xyxy: const BBox(20, 20, 380, 100)),
    );
    final page = await renderTextOnPage(RgbImage.filled(400, 120, 255, 255, 255), [item], engines);
    (int, int, int) px(int x, int y) {
      final i = (y * page.width + x) * 3;
      return (page.data[i], page.data[i + 1], page.data[i + 2]);
    }

    bool dark(int x, int y) => px(x, y).$1 < 60 && px(x, y).$2 < 60;
    bool white(int x, int y) => px(x, y).$1 > 200 && px(x, y).$2 > 200 && px(x, y).$3 > 200;
    var letters = 0, gaps = 0;
    for (var y = 4; y < page.height - 4; y++) {
      for (var x = 4; x < page.width - 4; x++) {
        if (dark(x, y)) letters++;
        if (!white(x, y)) continue;
        // White closer to a letter than the outline reaches is a gap.
        near:
        for (var dy = -4; dy <= 4; dy++) {
          for (var dx = -4; dx <= 4; dx++) {
            if (math.sqrt(dx * dx + dy * dy) <= 4 && dark(x + dx, y + dy)) {
              gaps++;
              break near;
            }
          }
        }
      }
    }
    expect(letters, greaterThan(300), reason: 'the text is drawn');
    expect(gaps, 0);
  });
}
