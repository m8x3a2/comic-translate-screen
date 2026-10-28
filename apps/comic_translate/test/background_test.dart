// The image work of state/background.dart really runs in another isolate.

import 'dart:io';
import 'dart:typed_data';

import 'package:comic_translate/pipeline/psd_page.dart';
import 'package:comic_translate/state/background.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('cts_фон пробел_'));
  tearDown(() => dir.deleteSync(recursive: true));

  RgbImage picture() {
    final data = Uint8List(4 * 3 * 3);
    for (var i = 0; i < data.length; i++) {
      data[i] = i * 7 % 256;
    }
    return RgbImage(4, 3, data);
  }

  test('a PNG written and read back, as colour, gray and with transparency', () async {
    final file = p.join(dir.path, 'страница 1.png');
    final image = picture();
    await writePngInBackground(file, image);
    final back = await readImageInBackground(file);
    expect((back.width, back.height), (4, 3));
    expect(back.data, image.data);
    final gray = await readGrayInBackground(file);
    expect((gray.width, gray.height), (4, 3));
    final (rgb, alpha) = await readRgbaInBackground(file);
    expect(rgb.data, image.data);
    expect(alpha.data, everyElement(255));
  });

  test('a Photoshop file written in the background opens again', () async {
    final image = picture();
    final doc = await buildPagePsd(image, image, const [], AppSettings(), targetLanguage: 'Russian');
    final file = p.join(dir.path, 'страница 1.psd');
    await writePsdInBackground(file, doc);
    expect(readPagePsd(decodePsd(File(file).readAsBytesSync())).original.data, image.data);
  });
}
