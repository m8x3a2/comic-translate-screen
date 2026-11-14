// The drawing tool: its modes, colours and the colour codes.

import 'package:comic_translate/state/editor.dart';
import 'package:comic_translate/ui/shell_full/draw_options.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('colour codes', () {
    expect(colourCode(0xFF0A0B0C), '#0A0B0C');
    expect(parseColourCode('#ffffff'), 0xFFFFFFFF);
    expect(parseColourCode('123456'), 0xFF123456);
    expect(parseColourCode('#abc'), 0xFFAABBCC);
    expect(parseColourCode('#12345'), isNull);
    expect(parseColourCode('xyz'), isNull);
  });

  test('the pipette button picks one colour and goes back to the mode before it', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final editor = c.read(editorProvider.notifier);
    editor.setDrawMode(DrawMode.fill);
    expect(c.read(editorProvider).tool, EditorTool.draw);
    expect(c.read(editorProvider).view, ViewMode.result);
    editor.setDrawMode(DrawMode.pipette);
    editor.endPipette();
    expect(c.read(editorProvider).drawMode, DrawMode.fill);
  });

  test('chosen colours are kept as recent ones, newest first, without repeats', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final editor = c.read(editorProvider.notifier);
    for (final colour in [0xFF000001, 0xFF000002, 0xFF000001]) {
      editor.setPaintColor(colour);
    }
    expect(c.read(editorProvider).paintColor, 0xFF000001);
    expect(c.read(editorProvider).recentColors, [0xFF000001, 0xFF000002]);
    for (var i = 0; i < 20; i++) {
      editor.setPaintColor(0xFF100000 + i);
    }
    expect(c.read(editorProvider).recentColors, hasLength(maxRecentColors));
  });

  test('the brush keys change the brush in use; a tool leaves "As it will be"', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final editor = c.read(editorProvider.notifier);
    editor.setTool(EditorTool.draw);
    editor.setCurrentBrushSize(40);
    expect(c.read(editorProvider).paintSize, 40);
    expect(c.read(editorProvider).brushSize, 25);
    editor.togglePreview();
    expect(c.read(editorProvider).preview, isTrue);
    editor.setTool(EditorTool.boxes);
    expect(c.read(editorProvider).preview, isFalse);
  });
}
