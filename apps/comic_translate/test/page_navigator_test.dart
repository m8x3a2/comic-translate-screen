// The mini view: a click in it centres the view on that point; a long strip
// gets the bar of its whole length.

import 'package:comic_translate/ui/shell_full/page_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<List<Offset>> clicks(WidgetTester tester, Size scene, List<Offset> at, {double maxHeight = 260}) async {
    final jumps = <Offset>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: PageNavigator(
            pictures: [(path: 'missing.png', rect: Offset.zero & scene)],
            scene: scene,
            transform: TransformationController(),
            viewport: const Size(800, 600),
            onJump: jumps.add,
            maxHeight: maxHeight,
          ),
        ),
      ),
    );
    final box = tester.getTopLeft(find.byType(Card)) + const Offset(4, 4);
    for (final p in at) {
      await tester.tapAt(box + p);
      await tester.pump();
    }
    return jumps;
  }

  testWidgets('a page: the point clicked, in page pixels', (tester) async {
    // 160 wide for 1600 pixels: one mini pixel is ten page pixels.
    final jumps = await clicks(tester, const Size(1600, 2000), [const Offset(80, 100)]);
    expect(jumps.single.dx, closeTo(800, 1));
    expect(jumps.single.dy, closeTo(1000, 1));
    final bar = find.byWidgetPredicate((w) => w is CustomPaint && '${w.painter.runtimeType}' == '_WholeStrip');
    expect(bar, findsNothing, reason: 'no bar: the page fits');
  });

  testWidgets('a long strip: the bar jumps along its whole length', (tester) async {
    // 160 wide for 800 pixels: the strip is 20 000 mini pixels high, the view 200.
    final jumps = await clicks(tester, const Size(800, 100000), [const Offset(160 + 7, 100)], maxHeight: 200);
    expect(jumps.single.dy, closeTo(50000, 600), reason: 'the middle of the bar is the middle of the strip');
  });
}
