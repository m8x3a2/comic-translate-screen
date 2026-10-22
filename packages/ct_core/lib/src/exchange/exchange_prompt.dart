/// The instructions the user copies into the chat together with the
/// pictures or the text. In English: chats follow English instructions best,
/// whatever the languages of the comic.
library;

import 'exchange_answer.dart';
import 'exchange_settings.dart';

/// Built-in instructions. `{kind}`, `{source}`, `{target}`, `{labels}`,
/// `{lines}`, `{context}` and `{pictures}` are filled in by [exchangePrompt].
const defaultExchangePrompts = {
  ExchangeMode.recognize: '''
The attached pictures show pieces of text cut out of {kind}. Each piece has a label like [01-003] above it.
{pictures}Write down the {source} text of every labelled piece exactly as it is written (keep the letters, the case and the punctuation).
Answer with one line per label and nothing else:
[01-003] text
Write a piece with several lines as one line. If a piece has no readable text, write its label with nothing after it.
Labels: {labels}
{context}''',
  ExchangeMode.translate: '''
Translate these lines of {kind} from {source} into {target}.
{pictures}Keep the tone and the way each character speaks; the translation should read naturally.
Answer with one line per label and nothing else:
[01-003] translation
{context}
{lines}''',
  ExchangeMode.both: '''
The attached pictures show pieces of text cut out of {kind}. Each piece has a label like [01-003] above it.
{pictures}For every labelled piece write the {source} text exactly as it is written, then " --> ", then its translation into {target}.
Keep the tone and the way each character speaks; the translation should read naturally.
Answer with one line per label and nothing else:
[01-003] original text --> translation
Write a piece with several lines as one line. If a piece has no readable text, write its label with nothing after it.
Labels: {labels}
{context}''',
};

/// The instructions for [items]: the user's own [template] or the
/// built-in one. [screens]: screenshots of sites and games rather than a
/// comic. [contextPictures]: pictures of the whole pages go along.
String exchangePrompt(
  ExchangeMode mode,
  List<ExchangeItem> items, {
  required String sourceLanguage,
  required String targetLanguage,
  String template = '',
  String extraContext = '',
  bool screens = false,
  bool contextPictures = false,
}) {
  final base = template.trim().isEmpty ? defaultExchangePrompts[mode]! : template;
  final lines = [for (final i in items) '${i.label} ${_oneLine(i.text)}'].join('\n');
  final values = {
    'kind': screens ? 'screenshots of a site or a game' : 'a comic',
    'source': sourceLanguage == 'Auto' ? 'original' : sourceLanguage,
    'target': targetLanguage,
    'labels': [for (final i in items) i.label].join(' '),
    'lines': lines,
    'context': extraContext.trim().isEmpty
        ? ''
        : 'About the ${screens ? 'screenshots' : 'comic'}: ${extraContext.trim()}',
    'pictures': contextPictures
        ? 'Pictures of the whole pages with the same labels on them are attached too, only to show what happens '
              'and who speaks.\n'
        : '',
  };
  final out = base.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => values[m[1]] ?? m[0]!);
  return '${out.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim()}\n';
}

String _oneLine(String s) => s.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
