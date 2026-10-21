// Parity of script identification ("Auto" source language) with the original
// comic-translate, without the model: which line of each detected block is
// read, how it is prepared for the OSD model, and the helpers that route
// blocks by script. Reference: tools/reference/gen_reference.py (script).
// The model itself: packages/ct_providers/test/script_id_parity_test.dart.

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

import 'reference.dart';

RgbImage invert(RgbImage src) =>
    RgbImage(src.width, src.height, Uint8List.fromList([for (final v in src.data) 255 - v]));

/// The detected blocks of [page], as the original's script step sees them.
List<TextBlock> referenceBlocks(String page, {required bool lines}) => [
  for (final b in (loadReference('detection/$page.json')['blocks'] as List).cast<Map<String, Object?>>())
    TextBlock.fromJson(b)
      ..sourceLang = ''
      ..lines = lines ? TextBlock.fromJson(b).lines : []
      ..direction = lines ? TextBlock.fromJson(b).direction : TextDirection.unknown,
];

void main() {
  final ref = loadReference('script.json');
  final pages = (ref['pages'] as List).cast<Map<String, Object?>>();

  for (final page in pages) {
    final name = page['page'] as String;
    final variants = (page['variants'] as Map).cast<String, Map<String, Object?>>();
    for (final MapEntry(key: variant, value: expected) in variants.entries) {
      test('$name $variant: line crops and model inputs', () async {
        var image = await ImageCodec.readFile(pagePath(name));
        if (variant == 'inverted') image = invert(image);
        final blocks = referenceBlocks(name, lines: variant != 'no_lines');
        final entries = (expected['blocks'] as List).cast<Map<String, Object?>>();
        expect(blocks.length, entries.length);
        for (final (i, b) in blocks.indexed) {
          final e = entries[i];
          final found = largestLineCrop(image, b);
          if (e['crop'] == null) {
            expect(found, isNull, reason: 'block $i');
            continue;
          }
          final (crop, direction) = found!;
          expect([crop.height, crop.width], e['crop'], reason: 'block $i crop');
          expect(direction, e['direction'], reason: 'block $i direction');
          final input = scriptInputForBlock(image, b);
          if (e['input_width'] == null || (e['input_width'] as int) < 3) {
            expect(input, isNull, reason: 'block $i input');
            continue;
          }
          expect(input!.width, e['input_width'], reason: 'block $i input width');
          final bytes = input.data.buffer.asUint8List(input.data.offsetInBytes, input.data.lengthInBytes);
          expect(sha256.convert(bytes).toString(), e['input_sha256'], reason: 'block $i input values');
        }
      });

      test('$name $variant: page language from the block scripts', () {
        final blocks = referenceBlocks(name, lines: true);
        final entries = (expected['blocks'] as List).cast<Map<String, Object?>>();
        for (final (i, b) in blocks.indexed) {
          b.script = entries[i]['script'] as String;
        }
        expect(dominantPageScript(blocks), expected['dominant']);
        expect(dominantPageScript(blocks, threshold: 0.0), expected['dominant_any']);
        expect(resolveAutoSourceLanguage(blocks, Languages.auto), expected['resolved']);
        expect(resolveAutoSourceLanguage(blocks, 'English'), 'English');
      });
    }
  }

  test('script helpers for every label', () {
    for (final h in (ref['helpers'] as List).cast<Map<String, Object?>>()) {
      final label = h['label'] as String;
      expect(normalizeScript(label), h['normalized'], reason: label);
      expect(isSupportedScript(label), h['supported'], reason: label);
      expect(ocrBucketForScript(label), h['bucket'], reason: label);
      expect(languageCodeForScript(label), h['code'], reason: label);
      expect(sourceLanguageForScript(label), h['source'], reason: label);
    }
  });

  test('dominant page script on random pages', () {
    for (final (i, c) in (ref['dominant'] as List).cast<Map<String, Object?>>().indexed) {
      final blocks = [
        for (final b in (c['blocks'] as List).cast<Map<String, Object?>>())
          TextBlock(xyxy: BBox.fromJson(b['xyxy']), script: b['script'] as String),
      ];
      expect(dominantPageScript(blocks), c['dominant'], reason: 'case $i');
      expect(dominantPageScript(blocks, threshold: 0.0), c['dominant_any'], reason: 'case $i');
      expect(resolveAutoSourceLanguage(blocks, Languages.auto), c['resolved'], reason: 'case $i');
    }
  });

  test('OCR groups: own script, else the page script', () {
    TextBlock block(String script, int width) => TextBlock(xyxy: BBox(0, 0, width, 10), script: script);
    final blocks = [block('Japanese_vert', 100), block('', 10), block('Latin', 10), block('Greek', 5)];
    final groups = autoOcrGroups(blocks);
    expect(groups.keys, ['japanese', 'latin']);
    expect(groups['japanese'], [blocks[0], blocks[1], blocks[3]]);
    expect([for (final b in blocks) b.sourceLang], ['ja', 'ja', 'en', 'ja']);

    // A mixed page: blocks without a supported script go to Chinese, as in the original.
    final mixed = [block('Latin', 10), block('Hangul', 10), block('', 10)];
    expect(autoOcrGroups(mixed).keys, ['latin', 'korean', 'chinese']);
    expect(mixed[2].sourceLang, 'zh');
  });
}
