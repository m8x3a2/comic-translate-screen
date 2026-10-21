import 'dart:io';
import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';
import 'package:ct_core/src/psd/packbits.dart';
import 'package:test/test.dart';

/// A page with a grey square, a patch over it and a text layer in groups.
PsdDocument sampleDocument({int width = 64, int height = 48}) {
  final page = RgbImage.filled(width, height, 255, 255, 255);
  for (var y = 10; y < 30; y++) {
    for (var x = 10; x < 40; x++) {
      page.data.fillRange((y * width + x) * 3, (y * width + x) * 3 + 3, 90);
    }
  }
  final textPixels = Uint8List(20 * 10 * 4);
  for (var i = 0; i < 20 * 10; i++) {
    textPixels[i * 4 + 3] = i.isEven ? 255 : 0;
  }
  return PsdDocument(
    width: width,
    height: height,
    composite: page,
    layers: [
      PsdGroup('Editable Text', [
        PsdLayer(
          'Text 1',
          pixels: PsdPixels(12, 14, 20, 10, textPixels),
          stroke: const PsdStroke(0xFFFFEE00, 3),
          text: const PsdText(
            text: 'ПРИВЕТ,\nмир (тест)',
            font: 'Pangolin-Regular',
            fontSize: 18,
            transform: [1, 0, 0, 1, 12, 14],
            boxWidth: 30,
            boxHeight: 24,
            color: 0xFF102030,
            strokeColor: 0xFFFFFFFF,
            strokeWidth: 4,
            leading: 22,
            underline: true,
          ),
        ),
      ]),
      PsdGroup('Inpaint Patches', [
        PsdLayer('Patch 1', pixels: PsdPixels.opaque(RgbImage.filled(8, 6, 255, 255, 255), left: 20, top: 20)),
      ]),
      PsdLayer('Raw Image', pixels: PsdPixels.opaque(page)),
    ],
  );
}

void main() {
  test('PackBits round trip', () {
    for (final src in [
      Uint8List(0),
      Uint8List.fromList([1]),
      Uint8List.fromList([1, 1]),
      Uint8List.fromList(List.filled(300, 7)),
      Uint8List.fromList([for (var i = 0; i < 300; i++) i * 7 % 256]),
      Uint8List.fromList([1, 2, 2, 3, 3, 3, 4, 4, 4, 4, 5, 6, 6]),
    ]) {
      final out = Uint8List(src.length + src.length ~/ 128 + 2);
      final n = packBits(src, 0, src.length, out, 0);
      final back = Uint8List(src.length);
      expect(unpackBits(out, 0, n, back, 0, src.length), src.length);
      expect(back, src);
    }
  });

  test('EngineData round trip', () {
    final data = serializeEngineData({
      'A': {
        'Text': 'a (b) \\ c\r',
        'N': 3,
        'F': 1.0,
        'H': .5,
        'L': [1.0, 0.0],
        'R': [3, 4],
        'B': true,
      },
      'S': [
        {'Name': 'x'},
        {'Name': 'y'},
      ],
    });
    final back = parseEngineData(data);
    expect(back, {
      'A': {
        'Text': 'a (b) \\ c\r',
        'N': 3,
        'F': 1.0,
        'H': .5,
        'L': [1.0, 0.0],
        'R': [3, 4],
        'B': true,
      },
      'S': [
        {'Name': 'x'},
        {'Name': 'y'},
      ],
    });
    expect(String.fromCharCodes(data), contains('/F 1.0'));
    expect(String.fromCharCodes(data), contains('/H .5'));
  });

  test('write and read back: layers, groups, text, the merged picture', () async {
    final doc = sampleDocument();
    final bytes = encodePsd(doc);
    final sample = Platform.environment['CTS_PSD_SAMPLE'];
    if (sample != null) await File(sample).writeAsBytes(bytes);

    final back = decodePsd(bytes);
    expect((back.width, back.height), (64, 48));
    expect(back.composite!.data, doc.composite!.data);
    expect([for (final n in back.layers) n.name], ['Editable Text', 'Inpaint Patches', 'Raw Image']);
    final flat = back.flatLayers().toList();
    expect(
      [for (final (l, path) in flat) '${path.join('/')}:${l.name}'],
      ['Editable Text:Text 1', 'Inpaint Patches:Patch 1', ':Raw Image'],
    );
    final (textLayer, _) = flat.first;
    final t = textLayer.text!;
    expect(t.text, 'ПРИВЕТ,\nмир (тест)');
    expect(t.font, 'Pangolin-Regular');
    expect(t.fontSize, 18);
    expect(t.color, 0xFF102030);
    expect(t.strokeColor, 0xFFFFFFFF);
    expect(t.strokeWidth, 4);
    expect(t.leading, 22);
    expect(t.underline, isTrue);
    expect((textLayer.stroke!.color, textLayer.stroke!.size), (0xFFFFEE00, 3));
    expect(t.justification, PsdJustification.center);
    expect(t.transform, [1, 0, 0, 1, 12, 14]);
    expect((t.boxWidth, t.boxHeight), (30, 24));
    expect(textLayer.pixels!.rgba, doc.flatLayers().first.$1.pixels!.rgba);
    final patch = flat[1].$1.pixels!;
    expect((patch.left, patch.top, patch.width, patch.height), (20, 20, 8, 6));
    expect(flat.last.$1.pixels!.rgba, PsdPixels.opaque(doc.composite!).rgba);
  });

  test('rotated and scaled text: page size and corner', () {
    // 30° and twice the size in the transform: the size is read in pixels.
    const c = 0.8660254037844387, s = 0.5;
    final doc = PsdDocument(
      width: 100,
      height: 100,
      layers: [
        PsdLayer(
          'T',
          text: const PsdText(
            text: 'x',
            font: 'ArialMT',
            fontSize: 10,
            transform: [2 * c, 2 * s, -2 * s, 2 * c, 40, 30],
            boxWidth: 20,
            boxHeight: 10,
          ),
        ),
      ],
    );
    final t = (decodePsd(encodePsd(doc)).layers.single as PsdLayer).text!;
    expect(t.fontSize, closeTo(20, 1e-9));
    expect(t.boxWidth, closeTo(40, 1e-9));
    expect(t.transform[0], closeTo(c, 1e-9));
    expect(t.transform[1], closeTo(s, 1e-9));
    expect(t.transform.sublist(4), [40, 30]);
  });

  test('pages taller than 30 000 px are written as PSB', () {
    final doc = PsdDocument(
      width: 4,
      height: 30001,
      composite: RgbImage.filled(4, 30001, 1, 2, 3),
      layers: [PsdLayer('L', pixels: PsdPixels.opaque(RgbImage.filled(4, 30001, 1, 2, 3)))],
    );
    final bytes = encodePsd(doc);
    expect(bytes[5], 2, reason: 'version 2 = PSB');
    final back = decodePsd(bytes);
    expect(back.composite!.data.sublist(0, 3), [1, 2, 3]);
    expect((back.layers.single as PsdLayer).pixels!.height, 30001);
  });
}
