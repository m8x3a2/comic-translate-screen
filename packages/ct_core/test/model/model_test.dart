import 'dart:convert';

import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

void main() {
  group('BBox', () {
    test('geometry helpers', () {
      const a = BBox(0, 0, 10, 10);
      const b = BBox(5, 5, 15, 15);
      expect(a.area, 100);
      expect(a.intersection(b), const BBox(5, 5, 10, 10));
      expect(a.union(b), const BBox(0, 0, 15, 15));
      expect(a.iou(b), closeTo(25 / 175, 1e-9));
      expect(a.intersection(const BBox(20, 20, 30, 30)), isNull);
      expect(const BBox(-5, 3, 50, 8).clampTo(20, 10), const BBox(0, 3, 20, 8));
      expect(BBox.fromList([1.9, 2.1, 3.7, 4.2]), const BBox(1, 2, 3, 4));
      expect(a.xywh, [0, 0, 10, 10]);
    });
  });

  group('TextLine', () {
    test('box and polygon JSON shapes match the original', () {
      final box = TextLine.fromJson([1, 2, 3, 4]);
      expect(box.isPolygon, isFalse);
      expect(box.toJson(), [1, 2, 3, 4]);

      final poly = TextLine.fromJson([
        [0, 0],
        [10, 1],
        [10.5, 5],
        [0, 4],
      ]);
      expect(poly.isPolygon, isTrue);
      expect(poly.axisBox, const BBox(0, 0, 11, 5));
      expect(jsonEncode(poly.toJson()), '[[0,0],[10,1],[10.5,5],[0,4]]');
    });
  });

  group('TextBlock', () {
    test('JSON round trip keeps all fields', () {
      final block = TextBlock(
        xyxy: const BBox(10, 20, 110, 80),
        bubbleXyxy: const BBox(0, 0, 200, 150),
        textClass: TextClass.bubble,
        lines: [const TextLine.box(BBox(12, 22, 100, 40))],
        angle: 2.5,
        text: 'HELLO',
        translation: 'ПРИВЕТ',
        sourceLang: 'en',
        targetLang: 'ru',
        fontColor: [0, 0, 0],
        direction: TextDirection.horizontal,
      );
      final restored = TextBlock.fromJson(jsonDecode(jsonEncode(block.toJson())) as Map<String, Object?>);
      expect(restored.toJson(), block.toJson());
      expect(restored.textClass, TextClass.bubble);
      expect(restored.lines.single.axisBox, const BBox(12, 22, 100, 40));
    });

    test('texts join into text, copy is deep', () {
      final block = TextBlock(xyxy: const BBox(0, 0, 1, 1), texts: ['A', 'B']);
      expect(block.text, 'A B');
      final copy = block.copy()..texts.add('C');
      expect(block.texts, ['A', 'B']);
      expect(copy.text, 'A B');
    });

    test('parseColor accepts lists and hex', () {
      expect(TextBlock.parseColor([255.0, 128, 0, 255]), [255, 128, 0]);
      expect(TextBlock.parseColor('#10ff20'), [16, 255, 32]);
      expect(TextBlock.parseColor(''), isNull);
      expect(TextBlock.parseColor([]), isNull);
    });

    test('original class ids', () {
      expect(TextClass.parse('text_free'), TextClass.free);
      expect(TextClass.bubble.id, 'text_bubble');
      expect(TextBlock(xyxy: const BBox(0, 0, 1, 1), direction: TextDirection.vertical).sourceLangDirection, 'ver_rtl');
    });
  });

  group('Languages', () {
    test('codes and rendering traits follow the original', () {
      expect(Languages.codeOf('Simplified Chinese'), 'zh-CN');
      expect(Languages.codeOf('Brazilian Portuguese'), 'pt-br');
      expect(Languages.isNoSpaceCode('ja'), isTrue);
      expect(Languages.isNoSpaceCode('zh-TW'), isTrue);
      expect(Languages.isNoSpaceCode('th'), isTrue);
      expect(Languages.isNoSpaceCode('en'), isFalse);
      expect(Languages.isVerticalCode('zh-CN'), isTrue);
      expect(Languages.isVerticalCode('zh'), isFalse);
      expect(Languages.isRtlName('Persian'), isTrue);
      expect(Languages.sources.map((l) => l.name),
          ['English', 'Korean', 'Japanese', 'French', 'Chinese', 'Russian', 'German', 'Dutch', 'Spanish', 'Italian']);
      expect(Languages.targets.length, 27);
    });
  });

  group('a box changed by hand', () {
    TextBlock detected() => TextBlock(
          xyxy: const BBox(100, 100, 160, 140),
          bubbleXyxy: const BBox(90, 90, 170, 150),
          lines: [
            const TextLine.box(BBox(102, 102, 158, 118)),
            TextLine.polygon(const [Point2(104, 122), Point2(156, 122), Point2(156, 138), Point2(104, 138)]),
          ],
        );

    test('moved: lines and bubble go along', () {
      final b = detected()..moveBoxTo(const BBox(300, 50, 360, 90));
      expect(b.xyxy, const BBox(300, 50, 360, 90));
      expect(b.bubbleXyxy, const BBox(290, 40, 370, 100));
      expect(b.lines.first.box, const BBox(302, 52, 358, 68));
      expect(b.lines.last.polygon!.first, const Point2(304, 72));
    });

    test('resized: lines are dropped, the bubble stays only around it', () {
      final inside = detected()..moveBoxTo(const BBox(95, 95, 165, 145));
      expect(inside.lines, isEmpty);
      expect(inside.bubbleXyxy, const BBox(90, 90, 170, 150));
      final out = detected()..moveBoxTo(const BBox(80, 100, 160, 140));
      expect(out.bubbleXyxy, isNull);
    });
  });
}
