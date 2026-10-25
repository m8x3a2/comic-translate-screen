import 'package:ct_core/ct_core.dart';
import 'package:ct_providers/ct_providers.dart';
import 'package:test/test.dart';

void main() {
  test('a loop is cut where it starts, as derep.py of the experiment did', () {
    expect(cutRepeats(List.filled(41, 'Clap').join(' ')), 'Clap Clap Clap Clap');
    expect(
      cutRepeats('Fantastic! ${List.filled(10, 'Clap Clap! clap Clap.').join(' ')}'),
      'Fantastic! Clap Clap! clap',
    );
    const words =
        'one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen '
        'seventeen eighteen nineteen twenty a b c d e';
    expect(cutRepeats(words), words);
    expect(cutRepeats('Hey ${List.filled(20, 'ha ho').join(' ')} '), 'Hey ha ho ha');
    expect(cutRepeats('HALT!!'), 'HALT!!');
  });

  test('the reading becomes one line without markdown', () {
    expect(cleanVlmText('**YOU SHOULD**\n\nBE GRATEFUL!!\n'), 'YOU SHOULD BE GRATEFUL!!');
    expect(cleanVlmText('<think>hmm</think>```text\nHALT!!\n```'), 'HALT!!');
  });

  test('the prompt of the chat template', () {
    expect(paddleOcrVlPrompt('<m>'), '<|begin_of_sentence|>User: <m>OCR:\nAssistant:\n');
  });

  test('the slow reader is a reader of the levels, its model in the catalog', () {
    final registry = builtInRegistry();
    expect(registry.info(vlmReaderId).kind, PluginKind.reader);
    expect(registry.info(secondReaderId).kind, PluginKind.reader);
    expect(ModelCatalog.byId('paddleocr-vl-1.6')!.totalSize, 1817539616);
  });
}
