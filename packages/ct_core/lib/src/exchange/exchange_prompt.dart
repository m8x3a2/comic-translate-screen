/// The instructions the user copies into the chat together with the
/// pictures or the text. In English: chats follow English instructions best,
/// whatever the languages of the comic.
library;

import 'exchange_answer.dart';
import 'exchange_settings.dart';

/// Built-in instructions. `{kind}`, `{source}`, `{target}`, `{labels}`,
/// `{lines}`, `{context}`, `{pictures}`, `{stress}` and `{separator}` are
/// filled in by [exchangePrompt].
const defaultExchangePrompts = {
  ExchangePrompt.recognize: '''
The attached pictures show pieces of text cut out of {kind}. Each piece has a label like [01-003] above it.
{pictures}Write down the {source} text of every labelled piece exactly as it is written (keep the letters, the case and the punctuation).
Answer with one line per label and nothing else:
[01-003] text
Write a piece with several lines as one line. If a piece has no readable text, write its label with nothing after it.
Labels: {labels}
{context}''',
  ExchangePrompt.translate: '''
Translate these lines of {kind} from {source} into {target}.
{pictures}Keep the tone and the way each character speaks; the translation should read naturally.
{stress}Answer with one line per label and nothing else:
[01-003] translation
{context}
{lines}''',
  ExchangePrompt.both: '''
The attached pictures show pieces of text cut out of {kind}. Each piece has a label like [01-003] above it.
{pictures}For every labelled piece write the {source} text exactly as it is written, then " {separator} ", then its translation into {target}.
Keep the tone and the way each character speaks; the translation should read naturally.
{stress}Answer with one line per label and nothing else:
[01-003] original text {separator} translation
Write a piece with several lines as one line. If a piece has no readable text, write its label with nothing after it.
Labels: {labels}
{context}''',
  ExchangePrompt.bothApart: '''
The attached pictures show pieces of text cut out of {kind}. Each piece has a label like [01-003] above it.
{pictures}Answer with two lists and nothing else.
First the {source} text of every labelled piece exactly as it is written, one line per label:
[01-003] original text
Then a line with only ===
Then the translation of every piece into {target}, one line per label:
[01-003] translation
Keep the tone and the way each character speaks; the translation should read naturally.
{stress}Write a piece with several lines as one line. If a piece has no readable text, write its label with nothing after it.
Labels: {labels}
{context}''',
};

/// The instructions for [items]: the user's own [template] or the
/// built-in one. [screens]: screenshots of sites and games rather than a
/// comic. [contextPictures]: pictures of the whole pages go along.
String exchangePrompt(
  ExchangePrompt kind,
  List<ExchangeItem> items, {
  required String sourceLanguage,
  required String targetLanguage,
  String template = '',
  String extraContext = '',
  bool screens = false,
  bool contextPictures = false,
  String separator = defaultExchangeSeparator,
}) {
  final base = template.trim().isEmpty ? defaultExchangePrompts[kind]! : template;
  final lines = exchangeTextLines(items);
  final values = {
    'separator': separator,
    'kind': screens ? 'screenshots of a site or a game' : 'a comic',
    'source': sourceLanguage == 'Auto' ? 'original' : sourceLanguage,
    'target': targetLanguage,
    'labels': [for (final i in items) i.label].join(' '),
    'lines': lines,
    'context': extraContext.trim().isEmpty
        ? ''
        : 'About the ${screens ? 'screenshots' : 'comic'}: ${extraContext.trim()}',
    // Stressed words can be seen only on pictures.
    'stress': kind != ExchangePrompt.recognize && (kind != ExchangePrompt.translate || contextPictures)
        ? '$stressInstruction\n'
        : '',
    'pictures': contextPictures
        ? 'Pictures of the whole pages with the same labels on them are attached too, only to show what happens '
              'and who speaks.\n'
        : '',
  };
  final out = base.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => values[m[1]] ?? m[0]!);
  return '${out.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim()}\n';
}

/// How the chat marks the words the source stresses (bold or larger
/// letters); they become bold words of the translation.
const stressInstruction =
    'Where the original stresses a word (bold or larger letters), put the matching word of the translation '
    'between stars: *word*. Use no other stars.';

/// The text of [items], one line per label: `[01-003] I'M LATE!` (the
/// `{lines}` of the instructions, and what "Copy the text" copies).
String exchangeTextLines(List<ExchangeItem> items) =>
    [for (final i in items) '${i.label} ${_oneLine(i.text)}'].join('\n');

String _oneLine(String s) => s.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
