// Translates with a real text model; skipped unless CT_LLAMA_TEXT_MODEL
// (a GGUF file) is set. CT_LLAMA_TEXT_EXPECT: a word the translation must
// hold.

import 'dart:io';

import 'package:ct_llama/ct_llama.dart';
import 'package:test/test.dart';

void main() {
  final env = Platform.environment;
  final path = env['CT_LLAMA_TEXT_MODEL'];
  test(
    'a text model translates one phrase, at once and the same way twice',
    () async {
      final model = TextModel.open(path!, threads: 4, contextSize: 2048);
      try {
        final prompt = model.chatPrompt([
          (
            'user',
            'Translate the following text into Russian. Output the translation directly, without any '
                'explanation:\n\nWhile everyone else is losing their minds, I stay calm.',
          ),
        ]);
        final sw = Stopwatch()..start();
        final a = await model.generate(prompt, sampling: const TextSampling(maxTokens: 128));
        final b = await model.generate(prompt, sampling: const TextSampling(maxTokens: 128));
        stdout.writeln('${a.text.trim()}  (${a.tokens} tokens, ${sw.elapsedMilliseconds ~/ 2} ms each)');
        expect(a.text, b.text);
        expect(a.stopped, isFalse);
        expect(a.text, isNot(contains('<think>')));
        expect(RegExp('[а-яА-Я]').hasMatch(a.text), isTrue, reason: a.text);
        final word = env['CT_LLAMA_TEXT_EXPECT'];
        if (word != null) expect(a.text.toLowerCase(), contains(word.toLowerCase()));
      } finally {
        model.dispose();
      }
    },
    skip: path == null ? 'set CT_LLAMA_TEXT_MODEL to a GGUF text model' : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
