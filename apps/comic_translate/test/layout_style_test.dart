// A bubble's own style must not change how the other bubbles are drawn.

import 'package:comic_translate/pipeline/page_pipeline.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a styled bubble that does not fit does not enlarge the page', () async {
    final settings = AppSettings();
    TextBlock block(int x, String text, {BlockStyle? style}) =>
        TextBlock(xyxy: BBox(x, 20, x + 85, 90), text: 'Hi', translation: text, style: style);
    final normal = [block(10, 'Привет'), block(100, 'Да'), block(190, 'Нет'), block(280, 'Ну')];
    final engines = await loadTextEngines(settings, 'Russian', normal);
    RenderLayout layout(List<TextBlock> blocks) =>
        layoutRender(400, 300, blocks, settings, engines, targetLanguage: 'Russian');
    expect(layout(normal).scale, 1);

    // Widely spaced lines in one bubble: its text may overflow, the page stays.
    final spaced = [
      ...normal.take(3),
      block(280, 'Очень длинная реплика в маленьком пузыре', style: const BlockStyle(lineSpacing: 2.5, fontSizePt: 30)),
    ];
    final r = layout(spaced);
    expect(r.scale, 1, reason: 'enlarging would resize every other bubble');
    expect(r.items.first.width, layout(normal).items.first.width);
  });
}
