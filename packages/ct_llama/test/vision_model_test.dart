// Reads a picture with a real vision-language model; skipped unless
// CT_LLAMA_MODEL, CT_LLAMA_MMPROJ and CT_LLAMA_IMAGE (a binary PPM) are set,
// with CT_LLAMA_EXPECT the reading llama-server gave.

import 'dart:io';
import 'dart:typed_data';

import 'package:ct_llama/ct_llama.dart';
import 'package:test/test.dart';

(Uint8List, int, int) _readPpm(String path) {
  final bytes = File(path).readAsBytesSync();
  final fields = <String>[];
  var i = 0;
  while (fields.length < 4) {
    while (bytes[i] == 0x20 || bytes[i] == 0x0a || bytes[i] == 0x0d || bytes[i] == 0x09) {
      i++;
    }
    final start = i;
    while (bytes[i] != 0x20 && bytes[i] != 0x0a && bytes[i] != 0x0d && bytes[i] != 0x09) {
      i++;
    }
    fields.add(String.fromCharCodes(bytes, start, i));
  }
  final w = int.parse(fields[1]), h = int.parse(fields[2]);
  return (Uint8List.sublistView(bytes, i + 1, i + 1 + w * h * 3), w, h);
}

void main() {
  final env = Platform.environment;
  final model = env['CT_LLAMA_MODEL'];
  final mmproj = env['CT_LLAMA_MMPROJ'];
  final image = env['CT_LLAMA_IMAGE'];
  test(
    'PaddleOCR-VL reads a speech bubble as llama-server does',
    () async {
      final errors = <String>[];
      VisionModel.onError = errors.add;
      final vlm = VisionModel.open(model!, mmproj!);
      final (rgb, w, h) = _readPpm(image!);
      final sw = Stopwatch()..start();
      final r = await vlm.read(rgb, w, h, '<|begin_of_sentence|>User: ${VisionModel.marker}OCR:\nAssistant:\n');
      print('${r.text} | prompt ${r.promptTokens} tokens, ${r.tokens} written, ${sw.elapsedMilliseconds} ms');
      vlm.dispose();
      expect(errors, isEmpty);
      if (env['CT_LLAMA_EXPECT'] case final expected?) expect(r.text.trim(), expected);
      if (env['CT_LLAMA_PROMPT_TOKENS'] case final n?) expect(r.promptTokens, int.parse(n));
    },
    skip: model == null || mmproj == null || image == null ? 'no model given' : false,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
